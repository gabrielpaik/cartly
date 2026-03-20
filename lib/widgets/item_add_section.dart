import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recognized_item.dart';
import '../models/scan_job.dart';
import '../services/scan_repository.dart';

final _priceFormatter = NumberFormat('#,###');
String _fmt(int v) => _priceFormatter.format(v);

class ItemAddSection extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ScanRepository scanRepository;

  final void Function(RecognizedItem item) onAdd;
  final VoidCallback? onAddedFeedback;
  final String addButtonText;

  const ItemAddSection({
    super.key,
    required this.cameras,
    required this.scanRepository,
    required this.onAdd,
    this.onAddedFeedback,
    this.addButtonText = '카트에 추가',
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
  String? _capturedPath; // ✅ 프리즈 이미지 경로

  bool get showResultCard => recognized != null;

  void _openScanner() {
    setState(() {
      isScannerOpen = true;
      manualEntryOpen = false;
      recognized = null;
      _capturedPath = null;
    });
  }

  Future<void> _closeScanner() async {
    final path = _capturedPath;

    setState(() {
      isScannerOpen = false;
      manualEntryOpen = false;
      recognized = null;
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
      _capturedPath = null;
    });
  }

  Future<void> _addToParent(RecognizedItem item) async {
    widget.onAdd(item);
    widget.onAddedFeedback?.call();
    await _closeScanner();
  }

  Future<void> _runOcrFromFilePath(String imagePath) async {
    if (isOcrRunning) return;
    setState(() {
      isOcrRunning = true;
      _statusMessage = '업로드 중...';
    });

    try {
      final submitted = await widget.scanRepository.submitImage(imagePath);
      if (!mounted) return;

      ScanJob job = submitted;
      for (var i = 0; i < 15; i++) {
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 700));
        job = await widget.scanRepository.getJob(submitted.jobId);

        if (!mounted) return;
        setState(() {
          _statusMessage = switch (job.status) {
            ScanJobStatus.queued => '대기 중...',
            ScanJobStatus.uploading => '업로드 중...',
            ScanJobStatus.processing => '분석 중...',
            ScanJobStatus.done => '결과 정리 중...',
            ScanJobStatus.failed => job.errorMessage ?? '인식에 실패했어요',
          };
        });

        if (job.status == ScanJobStatus.done) break;
        if (job.status == ScanJobStatus.failed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(job.errorMessage ?? '텍스트를 못 읽었어요. 더 가까이/선명하게 찍어봐요')),
          );
          return;
        }
      }

      final result = await widget.scanRepository.getResult(submitted.jobId);
      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('텍스트를 못 읽었어요. 더 가까이/선명하게 찍어봐요')),
        );
        return;
      }

      setState(() {
        recognized = RecognizedItem(name: result.name, price: result.price);
        manualEntryOpen = false;
        _capturedPath = imagePath;
        _statusMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('분석 처리 중 오류가 났어요')));
    } finally {
      if (mounted) {
        setState(() {
          isOcrRunning = false;
          if (recognized != null) {
            _statusMessage = null;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 가격표 인식하기
        GestureDetector(
          onTap: isScannerOpen ? _closeScanner : _openScanner,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFE31837),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.camera_alt, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '가격표 인식하기',
                  style: TextStyle(
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
        ],

        // 인식 결과 (직접 추가하기 위)
        if (showResultCard && !manualEntryOpen) ...[
          RecognizedResultCard(
            title: '인식 결과',
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
              children: const [
                Icon(Icons.edit, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '직접 추가하기',
                  style: TextStyle(
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
            title: '직접 추가하기',
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
        const SnackBar(content: Text('촬영/OCR에 실패했어요. 다시 시도해 주세요')),
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
                          child: const Text(
                            '카메라 준비 중...',
                            style: TextStyle(color: Colors.white70),
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
                            color: Colors.white.withOpacity(0.95),
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
                        color: Colors.black.withOpacity(0.35),
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
                          color: Colors.black.withOpacity(0.35),
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
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '다시 찍기',
                            style: TextStyle(
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
                            (widget.isBusy || _isCapturing) ? '인식 중...' : '인식',
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

/* =========================
   RecognizedResultCard
   ========================= */

class RecognizedResultCard extends StatefulWidget {
  final RecognizedItem item;
  final void Function(RecognizedItem updated) onChanged;
  final void Function(RecognizedItem item) onAdd;
  final String title;

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
    this.title = '인식 결과',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상품명/가격을 확인해주세요')));
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
          Text(
            widget.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              const SizedBox(
                width: 64,
                child: Text('상품명', style: TextStyle(color: Colors.black54)),
              ),
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          hintText: '상품명',
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
              const SizedBox(
                width: 64,
                child: Text('가격', style: TextStyle(color: Colors.black54)),
              ),
              Expanded(
                child: isEditing
                    ? TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          hintText: '가격(숫자)',
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
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: isEditing ? cancelEdit : startEdit,
                  child: Text(
                    isEditing ? '취소' : '수정',
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
