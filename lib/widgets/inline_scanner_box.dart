import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'scan_ui_helpers.dart';

class InlineScannerBox extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool isBusy;
  final String? capturedImagePath;
  final VoidCallback onClose;
  final VoidCallback onRetake;
  final Future<void> Function(String path) onRecognize;

  const InlineScannerBox({
    super.key,
    required this.cameras,
    required this.isBusy,
    required this.capturedImagePath,
    required this.onClose,
    required this.onRetake,
    required this.onRecognize,
  });

  @override
  State<InlineScannerBox> createState() => _InlineScannerBoxState();
}

class _InlineScannerBoxState extends State<InlineScannerBox> {
  CameraController? _controller;
  Future<void>? _initFuture;

  bool _isCapturing = false;

  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  Offset? _focusUiPoint;

  bool _isScaling = false;
  double _lastScale = 1.0;
  DateTime _lastScaleEnd = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isEmpty) return;

    final back = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      back,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    _initFuture = _controller!.initialize().then((_) async {
      try {
        _minZoom = await _controller!.getMinZoomLevel();
        _maxZoom = await _controller!.getMaxZoomLevel();
        _currentZoom = _minZoom;
        await _controller!.setZoomLevel(_currentZoom);
      } catch (_) {}
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _tapBlockedByRecentScale {
    final diff = DateTime.now().difference(_lastScaleEnd).inMilliseconds;
    return _isScaling || diff < 120;
  }

  Future<void> _setFocusAndExposure({
    required Offset tapPos,
    required Size boxSize,
  }) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.capturedImagePath != null) return;

    final dx = (tapPos.dx / boxSize.width).clamp(0.0, 1.0);
    final dy = (tapPos.dy / boxSize.height).clamp(0.0, 1.0);
    final point = Offset(dx, dy);

    try {
      await controller.setFocusPoint(point);
      await controller.setExposurePoint(point);
    } catch (_) {}

    setState(() => _focusUiPoint = tapPos);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _focusUiPoint = null);
    });
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.capturedImagePath != null) return;
    if (_maxZoom <= _minZoom) return;

    final next = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    if ((next - _currentZoom).abs() < 0.01) return;

    _currentZoom = next;
    try {
      await controller.setZoomLevel(_currentZoom);
    } catch (_) {}
  }

  Future<void> _capture() async {
    if (_isCapturing || widget.isBusy) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (widget.capturedImagePath != null) return;

    setState(() => _isCapturing = true);

    try {
      final xfile = await controller.takePicture();
      await controller.pausePreview();
      await widget.onRecognize(xfile.path);
      if (widget.capturedImagePath == null) {
        try {
          await controller.resumePreview();
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scanNestedText(
              'validation',
              'captureFailed',
              '촬영/OCR에 실패했어요. 다시 시도해 주세요',
            ),
          ),
        ),
      );
      try {
        await _controller?.resumePreview();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boxSize = Size(constraints.maxWidth, constraints.maxHeight);
            final boxAspect = constraints.maxWidth / constraints.maxHeight;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                if (_tapBlockedByRecentScale) return;
                _setFocusAndExposure(
                  tapPos: details.localPosition,
                  boxSize: boxSize,
                );
              },
              onScaleStart: (_) {
                _isScaling = true;
                _baseZoom = _currentZoom;
                _lastScale = 1.0;
              },
              onScaleUpdate: (details) async {
                final delta = (details.scale - _lastScale).abs();
                if (delta < 0.01) return;
                _lastScale = details.scale;
                await _onScaleUpdate(details);
              },
              onScaleEnd: (_) {
                _lastScaleEnd = DateTime.now();
                Future.delayed(const Duration(milliseconds: 80), () {
                  if (mounted) setState(() => _isScaling = false);
                });
              },
              child: Stack(
                children: [
                  FutureBuilder<void>(
                    future: _initFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done ||
                          _controller == null ||
                          !_controller!.value.isInitialized) {
                        return Container(
                          color: Colors.black87,
                          alignment: Alignment.center,
                          child: Text(
                            scanText('cameraPreparing', '카메라 준비 중...'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      if (widget.capturedImagePath != null) {
                        return Image.file(
                          File(widget.capturedImagePath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      }

                      final controller = _controller!;
                      final previewAspect = controller.value.aspectRatio;
                      final scale = previewAspect / boxAspect;

                      return ClipRect(
                        child: Transform.scale(
                          scale: scale,
                          child: Center(child: CameraPreview(controller)),
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                  if (_focusUiPoint != null)
                    Positioned(
                      left: _focusUiPoint!.dx - 24,
                      top: _focusUiPoint!.dy - 24,
                      child: IgnorePointer(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.92),
                              width: 1.6,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.isBusy ? null : widget.onClose,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              backgroundColor: Colors.black45,
                            ),
                            child: Text(scanText('close', '닫기')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.capturedImagePath != null)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.isBusy ? null : widget.onRetake,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                                backgroundColor: Colors.black45,
                              ),
                              child: Text(scanText('retake', '다시 찍기')),
                            ),
                          ),
                        if (widget.capturedImagePath != null)
                          const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.capturedImagePath != null ||
                                    widget.isBusy ||
                                    _isCapturing
                                ? null
                                : _capture,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE31837),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              widget.isBusy || _isCapturing
                                  ? scanText('processing', '처리 중...')
                                  : scanText('capture', '촬영'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
