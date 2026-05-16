import 'package:intl/intl.dart';

import '../models/saved_cart.dart';
import '../services/admob_service.dart';
import '../services/app_runtime_copy.dart';

SavedCart cloneSavedCartSnapshot(SavedCart source) {
  return SavedCart(
    id: source.id,
    title: source.title,
    createdAt: source.createdAt,
    updatedAt: source.updatedAt,
    expiresAt: source.expiresAt,
    isExpired: source.isExpired,
    retentionExtensionCount: source.retentionExtensionCount,
    canExtendRetention: source.canExtendRetention,
    receiptStatus: source.receiptStatus == null
        ? null
        : SavedCartReceiptStatus(
            receiptId: source.receiptStatus!.receiptId,
            receiptStatus: source.receiptStatus!.receiptStatus,
            merchantName: source.receiptStatus!.merchantName,
            hasReceipt: source.receiptStatus!.hasReceipt,
            updatedAt: source.receiptStatus!.updatedAt,
            completedAt: source.receiptStatus!.completedAt,
          ),
    items: source.items
        .map(
          (item) => SavedCartItem(
            name: item.name,
            price: item.price,
            quantity: item.quantity,
            source: item.source,
            scanResultId: item.scanResultId,
            originalName: item.originalName,
          ),
        )
        .toList(),
  );
}

String? cartDetailInlineEditValidationMessage({
  required String nameText,
  required String priceText,
}) {
  final newName = nameText.trim();
  final newPrice = int.tryParse(priceText.replaceAll(',', '').trim()) ?? 0;
  if (newName.isEmpty || newPrice <= 0) {
    return AppRuntimeCopy.text(
      ['cartDetail', 'validation', 'namePriceRequired'],
      '상품명/가격을 확인해주세요',
    );
  }
  return null;
}

String? cartDetailSaveValidationMessage(List<SavedCartItem> items) {
  for (final item in items) {
    item.name = item.name.trim();
    if (item.name.isEmpty) {
      return AppRuntimeCopy.text(
        ['cartDetail', 'validation', 'nameRequired'],
        '상품명이 비어있어요',
      );
    }
    if (item.price <= 0 || item.quantity <= 0) {
      return AppRuntimeCopy.text(
        ['cartDetail', 'validation', 'priceQuantityRequired'],
        '가격/수량을 확인해주세요',
      );
    }
  }
  return null;
}

String? cartDetailRetentionResultMessage(RewardedAdResult result) {
  return switch (result) {
    RewardedAdResult.dismissed => '광고를 끝까지 봐야 카트가 다시 열려요',
    RewardedAdResult.unavailable => '지금은 광고를 불러오지 못했어요. 잠시 후 다시 시도해주세요',
    RewardedAdResult.failedToShow => '광고를 여는 데 실패했어요. 잠시 후 다시 시도해주세요',
    RewardedAdResult.rewarded => null,
  };
}

String cartDetailRetentionExtendedMessage(SavedCart updatedCart) {
  if (updatedCart.expiresAt == null) {
    return '저장 기간을 연장했어요';
  }
  return '저장 기간이 ${DateFormat('M월 d일').format(updatedCart.expiresAt!)}까지 연장됐어요';
}
