import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recognized_item.dart';
import '../models/recognized_item_candidate.dart';
import '../models/scan_job.dart';
import '../services/app_runtime_copy.dart';
import '../services/remote_scan_repository.dart';
import '../services/scan_repository.dart';

final _priceFormatter = NumberFormat('#,###');
String _fmt(int v) => _priceFormatter.format(v);

String _scanText(String key, String fallback) =>
    AppRuntimeCopy.text(['scan', key], fallback);

String _scanNestedText(String group, String key, String fallback) =>
    AppRuntimeCopy.text(['scan', group, key], fallback);

String _scanStatusText(ScanJob job) {
  return switch (job.status) {
    ScanJobStatus.queued => _scanText('queued', '대기 중...'),
    ScanJobStatus.uploading => _scanText('uploading', '업로드 중...'),
    ScanJobStatus.processing => _scanText('processing', '분석 중...'),
    ScanJobStatus.done => _scanText('resultPreparing', '결과 정리 중...'),
    ScanJobStatus.failed =>
      job.errorMessage ?? _scanText('failed', '인식에 실패했어요'),
  };
}

String _scanReviewMessage(double? confidence) {
  if (confidence == null) {
    return _scanNestedText('review', 'default', '인식 결과를 확인한 뒤 카트에 담아주세요.');
  }
  if (confidence >= 0.85) {
    return _scanNestedText('review', 'high', '신뢰도가 높은 결과예요. 빠르게 확인하고 담아주세요.');
  }
  if (confidence >= 0.65) {
    return _scanNestedText('review', 'medium', '한 번 확인하고 담는 걸 권장해요.');
  }
  return _scanNestedText('review', 'low', '확인 필요 결과예요. 수정하거나 다시 찍는 게 좋아요.');
}

String _scanConfidenceLabel(double confidence) {
  if (confidence >= 0.85) {
    return _scanNestedText('confidence', 'high', '신뢰 높음');
  }
  if (confidence >= 0.65) {
    return _scanNestedText('confidence', 'medium', '확인 권장');
  }
  return _scanNestedText('confidence', 'low', '확인 필요');
}

class ItemAddSection extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ScanRepository scanRepository;

  final void Function(RecognizedItem item) onAdd;
  final void Function(RecognizedItem item)? onRecognized;
  final VoidCallback? onAddedFeedback;
  final String addButtonText;

  const ItemAddSection({
    super.key,
    required this.cameras,
    required this.scanRepository,
    required this.onAdd,
    this.onRecognized,
    this.onAddedFeedback,
    this.addButtonText = '카트에 담기',
  });

  @override
  State<ItemAddSection> createState() => _ItemAddSectionState();
}

class _ItemAddSectionState extends State<ItemAddSection> {
  bool isScannerOpen = false;
  bool manualEntryOpen = false;
  bool isOcrRunning = false;
  String? _statusMessage;

  RecognizedItem? recognized;
  RecognizedItemCandidate? _originalCandidate;
  String? _recognizedJobId;
  String? _pendingJobId;
  String? _capturedPath; // ✅ 프리즈 이미지 경로

  bool get showResultCard => recognized != null;

  void _openScanner() {
    if (isOcrRunning) return;
    setState(() {
      isScannerOpen = true;
      manualEntryOpen = false;
      recognized = null;
      _originalCandidate = null;
      _recognizedJobId = null;
      _pendingJobId = null;
      _capturedPath = null;
    });
  }

  Future<void> _closeScanner() async {
    final path = _capturedPath;

    setState(() {
      isScannerOpen = false;
      manualEntryOpen = false;
      recognized = null;
      _originalCandidate = null;
      _recognizedJobId = null;
      _pendingJobId = null;
      _capturedPath = null;
    });

    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  void _openManualInline() {
    setState(() {
      isScannerOpen = false;
      manualEntryOpen = true;
      recognized = RecognizedItem(name: '', price: 0);
      _originalCandidate = null;
      _recognizedJobId = null;
      _pendingJobId = null;
      _capturedPath = null;
    });
  }

  bool _matchesOriginalCandidate(
    RecognizedItem item,
    RecognizedItemCandidate original,
  ) {
    return item.name.trim() == original.name.trim() &&
        item.price == original.price &&
        (item.sku ?? '').trim() == (original.sku ?? '').trim();
  }

  Future<void> _submitFeedbackIfNeeded(RecognizedItem item) async {
    final original = _originalCandidate;
    final jobId = item.scanJobId ?? _recognizedJobId;
    if (original == null || jobId == null || jobId.trim().isEmpty) {
      return;
    }

    final accepted = _matchesOriginalCandidate(item, original);

    try {
      await widget.scanRepository.submitFeedback(
        jobId: jobId,
        accepted: accepted,
        original: original,
        corrected: accepted ? null : item,
      );
    } catch (_) {
      // feedback는 best-effort로 남긴다.
    }
  }

  Future<void> _addToParent(RecognizedItem item) async {
    unawaited(_submitFeedbackIfNeeded(item));
    widget.onAdd(item);
    widget.onAddedFeedback?.call();
    await _closeScanner();
  }

  Future<void> _pollForSubmittedJob(ScanJob submitted, String imagePath) async {
    try {
      ScanJob job = submitted;

      for (var i = 0; i < 60; i++) {
        if (!mounted || _pendingJobId != submitted.jobId) return;

        await Future.delayed(const Duration(milliseconds: 1000));
        job = await widget.scanRepository.getJob(submitted.jobId);

        if (!mounted || _pendingJobId != submitted.jobId) return;
        setState(() {
          _statusMessage = _scanStatusText(job);
        });

        if (job.status == ScanJobStatus.done) {
          final result = await widget.scanRepository.getResult(submitted.jobId);
          if (!mounted || _pendingJobId != submitted.jobId) return;

          if (result == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _scanText('resultEmpty', '텍스트를 못 읽었어요. 더 가까이/선명하게 찍어봐요'),
                ),
              ),
            );
            setState(() {
              isOcrRunning = false;
              _pendingJobId = null;
              _capturedPath = null;
            });
            return;
          }

          final recognizedItem = RecognizedItem.fromCandidate(result);
          setState(() {
            isOcrRunning = false;
            recognized = recognizedItem;
            _originalCandidate = result;
            _recognizedJobId = result.scanJobId ?? submitted.jobId;
            _pendingJobId = null;
            manualEntryOpen = false;
            _capturedPath = imagePath;
            _statusMessage = null;
          });
          widget.onRecognized?.call(recognizedItem);
          return;
        }

        if (job.status == ScanJobStatus.failed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                job.errorMessage ??
                    _scanText('resultEmpty', '텍스트를 못 읽었어요. 더 가까이/선명하게 찍어봐요'),
              ),
            ),
          );
          setState(() {
            isOcrRunning = false;
            _pendingJobId = null;
            _capturedPath = null;
            _statusMessage = null;
          });
          return;
        }
      }

      if (!mounted || _pendingJobId != submitted.jobId) return;
      setState(() {
        isOcrRunning = false;
        _statusMessage = _scanText('timeout', '분석이 지연되고 있어요. 잠시 후 결과를 다시 확인해봐요');
      });
    } on ScanRepositoryException catch (error) {
      if (!mounted || _pendingJobId != submitted.jobId) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        isOcrRunning = false;
        _pendingJobId = null;
        _capturedPath = null;
        _statusMessage = null;
      });
    } catch (_) {
      if (!mounted || _pendingJobId != submitted.jobId) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_scanText('processingError', '분석 처리 중 오류가 났어요')),
        ),
      );
      setState(() {
        isOcrRunning = false;
        _pendingJobId = null;
        _capturedPath = null;
        _statusMessage = null;
      });
    }
  }

  Future<void> _runOcrFromFilePath(String imagePath) async {
    if (isOcrRunning) return;
    setState(() {
      isOcrRunning = true;
      _statusMessage = _scanText('uploading', '업로드 중...');
    });

    try {
      final submitted = await widget.scanRepository.submitImage(imagePath);
      if (!mounted) return;

      setState(() {
        isScannerOpen = false;
        _pendingJobId = submitted.jobId;
        _recognizedJobId = submitted.jobId;
        _capturedPath = imagePath;
        _statusMessage = _scanText('processing', '분석 중...');
      });

      unawaited(_pollForSubmittedJob(submitted, imagePath));
    } on ScanRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() {
        isOcrRunning = false;
        _pendingJobId = null;
        _capturedPath = null;
        _statusMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_scanText('processingError', '분석 처리 중 오류가 났어요')),
        ),
      );
      setState(() {
        isOcrRunning = false;
        _pendingJobId = null;
        _capturedPath = null;
        _statusMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 가격표 인식하기
        GestureDetector(
          onTap: isOcrRunning ? null : (isScannerOpen ? _closeScanner : _openScanner),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE31837),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _scanText('captureButton', '가격표 인식하기'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 카메라 영역 (버튼 사이)
        if (isScannerOpen) ...[
          InlineScannerBox(
            cameras: widget.cameras,
            isBusy: isOcrRunning,
            capturedImagePath: _capturedPath,
            onRecognize: _runOcrFromFilePath,
            onClose: _closeScanner,
            onRetake: () async {
              final path = _capturedPath;
              setState(() {
                _capturedPath = null;
                recognized = null;
                _originalCandidate = null;
                _recognizedJobId = null;
                _pendingJobId = null;
                _statusMessage = null;
              });
              if (path != null) {
                try {
                  await File(path).delete();
                } catch (_) {}
              }
            },
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ] else if (_statusMessage != null && (isOcrRunning || _pendingJobId != null)) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusMessage!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 인식 결과 (직접 추가하기 위)
        if (showResultCard && !manualEntryOpen) ...[
          RecognizedResultCard(
            title: _scanText('recognizedTitle', '인식 결과'),
            item: recognized!,
            onChanged: (u) => setState(() => recognized = u),
            onAdd: _addToParent,
            addButtonText: widget.addButtonText,
          ),
          const SizedBox(height: 12),
        ],

        // 직접 추가하기
        GestureDetector(
          onTap: _openManualInline,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _scanText('manualAddAction', '직접 추가하기'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (manualEntryOpen) ...[
          const SizedBox(height: 12),
          RecognizedResultCard(
            title: _scanText('manualAddTitle', '직접 추가하기'),
            item: recognized!,
            startEditing: true,
            showCancel: true,
            onCancel: () => setState(() {
              manualEntryOpen = false;
              recognized = null;
            }),
            onChanged: (u) => setState(() => recognized = u),
            onAdd: _addToParent,
            addButtonText: widget.addButtonText,
          ),
        ],
      ],
    );
  }
}

/* =========================
   InlineScannerBox
   ========================= */

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

  // ✅ 제스처 충돌 방지용
  bool _isScaling = false;
  double _lastScale = 1.0;
  DateTime _lastScaleEnd = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.cameras.isEmpty) return;

    // ✅ 후면 카메라 우선
    final back = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
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
    // ✅ scale이 끝난 직후 ‘의도치 않은 tap’ 방지
    final diff = DateTime.now().difference(_lastScaleEnd).inMilliseconds;
    return _isScaling || diff < 120;
  }

  Future<void> _setFocusAndExposure({
    required Offset tapPos,
    required Size boxSize,
  }) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    // ✅ 프리즈(촬영 이미지)면 포커스/노출 무시
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

  Future<void> _onScaleUpdate(ScaleUpdateDetails d) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    // ✅ 프리즈 상태면 줌 막기
    if (widget.capturedImagePath != null) return;

    if (_maxZoom <= _minZoom) return;

    final next = (_baseZoom * d.scale).clamp(_minZoom, _maxZoom);
    if ((next - _currentZoom).abs() < 0.01) return;

    _currentZoom = next;
    try {
      await controller.setZoomLevel(_currentZoom);
    } catch (_) {}
  }

  Future<void> _capture() async {
    if (_isCapturing || widget.isBusy) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (widget.capturedImagePath != null) return;

    setState(() => _isCapturing = true);

    try {
      final xfile = await c.takePicture();
      await c.pausePreview();
      await widget.onRecognize(xfile.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _scanNestedText(
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
            final boxAspect =
                constraints.maxWidth / constraints.maxHeight; // 1.0

            return GestureDetector(
              behavior: HitTestBehavior.opaque,

              // ✅ 탭 포커스: 핀치 직후/중에는 무시해서 충돌 방지
              onTapUp: (d) {
                if (_tapBlockedByRecentScale) return;
                _setFocusAndExposure(tapPos: d.localPosition, boxSize: boxSize);
              },

              // ✅ 핀치줌
              onScaleStart: (_) {
                _isScaling = true;
                _baseZoom = _currentZoom;
                _lastScale = 1.0;
              },
              onScaleUpdate: (d) async {
                final delta = (d.scale - _lastScale).abs();
                if (delta < 0.01) return;
                _lastScale = d.scale;
                await _onScaleUpdate(d);
              },
              onScaleEnd: (_) {
                _lastScaleEnd = DateTime.now();
                // 약간 딜레이 후 스케일링 상태 해제
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
                            _scanText('cameraPreparing', '카메라 준비 중...'),
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

                      // ✅ 1:1 꽉 채우기 (비율 유지 + 크롭)
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

                  // ✅ 포커스 UI: 동그란 링(원형)
                  if (_focusUiPoint != null)
                    Positioned(
                      left: _focusUiPoint!.dx - 26,
                      top: _focusUiPoint!.dy - 26,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),

                  // 줌 배지
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'x${_currentZoom.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  // 닫기
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),

                  // 다시 찍기 (프리즈일 때)
                  if (widget.capturedImagePath != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            await _controller?.resumePreview();
                          } catch (_) {}
                          widget.onRetake();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _scanText('retakeAction', '다시 찍기'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 인식 버튼
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Center(
                      child: GestureDetector(
                        onTap: (widget.capturedImagePath == null)
                            ? _capture
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            (widget.isBusy || _isCapturing)
                                ? _scanText('recognizing', '인식 중...')
                                : _scanText('recognizeAction', '인식'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
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

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final label = _scanConfidenceLabel(confidence);
    final color = confidence >= 0.85
        ? const Color(0xFF1E8E3E)
        : confidence >= 0.65
        ? const Color(0xFFB26A00)
        : const Color(0xFFE31837);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${(confidence * 100).round()}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    );
  }
}

/* =========================
   RecognizedResultCard
   ========================= */

class RecognizedResultCard extends StatefulWidget {
  final RecognizedItem item;
  final void Function(RecognizedItem updated) onChanged;
  final void Function(RecognizedItem item) onAdd;
  final String? title;

  final bool startEditing;
  final bool showCancel;
  final VoidCallback? onCancel;
  final String addButtonText;

  const RecognizedResultCard({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onAdd,
    this.startEditing = false,
    this.showCancel = false,
    this.onCancel,
    this.addButtonText = '카트에 추가',
    this.title,
  });

  @override
  State<RecognizedResultCard> createState() => _RecognizedResultCardState();
}

class _RecognizedResultCardState extends State<RecognizedResultCard> {
  late bool isEditing;
  late final TextEditingController nameCtrl;
  late final TextEditingController priceCtrl;

  @override
  void initState() {
    super.initState();
    isEditing = widget.startEditing;
    nameCtrl = TextEditingController(text: widget.item.name);
    priceCtrl = TextEditingController(
      text: widget.item.price > 0 ? _fmt(widget.item.price) : '',
    );
  }

  @override
  void didUpdateWidget(covariant RecognizedResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.startEditing != widget.startEditing) {
      if (widget.startEditing && !isEditing) isEditing = true;
    }

    if (oldWidget.item.name != widget.item.name) {
      nameCtrl.text = widget.item.name;
    }
    if (oldWidget.item.price != widget.item.price) {
      priceCtrl.text = widget.item.price > 0 ? _fmt(widget.item.price) : '';
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  void startEdit() => setState(() => isEditing = true);

  void cancelEdit() {
    nameCtrl.text = widget.item.name;
    priceCtrl.text = widget.item.price > 0 ? _fmt(widget.item.price) : '';
    setState(() => isEditing = false);
  }

  RecognizedItem? applyEdits() {
    final name = nameCtrl.text.trim();
    final rawPrice = priceCtrl.text.replaceAll(',', '').trim();
    final parsed = int.tryParse(rawPrice);

    if (name.isEmpty || parsed == null || parsed <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _scanNestedText(
              'validation',
              'namePriceRequired',
              '상품명/가격을 확인해주세요',
            ),
          ),
        ),
      );
      return null;
    }

    final updated = widget.item.copyWith(name: name, price: parsed);
    widget.onChanged(updated);
    setState(() => isEditing = false);
    return updated;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title ?? _scanText('recognizedTitle', '인식 결과'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (item.confidence != null)
                _ConfidenceBadge(confidence: item.confidence!),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _scanReviewMessage(item.confidence),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
          if ((item.source ?? '').isNotEmpty ||
              (item.sku ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if ((item.source ?? '').isNotEmpty)
                  _MetaChip(
                    label: _scanText('sourceLabel', 'source'),
                    value: item.source!,
                  ),
                if ((item.sku ?? '').isNotEmpty)
                  _MetaChip(
                    label: _scanText('skuLabel', 'sku'),
                    value: item.sku!,
                  ),
              ],
            ),
          ],
          if ((item.rawText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12),
              ),
              child: Text(
                '${_scanText('rawTextPrefix', '원문')}: ${item.rawText!.trim()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),

          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  AppRuntimeCopy.text(['cartDetail', 'nameLabel'], '상품명'),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: AppRuntimeCopy.text([
                            'cartDetail',
                            'nameLabel',
                          ], '상품명'),
                        ),
                      )
                    : Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  AppRuntimeCopy.text(['cartDetail', 'priceLabel'], '가격'),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: _scanText('priceHint', '가격(숫자)'),
                        ),
                        onChanged: (v) {
                          // 입력 중 콤마 포맷
                          final raw = v.replaceAll(',', '');
                          final n = int.tryParse(raw);
                          if (n == null) return;
                          final formatted = _fmt(n);
                          if (formatted != v) {
                            priceCtrl.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(
                                offset: formatted.length,
                              ),
                            );
                          }
                        },
                      )
                    : Text(
                        '₩${_fmt(item.price)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.showCancel)
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    AppRuntimeCopy.text(['common', 'cancel'], '취소'),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: isEditing ? cancelEdit : startEdit,
                  child: Text(
                    isEditing
                        ? AppRuntimeCopy.text(['common', 'cancel'], '취소')
                        : AppRuntimeCopy.text(['common', 'edit'], '수정'),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE31837),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  RecognizedItem toAdd = widget.item;

                  if (isEditing) {
                    final updated = applyEdits();
                    if (updated == null) return;
                    toAdd = updated;
                  }

                  widget.onAdd(toAdd);
                },
                child: Text(
                  widget.addButtonText,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
