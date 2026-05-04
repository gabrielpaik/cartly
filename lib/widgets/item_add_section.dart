import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../models/recognized_item.dart';
import '../models/recognized_item_candidate.dart';
import '../models/scan_job.dart';
import '../services/remote_scan_repository.dart';
import '../services/scan_repository.dart';
import 'inline_scanner_box.dart';
import 'recognized_result_card.dart';
import 'scan_ui_helpers.dart';

String _fmt(int v) => fmtScanPrice(v);

String _scanText(String key, String fallback) => scanText(key, fallback);

class ItemAddSection extends StatefulWidget {
  final List<CameraDescription> cameras;
  final ScanRepository scanRepository;

  final Future<bool> Function(RecognizedItem item) onAdd;
  final void Function(RecognizedItem item)? onRecognized;
  final void Function(RecognizedItem item)? onDismissRecognized;
  final VoidCallback? onAddedFeedback;
  final String addButtonText;

  const ItemAddSection({
    super.key,
    required this.cameras,
    required this.scanRepository,
    required this.onAdd,
    this.onRecognized,
    this.onDismissRecognized,
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
  String? _capturedPath; // legacy capture path, kept for cleanup only
  final List<String> _queuedImagePaths = [];
  final List<_ScanQueueEntry> _scanInbox = [];
  int _scanSequence = 0;
  String? _activeQueueEntryId;

  bool get showResultCard => recognized != null;

  bool _isActiveReviewEntry(_ScanQueueEntry entry) {
    return entry.id == _activeQueueEntryId &&
        recognized != null &&
        !manualEntryOpen;
  }

  List<_ScanQueueEntry> get _visibleScanInboxEntries => _scanInbox
      .where((entry) => !_isActiveReviewEntry(entry))
      .toList(growable: false);

  List<_ScanQueueEntry> get _captureWaitingEntries => _visibleScanInboxEntries
      .where((entry) => entry.status == _ScanQueueStatus.captured)
      .toList(growable: false);

  List<_ScanQueueEntry> get _processingEntries => _visibleScanInboxEntries
      .where((entry) => entry.status != _ScanQueueStatus.captured)
      .toList(growable: false);

  int get _readyCount => _scanInbox
      .where(
        (entry) =>
            entry.status == _ScanQueueStatus.ready &&
            !_isActiveReviewEntry(entry),
      )
      .length;
  int get _failedCount => _scanInbox
      .where((entry) => entry.status == _ScanQueueStatus.failed)
      .length;
  int get _completedCount => _scanInbox
      .where((entry) => entry.status == _ScanQueueStatus.added)
      .length;

  String? get _queueStatusMessage {
    if (isOcrRunning && _queuedImagePaths.isNotEmpty) {
      return '분석 중 1건, 촬영 완료 ${_queuedImagePaths.length}건이 순서 대기 중이에요';
    }
    if (isOcrRunning) {
      return '가격표 1건을 분석 중이에요. 다른 가격표를 계속 찍을 수 있어요';
    }
    if (_queuedImagePaths.isNotEmpty) {
      return '촬영 완료 ${_queuedImagePaths.length}건이 분석 대기 중이에요';
    }
    return null;
  }

  String get _captureQueueSummaryText {
    final count = _captureWaitingEntries.length;
    if (count == 0) return '촬영해 둔 가격표가 없어요';
    return '촬영 완료 $count건이 아직 분석 전이에요';
  }

  String get _processingQueueSummaryText {
    final parts = <String>[];
    if (isOcrRunning) parts.add('분석 중 1건');
    if (_readyCount > 0) parts.add('검토 대기 $_readyCount건');
    if (_failedCount > 0) parts.add('실패 $_failedCount건');
    if (_completedCount > 0) parts.add('담기 완료 $_completedCount건');
    return parts.isEmpty ? '분석/검토 중인 항목이 없어요' : parts.join(' · ');
  }

  void _openScanner() {
    setState(() {
      isScannerOpen = true;
      manualEntryOpen = false;
      _capturedPath = null;
      _statusMessage = null;
    });
  }

  Future<void> _closeScanner() async {
    final path = _capturedPath;

    setState(() {
      isScannerOpen = false;
      manualEntryOpen = false;
      _capturedPath = null;
      _statusMessage = null;
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

  void _clearRecognizedResult() {
    if (!mounted) return;
    setState(() {
      recognized = null;
      _originalCandidate = null;
      _recognizedJobId = null;
      _statusMessage = null;
      manualEntryOpen = false;
      _activeQueueEntryId = null;
    });
    _promoteNextReadyItem();
  }

  Future<void> _addToParent(RecognizedItem item) async {
    final activeQueueEntryId = _activeQueueEntryId;
    final added = await widget.onAdd(item);
    if (!added) return;

    unawaited(_submitFeedbackIfNeeded(item));
    widget.onDismissRecognized?.call(item);
    widget.onAddedFeedback?.call();
    if (activeQueueEntryId != null) {
      setState(() {
        _updateQueueEntry(
          activeQueueEntryId,
          status: _ScanQueueStatus.added,
          item: item,
          errorMessage: null,
        );
      });
    }
    _clearRecognizedResult();
    await _closeScanner();
  }

  Future<void> _deleteQueuedImage(String imagePath) async {
    try {
      await File(imagePath).delete();
    } catch (_) {}
  }

  void _startNextQueuedScan() {
    if (!mounted || isOcrRunning || _queuedImagePaths.isEmpty) return;
    final nextImagePath = _queuedImagePaths.removeAt(0);
    unawaited(_runOcrFromFilePath(nextImagePath));
  }

  void _enqueueCapturedImage(String imagePath) {
    setState(() {
      _queuedImagePaths.add(imagePath);
      _statusMessage = null;
      _scanInbox.add(
        _ScanQueueEntry(
          id: _nextQueueEntryId(),
          imagePath: imagePath,
          status: _ScanQueueStatus.captured,
          createdAt: DateTime.now(),
        ),
      );
    });
    _startNextQueuedScan();
  }

  String _nextQueueEntryId() => 'scan-${_scanSequence++}';

  _ScanQueueEntry? _findQueueEntryByImagePath(String imagePath) {
    for (final entry in _scanInbox) {
      if (entry.imagePath == imagePath) return entry;
    }
    return null;
  }

  void _updateQueueEntry(
    String id, {
    _ScanQueueStatus? status,
    RecognizedItem? item,
    RecognizedItemCandidate? candidate,
    String? errorMessage,
  }) {
    final index = _scanInbox.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    final current = _scanInbox[index];
    _scanInbox[index] = current.copyWith(
      status: status,
      item: item,
      candidate: candidate,
      errorMessage: errorMessage,
      completedAt: status == _ScanQueueStatus.added
          ? DateTime.now()
          : current.completedAt,
    );
  }

  void _activateReadyEntry(_ScanQueueEntry entry) {
    if (entry.item == null) return;
    recognized = entry.item;
    _originalCandidate = entry.candidate;
    _recognizedJobId = entry.item?.scanJobId;
    _activeQueueEntryId = entry.id;
    manualEntryOpen = false;
  }

  void _promoteNextReadyItem() {
    if (!mounted || manualEntryOpen || recognized != null) return;
    for (final entry in _scanInbox) {
      if (entry.status == _ScanQueueStatus.ready && entry.item != null) {
        setState(() {
          _activateReadyEntry(entry);
        });
        widget.onDismissRecognized?.call(entry.item!);
        return;
      }
    }
  }

  void _removeQueueEntry(_ScanQueueEntry entry) {
    final wasActive = entry.id == _activeQueueEntryId;
    final recognizedItem = entry.item;
    setState(() {
      _scanInbox.removeWhere((candidate) => candidate.id == entry.id);
      if (wasActive) {
        recognized = null;
        _originalCandidate = null;
        _recognizedJobId = null;
        _activeQueueEntryId = null;
      }
    });
    if (recognizedItem != null) {
      widget.onDismissRecognized?.call(recognizedItem);
    }
    if (wasActive) _promoteNextReadyItem();
  }

  Future<void> _pollForSubmittedJob(ScanJob submitted, String imagePath) async {
    final queueEntryId = _findQueueEntryByImagePath(imagePath)?.id;
    try {
      ScanJob job = submitted;

      if (queueEntryId != null) {
        setState(() {
          _updateQueueEntry(queueEntryId, status: _ScanQueueStatus.processing);
        });
      }

      for (var i = 0; i < 60; i++) {
        if (!mounted || _pendingJobId != submitted.jobId) return;

        await Future.delayed(const Duration(milliseconds: 1000));
        job = await widget.scanRepository.getJob(submitted.jobId);

        if (!mounted || _pendingJobId != submitted.jobId) return;
        setState(() {
          _statusMessage = null;
        });

        if (job.status == ScanJobStatus.done) {
          final result = await widget.scanRepository.getResult(submitted.jobId);
          if (!mounted || _pendingJobId != submitted.jobId) return;

          if (result == null) {
            final message = _scanText(
              'resultEmpty',
              '텍스트를 못 읽었어요. 더 가까이/선명하게 찍어봐요',
            );
            await _deleteQueuedImage(imagePath);
            setState(() {
              isOcrRunning = false;
              _pendingJobId = null;
              _capturedPath = null;
              if (queueEntryId != null) {
                _updateQueueEntry(
                  queueEntryId,
                  status: _ScanQueueStatus.failed,
                  errorMessage: message,
                );
              }
            });
            _startNextQueuedScan();
            return;
          }

          final recognizedItem = RecognizedItem.fromCandidate(result);
          var promotedToActive = false;
          await _deleteQueuedImage(imagePath);
          setState(() {
            isOcrRunning = false;
            _pendingJobId = null;
            _capturedPath = null;
            _statusMessage = null;
            if (queueEntryId != null) {
              _updateQueueEntry(
                queueEntryId,
                status: _ScanQueueStatus.ready,
                item: recognizedItem,
                candidate: result,
                errorMessage: null,
              );
              if (recognized == null && !manualEntryOpen) {
                final entry = _findQueueEntryByImagePath(imagePath);
                if (entry != null) {
                  _activateReadyEntry(entry);
                  promotedToActive = true;
                }
              }
            } else {
              recognized = recognizedItem;
              _originalCandidate = result;
              _recognizedJobId = result.scanJobId ?? submitted.jobId;
              manualEntryOpen = false;
              promotedToActive = true;
            }
          });
          if (!promotedToActive) {
            widget.onRecognized?.call(recognizedItem);
          }
          _startNextQueuedScan();
          return;
        }

        if (job.status == ScanJobStatus.failed) {
          final message =
              job.errorMessage ??
              _scanText('resultEmpty', '텍스트를 못 읽었어요. 더 가까이/선명하게 찍어봐요');
          await _deleteQueuedImage(imagePath);
          setState(() {
            isOcrRunning = false;
            _pendingJobId = null;
            _capturedPath = null;
            _statusMessage = null;
            if (queueEntryId != null) {
              _updateQueueEntry(
                queueEntryId,
                status: _ScanQueueStatus.failed,
                errorMessage: message,
              );
            }
          });
          _startNextQueuedScan();
          return;
        }
      }

      if (!mounted || _pendingJobId != submitted.jobId) return;
      final message = _scanText('timeout', '분석이 지연되고 있어요. 잠시 후 결과를 다시 확인해봐요');
      await _deleteQueuedImage(imagePath);
      setState(() {
        isOcrRunning = false;
        _pendingJobId = null;
        _capturedPath = null;
        _statusMessage = message;
        if (queueEntryId != null) {
          _updateQueueEntry(
            queueEntryId,
            status: _ScanQueueStatus.failed,
            errorMessage: message,
          );
        }
      });
      _startNextQueuedScan();
    } on ScanRepositoryException catch (error) {
      if (!mounted || _pendingJobId != submitted.jobId) return;
      await _deleteQueuedImage(imagePath);
      setState(() {
        isOcrRunning = false;
        _pendingJobId = null;
        _capturedPath = null;
        _statusMessage = null;
        if (queueEntryId != null) {
          _updateQueueEntry(
            queueEntryId,
            status: _ScanQueueStatus.failed,
            errorMessage: error.message,
          );
        }
      });
      _startNextQueuedScan();
    } catch (_) {
      if (!mounted || _pendingJobId != submitted.jobId) return;
      final message = _scanText('processingError', '분석 처리 중 오류가 났어요');
      await _deleteQueuedImage(imagePath);
      setState(() {
        isOcrRunning = false;
        _pendingJobId = null;
        _capturedPath = null;
        _statusMessage = null;
        if (queueEntryId != null) {
          _updateQueueEntry(
            queueEntryId,
            status: _ScanQueueStatus.failed,
            errorMessage: message,
          );
        }
      });
      _startNextQueuedScan();
    }
  }

  Future<void> _runOcrFromFilePath(String imagePath) async {
    if (isOcrRunning) return;
    setState(() {
      isOcrRunning = true;
      _statusMessage = null;
    });

    try {
      final submitted = await widget.scanRepository.submitImage(imagePath);
      if (!mounted) return;

      setState(() {
        _pendingJobId = submitted.jobId;
        _recognizedJobId = submitted.jobId;
        _capturedPath = null;
        _statusMessage = null;
        final queueEntry = _findQueueEntryByImagePath(imagePath);
        if (queueEntry != null) {
          _updateQueueEntry(queueEntry.id, status: _ScanQueueStatus.uploading);
        }
      });

      unawaited(_pollForSubmittedJob(submitted, imagePath));
    } on ScanRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      await _deleteQueuedImage(imagePath);
      setState(() {
        isOcrRunning = false;
        _pendingJobId = null;
        _capturedPath = null;
        _statusMessage = null;
      });
      _startNextQueuedScan();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_scanText('processingError', '분석 처리 중 오류가 났어요')),
        ),
      );
      await _deleteQueuedImage(imagePath);
      setState(() {
        isOcrRunning = false;
        _pendingJobId = null;
        _capturedPath = null;
        _statusMessage = null;
      });
      _startNextQueuedScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanStatusMessage = _statusMessage ?? _queueStatusMessage;

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
              children: [
                const Icon(Icons.camera_alt, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _queueStatusMessage != null
                      ? _scanText('captureQueuedButton', '가격표 계속 찍기')
                      : _scanText('captureButton', '가격표 인식하기'),
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
            isBusy: false,
            capturedImagePath: _capturedPath,
            onRecognize: (imagePath) async {
              _enqueueCapturedImage(imagePath);
            },
            onClose: _closeScanner,
            onRetake: () async {
              final path = _capturedPath;
              setState(() {
                _capturedPath = null;
                _statusMessage = null;
              });
              if (path != null) {
                try {
                  await File(path).delete();
                } catch (_) {}
              }
            },
          ),
          if (scanStatusMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                scanStatusMessage,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ] else if (scanStatusMessage != null &&
            (isOcrRunning ||
                _pendingJobId != null ||
                _queuedImagePaths.isNotEmpty)) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              scanStatusMessage,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (_captureWaitingEntries.isNotEmpty) ...[
          _ScanInboxCard(
            title: '촬영 대기열',
            summaryText: _captureQueueSummaryText,
            entries: _captureWaitingEntries,
            activeEntryId: _activeQueueEntryId,
            onActivate: (_) {},
            onDismiss: _removeQueueEntry,
          ),
          const SizedBox(height: 12),
        ],

        if (_processingEntries.isNotEmpty) ...[
          _ScanInboxCard(
            title: '분석/검토 처리함',
            summaryText: _processingQueueSummaryText,
            entries: _processingEntries,
            activeEntryId: _activeQueueEntryId,
            onActivate: (entry) {
              if (entry.status != _ScanQueueStatus.ready ||
                  entry.item == null) {
                return;
              }
              setState(() {
                _activateReadyEntry(entry);
              });
            },
            onDismiss: _removeQueueEntry,
          ),
          const SizedBox(height: 12),
        ],

        // 인식 결과 (직접 추가하기 위)
        if (showResultCard && !manualEntryOpen) ...[
          RecognizedResultCard(
            title: _scanText('recognizedTitle', '지금 검토할 항목'),
            item: recognized!,
            onChanged: (u) {
              setState(() {
                recognized = u;
                if (_activeQueueEntryId != null) {
                  _updateQueueEntry(_activeQueueEntryId!, item: u);
                }
              });
              widget.onRecognized?.call(u);
            },
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

enum _ScanQueueStatus { captured, uploading, processing, ready, failed, added }

class _ScanQueueEntry {
  final String id;
  final String? imagePath;
  final _ScanQueueStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final RecognizedItem? item;
  final RecognizedItemCandidate? candidate;
  final String? errorMessage;

  const _ScanQueueEntry({
    required this.id,
    required this.status,
    required this.createdAt,
    this.imagePath,
    this.completedAt,
    this.item,
    this.candidate,
    this.errorMessage,
  });

  _ScanQueueEntry copyWith({
    String? id,
    String? imagePath,
    _ScanQueueStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    RecognizedItem? item,
    RecognizedItemCandidate? candidate,
    String? errorMessage,
  }) {
    return _ScanQueueEntry(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      item: item ?? this.item,
      candidate: candidate ?? this.candidate,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class _ScanInboxCard extends StatelessWidget {
  final String title;
  final String summaryText;
  final List<_ScanQueueEntry> entries;
  final String? activeEntryId;
  final ValueChanged<_ScanQueueEntry> onActivate;
  final ValueChanged<_ScanQueueEntry> onDismiss;

  const _ScanInboxCard({
    required this.title,
    required this.summaryText,
    required this.entries,
    required this.activeEntryId,
    required this.onActivate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            summaryText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          ...entries.map((entry) {
            final isActive = entry.id == activeEntryId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ScanInboxRow(
                entry: entry,
                isActive: isActive,
                onTap: entry.status == _ScanQueueStatus.ready
                    ? () => onActivate(entry)
                    : null,
                onDismiss: () => onDismiss(entry),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ScanInboxRow extends StatelessWidget {
  final _ScanQueueEntry entry;
  final bool isActive;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _ScanInboxRow({
    required this.entry,
    required this.isActive,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = switch (entry.status) {
      _ScanQueueStatus.failed => (
        bg: const Color(0xFFFFF1F1),
        fg: const Color(0xFFB42318),
        label: '실패',
      ),
      _ScanQueueStatus.added => (
        bg: const Color(0xFFEAF7EE),
        fg: const Color(0xFF2E7D32),
        label: '담기 완료',
      ),
      _ScanQueueStatus.ready => (
        bg: const Color(0xFFFFF4E5),
        fg: const Color(0xFFB26A00),
        label: isActive ? '검토 중' : '검토 대기',
      ),
      _ScanQueueStatus.processing => (
        bg: const Color(0xFFF3F4F6),
        fg: Colors.black87,
        label: '분석 중',
      ),
      _ScanQueueStatus.uploading => (
        bg: const Color(0xFFF3F4F6),
        fg: Colors.black87,
        label: '업로드 중',
      ),
      _ScanQueueStatus.captured => (
        bg: const Color(0xFFEEF2FF),
        fg: const Color(0xFF344054),
        label: '촬영 완료',
      ),
    };
    final title =
        entry.item?.name ??
        entry.errorMessage ??
        _scanText('queueUntitled', '새 가격표');
    final subtitle = switch (entry.status) {
      _ScanQueueStatus.failed =>
        entry.errorMessage ?? _scanText('processingError', '분석 처리 중 오류가 났어요'),
      _ScanQueueStatus.added => '카트에 담았어요',
      _ScanQueueStatus.ready =>
        entry.item == null ? '결과를 확인해 주세요' : '₩${_fmt(entry.item!.price)}',
      _ScanQueueStatus.processing => '결과를 읽는 중',
      _ScanQueueStatus.uploading => '이미지를 올리는 중',
      _ScanQueueStatus.captured => '아직 분석 전, 순서대로 처리될 예정',
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  palette.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: palette.fg,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (entry.status == _ScanQueueStatus.ready && !isActive)
                const Icon(Icons.chevron_right, color: Colors.black38),
              IconButton(
                tooltip: _scanText('recentDismiss', '지우기'),
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
