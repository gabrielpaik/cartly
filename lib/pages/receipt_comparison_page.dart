// ignore_for_file: unused_element, unused_element_parameter

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/cartly_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/receipt_compare.dart';
import '../models/saved_cart.dart';
import '../services/app_runtime_copy.dart';
import '../services/auth_store.dart';
import '../services/remote_receipt_repository.dart';
import '../widgets/cartly_badge.dart';
import '../widgets/cartly_info_card.dart';
import '../widgets/cartly_surface_card.dart';
import '../widgets/cartly_symbol_icon.dart';

final _receiptMoneyFormatter = NumberFormat('#,###');
String _receiptFmt(int value) => _receiptMoneyFormatter.format(value);

bool _isReceiptPurchasableLineItem(ReceiptLineItemModel item) {
  final amount = item.finalAmount ?? item.lineAmount;
  if (item.category != 'item') {
    return false;
  }
  if (amount <= 0) {
    return false;
  }
  return item.rawName.trim().isNotEmpty;
}

String _receiptSupportingLineItemLabel(ReceiptLineItemModel item) {
  switch (item.category) {
    case 'discount':
      return '할인';
    case 'coupon':
      return '쿠폰';
    case 'tax':
      return '세금';
    case 'subtotal':
      return '소계';
    case 'payment':
      return '결제';
    default:
      return '참고';
  }
}

bool _isReceiptItemLinkedAdjustment(ReceiptLineItemModel item) {
  if (item.category != 'discount' && item.category != 'coupon') {
    return false;
  }
  final amount = item.finalAmount ?? item.lineAmount;
  return amount < 0;
}

class _ReceiptPurchasedEntry {
  final ReceiptLineItemModel item;
  final List<ReceiptLineItemModel> linkedAdjustments;

  const _ReceiptPurchasedEntry({
    required this.item,
    required this.linkedAdjustments,
  });
}

class ReceiptCheckPage extends StatefulWidget {
  final SavedCart cart;

  const ReceiptCheckPage({super.key, required this.cart});

  @override
  State<ReceiptCheckPage> createState() => _ReceiptCheckPageState();
}

class _ReceiptCheckPageState extends State<ReceiptCheckPage> {
  final RemoteReceiptRepository _repository = RemoteReceiptRepository(
    authTokenProvider: () => AuthStore.instance.session.value?.authToken,
  );

  _ReceiptCompareUiState _state = _ReceiptCompareUiState.idle;
  ReceiptSummaryModel? _receipt;
  ReceiptCompareResultModel? _result;
  String? _receiptId;
  String? _errorMessage;
  String? _capturedImagePath;
  String _progressMessage = '영수증을 올리는 중';

  @override
  void initState() {
    super.initState();
    final existingReceiptId = widget.cart.receiptStatus?.receiptId;
    if (existingReceiptId != null && existingReceiptId.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resumeExistingReceipt(existingReceiptId);
      });
    }
  }

  bool get _isBusy =>
      _state == _ReceiptCompareUiState.uploading ||
      _state == _ReceiptCompareUiState.processing;

  bool _ensureSignedIn() {
    final session = AuthStore.instance.session.value;
    if (session == null || session.authToken.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 후 영수증 확인을 사용할 수 있어요')));
      return false;
    }
    return true;
  }

  Future<void> _resumeExistingReceipt(String receiptId) async {
    if (!_ensureSignedIn()) return;
    if (!mounted) return;

    setState(() {
      _receiptId = receiptId;
      _state = _ReceiptCompareUiState.processing;
      _progressMessage = '저장된 영수증 결과를 불러오는 중';
      _errorMessage = null;
    });

    try {
      final receipt = await _repository.getReceipt(receiptId);
      if (!mounted) return;

      if (receipt.status == 'failed') {
        setState(() {
          _receipt = receipt;
          _state = _ReceiptCompareUiState.error;
          _errorMessage = receipt.errorMessage ?? '영수증 분석에 실패했어요';
        });
        return;
      }

      if (receipt.status != 'ready') {
        setState(() {
          _receipt = receipt;
          _state = _ReceiptCompareUiState.error;
          _errorMessage = '영수증 정리가 아직 끝나지 않았어요. 잠시 후 다시 불러와 주세요';
        });
        return;
      }

      setState(() {
        _receipt = receipt;
      });
      await _loadResult(receiptId);
    } on RemoteReceiptException catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _ReceiptCompareUiState.error;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _ReceiptCompareUiState.error;
        _errorMessage = '저장된 영수증을 불러오지 못했어요';
      });
    }
  }

  Future<void> _startCameraCaptureFlow() async {
    if (_isBusy) return;
    if (!_ensureSignedIn()) return;

    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _ReceiptCameraCapturePage()),
    );
    if (!mounted || imagePath == null || imagePath.trim().isEmpty) {
      return;
    }

    await _createAndLoadReceipt(imagePath);
  }

  Future<void> _createAndLoadReceipt(String imagePath) async {
    setState(() {
      _capturedImagePath = imagePath;
      _state = _ReceiptCompareUiState.uploading;
      _result = null;
      _receipt = null;
      _receiptId = null;
      _errorMessage = null;
      _progressMessage = '영수증을 올리는 중';
    });

    try {
      final receipt = await _repository.createReceipt(
        savedCartId: widget.cart.id,
        imagePath: imagePath,
      );
      if (!mounted) return;

      if (receipt.status == 'failed') {
        setState(() {
          _receipt = receipt;
          _receiptId = receipt.id;
          _state = _ReceiptCompareUiState.error;
          _errorMessage = receipt.errorMessage ?? '영수증 분석에 실패했어요';
        });
        return;
      }

      if (receipt.status != 'ready') {
        setState(() {
          _receipt = receipt;
          _receiptId = receipt.id;
          _state = _ReceiptCompareUiState.error;
          _errorMessage = '영수증 정리가 아직 끝나지 않았어요. 잠시 후 다시 불러와 주세요';
        });
        return;
      }

      setState(() {
        _receipt = receipt;
        _receiptId = receipt.id;
        _state = _ReceiptCompareUiState.processing;
        _progressMessage = '영수증 결과를 불러오는 중';
      });

      await _loadResult(receipt.id);
    } on RemoteReceiptException catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _ReceiptCompareUiState.error;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _ReceiptCompareUiState.error;
        _errorMessage = '영수증 정리를 시작하지 못했어요';
      });
    }
  }

  Future<void> _loadResult(String receiptId) async {
    if (!mounted) return;

    setState(() {
      _state = _ReceiptCompareUiState.processing;
      _progressMessage = '영수증 결과를 불러오는 중';
      _errorMessage = null;
    });

    try {
      final result = await _repository.getResult(receiptId);
      if (!mounted) return;
      setState(() {
        _result = result;
        _receipt = result.receipt;
        _receiptId = result.receipt.id;
        _state = _ReceiptCompareUiState.ready;
      });
    } on RemoteReceiptException catch (error) {
      if (!mounted) return;

      setState(() {
        _state = _ReceiptCompareUiState.error;
        _errorMessage = error.code == 'RESULT_NOT_READY'
            ? '영수증 정리가 아직 끝나지 않았어요. 잠시 후 다시 불러와 주세요'
            : error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _ReceiptCompareUiState.error;
        _errorMessage = '영수증 결과를 불러오지 못했어요';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewData = _result == null
        ? null
        : _ReceiptSimpleViewData.fromResult(_result!, widget.cart);

    return Scaffold(
      backgroundColor: CartlyColors.surface1,
      appBar: AppBar(
        backgroundColor: CartlyColors.surface1,
        elevation: 0,
        surfaceTintColor: CartlyColors.surface1,
        foregroundColor: CartlyColors.textPrimary,
        title: const Text('영수증 확인'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _ReceiptCompareContextCard(cart: widget.cart),
            const SizedBox(height: 12),
            if (!kIsWeb && _capturedImagePath != null) ...[
              _ReceiptCapturedPreviewCard(imagePath: _capturedImagePath!),
              const SizedBox(height: 12),
            ],
            if (viewData == null &&
                !_isBusy &&
                _state != _ReceiptCompareUiState.error)
              _ReceiptCompareCaptureCard(
                onOpenUploadFlow: _startCameraCaptureFlow,
              ),
            if (_isBusy)
              _ReceiptCompareProcessingCard(
                message: _progressMessage,
                receipt: _receipt,
              ),
            if (_state == _ReceiptCompareUiState.error)
              _ReceiptCompareErrorCard(
                message: _errorMessage ?? '영수증 결과를 불러오지 못했어요',
                onRetryCapture: _startCameraCaptureFlow,
                onRetryLoad: _receiptId == null
                    ? null
                    : () => _loadResult(_receiptId!),
              ),
            if (viewData != null) ...[
              _ReceiptSimpleSummaryCard(data: viewData),
              const SizedBox(height: 12),
              _ReceiptFinalPriceCompareCard(data: viewData),
              const SizedBox(height: 12),
              _ReceiptStoredDetailsCard(data: viewData),
              const SizedBox(height: 16),
              _ReceiptResultActionsCard(
                onRetake: _startCameraCaptureFlow,
                onRefresh: _receiptId == null
                    ? null
                    : () => _loadResult(_receiptId!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ReceiptCompareUiState { idle, uploading, processing, ready, error }

class _ReceiptCompareContextCard extends StatelessWidget {
  final SavedCart cart;

  const _ReceiptCompareContextCard({required this.cart});

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('M월 d일 HH:mm').format(cart.createdAt);

    return CartlySurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CartlyBadge(
            label: AppRuntimeCopy.text([
              'receiptCompare',
              'savedCartOnlyBadge',
            ], '저장된 카트 기준 확인'),
            backgroundColor: CartlyColors.surface1,
            foregroundColor: CartlyColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: 12),
          Text(
            cart.title?.trim().isNotEmpty == true
                ? cart.title!.trim()
                : '$dateText 카트',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '$dateText · ${cart.totalCount}개 항목 · 예상 ₩${_receiptFmt(cart.totalPrice)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CartlyColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppRuntimeCopy.text([
              'receiptCompare',
              'contextBody',
            ], '이 저장본을 기준으로 영수증 요약과 상세 내역을 확인해요.'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CartlyColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCompareCaptureCard extends StatelessWidget {
  final Future<void> Function() onOpenUploadFlow;

  const _ReceiptCompareCaptureCard({required this.onOpenUploadFlow});

  @override
  Widget build(BuildContext context) {
    return CartlySurfaceCard(
      backgroundColor: const Color(0xFFFFF7ED),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '실제 영수증을 찍어서 비교해요',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '영수증 전체가 한 장에 들어오게 맞추고, 총액과 상품 목록이 잘 보이도록 촬영해 주세요.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CartlyColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: onOpenUploadFlow,
              style: CartlyButtonStyles.primary(),
              icon: const CartlySymbolIcon.sf('receipt'),
              label: const Text(
                '영수증 올리기',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCapturedPreviewCard extends StatelessWidget {
  final String imagePath;

  const _ReceiptCapturedPreviewCard({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: CartlyColors.surface2,
        borderRadius: BorderRadius.circular(CartlyRadii.card),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CartlyRadii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(file, fit: BoxFit.cover),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Text(
                '방금 올린 영수증',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCompareProcessingCard extends StatelessWidget {
  final String message;
  final ReceiptSummaryModel? receipt;

  const _ReceiptCompareProcessingCard({
    required this.message,
    required this.receipt,
  });

  @override
  Widget build(BuildContext context) {
    return CartlyInfoCard(
      padding: const EdgeInsets.all(18),
      header: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 12),
          Expanded(child: SizedBox.shrink()),
        ],
      ),
      title: '영수증 정리 진행 중',
      body: message,
      bodyColor: CartlyColors.textPrimary,
      footer: receipt == null
          ? null
          : Text(
              'receipt id ${receipt!.id}',
              style: CartlyText.cardMeta.copyWith(color: Colors.black45),
            ),
    );
  }
}

class _ReceiptCompareErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetryCapture;
  final Future<void> Function()? onRetryLoad;

  const _ReceiptCompareErrorCard({
    required this.message,
    required this.onRetryCapture,
    this.onRetryLoad,
  });

  @override
  Widget build(BuildContext context) {
    return CartlyInfoCard(
      backgroundColor: const Color(0xFFFFF1F2),
      title: '영수증 정리를 끝내지 못했어요',
      body: message,
      footer: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: onRetryCapture,
              style: CartlyButtonStyles.primary(),
              child: const Text(
                '다시 촬영',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (onRetryLoad != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onRetryLoad,
                style: CartlyButtonStyles.secondaryOutline(
                  foregroundColor: CartlyColors.textPrimary,
                  borderColor: CartlyColors.lineStrong,
                ),
                child: const Text(
                  '다시 불러오기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptSimpleViewData {
  final String merchantName;
  final String purchasedAtText;
  final int purchasedItemCount;
  final int actualTotal;
  final int cartTotal;
  final int totalDelta;
  final int totalDiscount;
  final bool hasStoredImage;
  final String? rawText;
  final List<_ReceiptPurchasedEntry> purchasedEntries;
  final List<ReceiptLineItemModel> supportingLineItems;

  const _ReceiptSimpleViewData({
    required this.merchantName,
    required this.purchasedAtText,
    required this.purchasedItemCount,
    required this.actualTotal,
    required this.cartTotal,
    required this.totalDelta,
    required this.totalDiscount,
    required this.hasStoredImage,
    required this.rawText,
    required this.purchasedEntries,
    required this.supportingLineItems,
  });

  factory _ReceiptSimpleViewData.fromResult(
    ReceiptCompareResultModel result,
    SavedCart cart,
  ) {
    final receipt = result.receipt;
    final purchasedEntries = <_ReceiptPurchasedEntry>[];
    final supportingLineItems = <ReceiptLineItemModel>[];
    var canLinkAdjustmentToLastItem = false;

    for (final lineItem in result.lineItems) {
      if (_isReceiptPurchasableLineItem(lineItem)) {
        purchasedEntries.add(
          _ReceiptPurchasedEntry(item: lineItem, linkedAdjustments: []),
        );
        canLinkAdjustmentToLastItem = true;
        continue;
      }

      if (_isReceiptItemLinkedAdjustment(lineItem) &&
          canLinkAdjustmentToLastItem &&
          purchasedEntries.isNotEmpty) {
        purchasedEntries.last.linkedAdjustments.add(lineItem);
        continue;
      }

      supportingLineItems.add(lineItem);
      canLinkAdjustmentToLastItem = false;
    }

    final purchasedItemCount = purchasedEntries.fold<int>(
      0,
      (sum, entry) =>
          sum +
          ((entry.item.quantity ?? 1) > 0 ? (entry.item.quantity ?? 1) : 1),
    );
    final actualTotal = receipt.totalAmount ?? 0;
    final cartTotal = cart.totalPrice;

    return _ReceiptSimpleViewData(
      merchantName: receipt.merchantName?.trim().isNotEmpty == true
          ? receipt.merchantName!.trim()
          : '영수증 확인 결과',
      purchasedAtText: receipt.purchasedAt == null
          ? '결제 시각 미상'
          : DateFormat('M월 d일 HH:mm').format(receipt.purchasedAt!.toLocal()),
      purchasedItemCount: purchasedItemCount > 0
          ? purchasedItemCount
          : purchasedEntries.length,
      actualTotal: actualTotal,
      cartTotal: cartTotal,
      totalDelta: actualTotal - cartTotal,
      totalDiscount: receipt.totalDiscountAmount ?? 0,
      hasStoredImage: receipt.imageUrl?.trim().isNotEmpty == true,
      rawText: receipt.rawText?.trim(),
      purchasedEntries: purchasedEntries,
      supportingLineItems: supportingLineItems,
    );
  }
}

class _ReceiptSimpleSummaryCard extends StatelessWidget {
  final _ReceiptSimpleViewData data;

  const _ReceiptSimpleSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return CartlySurfaceCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: CartlyColors.subBrand,
      radius: CartlyRadii.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: CartlyColors.surface1,
              borderRadius: BorderRadius.circular(CartlyRadii.pill),
            ),
            child: Text(
              data.merchantName,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: CartlyColors.subBrand,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '영수증으로 확인한 결과, ${data.purchasedItemCount}개의 상품 ${_receiptFmt(data.actualTotal)}원에 구매했어요!',
            style: const TextStyle(
              fontSize: 22,
              height: 1.35,
              fontWeight: FontWeight.w700,
              color: CartlyColors.onBrandPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '상세내역을 확인하여 비교해보세요',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: CartlyColors.onBrandMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.purchasedAtText,
            style: const TextStyle(
              fontSize: 13,
              color: CartlyColors.onBrandMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptFinalPriceCompareCard extends StatelessWidget {
  final _ReceiptSimpleViewData data;

  const _ReceiptFinalPriceCompareCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final delta = data.totalDelta;
    final deltaText = delta == 0
        ? '카트 총액과 같아요'
        : delta > 0
        ? '영수증 총액이 ${_receiptFmt(delta)}원 더 커요'
        : '카트 총액이 ${_receiptFmt(delta.abs())}원 더 커요';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CartlyColors.onBrandPrimary,
        borderRadius: BorderRadius.circular(CartlyRadii.card),
        border: Border.all(color: CartlyColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최종 가격 비교',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ReceiptAmountBox(label: '내 카트', amount: data.cartTotal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReceiptAmountBox(
                  label: '영수증',
                  amount: data.actualTotal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            deltaText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: delta == 0
                  ? CartlyColors.semanticSuccess
                  : CartlyColors.semanticWarning,
            ),
          ),
          if (data.totalDiscount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '할인/조정 합계 ${_receiptFmt(data.totalDiscount)}원',
              style: const TextStyle(
                fontSize: 13,
                color: CartlyColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptAmountBox extends StatelessWidget {
  final String label;
  final int amount;

  const _ReceiptAmountBox({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CartlyColors.surface2,
        borderRadius: BorderRadius.circular(CartlyRadii.control),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CartlyColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_receiptFmt(amount)}원',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ReceiptStoredDetailsCard extends StatefulWidget {
  final _ReceiptSimpleViewData data;

  const _ReceiptStoredDetailsCard({required this.data});

  @override
  State<_ReceiptStoredDetailsCard> createState() =>
      _ReceiptStoredDetailsCardState();
}

class _ReceiptStoredDetailsCardState extends State<_ReceiptStoredDetailsCard> {
  bool _showRawText = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CartlyColors.onBrandPrimary,
        borderRadius: BorderRadius.circular(CartlyRadii.card),
        border: Border.all(color: CartlyColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상세 내역',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            data.hasStoredImage
                ? '영수증 이미지와 텍스트를 저장해 두었어요.'
                : '영수증 텍스트를 저장해 두었어요.',
            style: const TextStyle(
              fontSize: 13,
              color: CartlyColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '텍스트로 정리한 상품 목록',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (data.purchasedEntries.isEmpty)
            Text(
              '정리된 상품 목록이 아직 없어요.',
              style: const TextStyle(
                fontSize: 13,
                color: CartlyColors.textSecondary,
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: CartlyColors.surface2,
                borderRadius: BorderRadius.circular(CartlyRadii.control),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final entry in data.purchasedEntries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.item.rawName.trim().isEmpty
                                        ? '이름 미상 상품'
                                        : entry.item.rawName.trim(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if ((entry.item.quantity ?? 1) > 1) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'x${entry.item.quantity}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: CartlyColors.textSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 12),
                                Text(
                                  '${_receiptFmt(entry.item.finalAmount ?? entry.item.lineAmount)}원',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            if (entry.linkedAdjustments.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              for (final adjustment in entry.linkedAdjustments)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    top: 4,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              adjustment.rawName.trim().isEmpty
                                                  ? '연결된 할인'
                                                  : adjustment.rawName.trim(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    CartlyColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_receiptSupportingLineItemLabel(adjustment)} 항목',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    CartlyColors.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${_receiptFmt(adjustment.finalAmount ?? adjustment.lineAmount)}원',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: CartlyColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (data.supportingLineItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '할인/세금/결제 참고 내역',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: CartlyColors.surface2,
                borderRadius: BorderRadius.circular(CartlyRadii.control),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final item in data.supportingLineItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.rawName.trim().isEmpty
                                        ? '이름 미상 항목'
                                        : item.rawName.trim(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _receiptSupportingLineItemLabel(item),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: CartlyColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${_receiptFmt(item.finalAmount ?? item.lineAmount)}원',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (data.rawText != null && data.rawText!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '추출된 원문 텍스트',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              '원문 텍스트는 기본으로 가려 두었어요.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CartlyColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showRawText = !_showRawText;
                  });
                },
                style: CartlyButtonStyles.secondaryOutline(
                  foregroundColor: CartlyColors.textPrimary,
                  borderColor: CartlyColors.lineStrong,
                ),
                icon: CartlySymbolIcon.sf(
                  _showRawText ? 'eyeglasses.slash' : 'eyeglasses',
                  size: 18,
                ),
                label: Text(_showRawText ? '원문 텍스트 숨기기' : '원문 텍스트 보기'),
              ),
            ),
            if (_showRawText) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CartlyColors.surface2,
                  borderRadius: BorderRadius.circular(CartlyRadii.control),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    data.rawText!,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReceiptResultActionsCard extends StatelessWidget {
  final VoidCallback onRetake;
  final VoidCallback? onRefresh;

  const _ReceiptResultActionsCard({
    required this.onRetake,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onRefresh,
            style: CartlyButtonStyles.secondaryOutline(
              foregroundColor: CartlyColors.textPrimary,
              borderColor: CartlyColors.lineStrong,
            ),
            icon: const CartlySymbolIcon.sf('arrow.clockwise', size: 18),
            label: const Text(
              '다시 불러오기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: onRetake,
            style: CartlyButtonStyles.primary(),
            icon: const CartlySymbolIcon.sf('camera.fill', size: 18),
            label: const Text(
              '영수증 다시 올리기',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptCameraCapturePage extends StatefulWidget {
  const _ReceiptCameraCapturePage();

  @override
  State<_ReceiptCameraCapturePage> createState() =>
      _ReceiptCameraCapturePageState();
}

class _ReceiptCameraCapturePageState extends State<_ReceiptCameraCapturePage> {
  CameraController? _controller;
  List<CameraDescription> _backCameras = const [];
  CameraDescription? _selectedCamera;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isPickingFromGallery = false;
  String? _errorMessage;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera([CameraDescription? preferredCamera]) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
          _errorMessage = '사용 가능한 카메라를 찾지 못했어요';
        });
        return;
      }

      final backCameras = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back)
          .toList();
      final targetPool = backCameras.isEmpty ? cameras : backCameras;
      final selected = preferredCamera ?? _pickDefaultReceiptCamera(targetPool);

      await _controller?.dispose();

      final controller = CameraController(
        selected,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      await controller.initialize();

      try {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = await controller.getMaxZoomLevel();
      } catch (_) {
        _minZoom = 1.0;
        _maxZoom = 1.0;
      }
      _currentZoom = _minZoom.clamp(1.0, _maxZoom);
      _baseZoom = _currentZoom;
      try {
        await controller.setZoomLevel(_currentZoom);
      } catch (_) {}

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _backCameras = targetPool;
        _selectedCamera = selected;
        _isInitializing = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = '카메라를 열지 못했어요. 권한을 확인해 주세요';
      });
    }
  }

  CameraDescription _pickDefaultReceiptCamera(List<CameraDescription> cameras) {
    CameraDescription? ultraWide;
    CameraDescription? standard;
    CameraDescription? tele;

    for (final camera in cameras) {
      final name = camera.name.toLowerCase();
      if (name.contains('ultra')) {
        ultraWide ??= camera;
      } else if (name.contains('tele')) {
        tele ??= camera;
      } else {
        standard ??= camera;
      }
    }

    return standard ?? ultraWide ?? tele ?? cameras.first;
  }

  String _cameraLabel(CameraDescription camera) {
    final name = camera.name.toLowerCase();
    if (name.contains('ultra')) return '0.5x';
    if (name.contains('tele')) return '2x';
    return '1x';
  }

  Future<void> _switchCamera(CameraDescription camera) async {
    if (_isInitializing || _isCapturing || _isPickingFromGallery) return;
    if (_selectedCamera?.name == camera.name) return;

    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });
    await _initializeCamera(camera);
  }

  Future<void> _setZoomLevel(double zoom) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = zoom.clamp(_minZoom, _maxZoom);
    try {
      await controller.setZoomLevel(next);
      if (!mounted) return;
      setState(() {
        _currentZoom = next;
        _baseZoom = next;
      });
    } catch (_) {}
  }

  Future<void> _capture() async {
    if (_isCapturing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final file = await _controller!.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _errorMessage = '영수증 촬영에 실패했어요';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isPickingFromGallery || _isCapturing) return;

    setState(() => _isPickingFromGallery = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (!mounted) return;
      if (picked == null || picked.path.trim().isEmpty) {
        setState(() => _isPickingFromGallery = false);
        return;
      }
      Navigator.of(context).pop(picked.path);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPickingFromGallery = false;
        _errorMessage = '사진첩에서 이미지를 가져오지 못했어요';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CartlyColors.contrast,
      appBar: AppBar(
        backgroundColor: CartlyColors.contrast,
        foregroundColor: CartlyColors.onBrandPrimary,
        title: const Text('영수증 촬영'),
      ),
      body: SafeArea(
        child: _errorMessage != null
            ? _buildBody()
            : Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _buildBody(),
                    ),
                  ),
                  _buildCameraControls(),
                ],
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CartlySymbolIcon.sf(
                'camera',
                color: CartlyColors.onBrandMuted,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CartlyColors.onBrandPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isInitializing
                    ? null
                    : () {
                        setState(() {
                          _isInitializing = true;
                          _errorMessage = null;
                        });
                        _initializeCamera();
                      },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitializing ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final controller = _controller!;
    const previewAspectRatio = 3 / 4;

    return GestureDetector(
      onScaleStart: (_) {
        _baseZoom = _currentZoom;
      },
      onScaleUpdate: (details) {
        final targetZoom = (_baseZoom * details.scale).clamp(
          _minZoom,
          _maxZoom,
        );
        if ((targetZoom - _currentZoom).abs() < 0.02) return;
        _setZoomLevel(targetZoom);
      },
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: previewAspectRatio,
            child: CameraPreview(controller),
          ),
          Positioned(
            left: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF232323),
                borderRadius: BorderRadius.circular(CartlyRadii.pill),
              ),
              child: Text(
                'x${_currentZoom.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: CartlyColors.onBrandPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraControls() {
    final isBusy = _isInitializing || _isCapturing || _isPickingFromGallery;
    final lensButtons = _backCameras.map((camera) {
      final label = _cameraLabel(camera);
      final selected = _selectedCamera?.name == camera.name;
      return GestureDetector(
        onTap: isBusy ? null : () => _switchCamera(camera),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3B3B3B) : Colors.transparent,
            borderRadius: BorderRadius.circular(CartlyRadii.pill),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFFFD54F)
                  : CartlyColors.onBrandMuted,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }).toList();

    return Container(
      color: CartlyColors.textPrimary,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lensButtons.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: lensButtons,
            ),
            const SizedBox(height: 18),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: OutlinedButton(
                  onPressed: isBusy ? null : _pickFromGallery,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CartlyColors.onBrandPrimary,
                    side: const BorderSide(
                      color: CartlyColors.onBrandMuted,
                      width: 0.5,
                    ),
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: _isPickingFromGallery
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: CartlyColors.onBrandPrimary,
                          ),
                        )
                      : const CartlySymbolIcon.sf('photo.on.rectangle.angled'),
                ),
              ),
              SizedBox(
                width: 84,
                height: 84,
                child: FilledButton(
                  onPressed: isBusy ? null : _capture,
                  style: FilledButton.styleFrom(
                    backgroundColor: CartlyColors.surface1,
                    foregroundColor: CartlyColors.textPrimary,
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  child: _isCapturing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : const CartlySymbolIcon.sf(
                          'camera.fill',
                          size: CartlyIconSizes.hero,
                        ),
                ),
              ),
              const SizedBox(width: 56, height: 56),
            ],
          ),
        ],
      ),
    );
  }
}
