import '../../catalog/domain/catalog_models.dart';

class SubscriptionInfo {
  SubscriptionInfo.fromJson(Map<String, dynamic> json)
    : name = requiredText(json, 'packageName'),
      premium = json['isPremium'] == true,
      tier = optionalText(json['tier']) ?? 'FREE',
      daysRemaining = json['daysRemaining'] is num
          ? (json['daysRemaining'] as num).toInt()
          : 0,
      expiresAt = optionalText(json['expiresAt']),
      syncedLyrics =
          json['entitlements'] is Map &&
          json['entitlements']['syncedLyrics'] == true;
  final String name;
  final String? expiresAt;
  // Ví dụ 'FREE' | 'INDIVIDUAL_BASIC' | 'INDIVIDUAL_FULL' | 'FAMILY'.
  final String tier;
  final int daysRemaining;
  final bool premium, syncedLyrics;
}

class PackageQuote {
  PackageQuote.fromJson(Map<String, dynamic> json)
    : id = requiredText(json, 'id'),
      name = requiredText(json, 'name'),
      amount = paymentAmount(json['amount']),
      days = (json['duration_days'] as num).toInt(),
      description = optionalText(json['description']),
      actionDescription = optionalText(json['actionDescription']),
      actionLabel = optionalText(json['actionLabel']) ?? 'Chọn gói',
      startAt = optionalText(json['startAt']);
  final String id, name, actionLabel;
  final num amount;
  final int days;
  final String? description, actionDescription, startAt;
}

class PaymentReceipt {
  PaymentReceipt.fromJson(Map<String, dynamic> json)
    : code = optionalText(json['orderCode']) ?? '',
      amount = paymentAmount(json['amount']),
      status = requiredText(json, 'status');
  final String code, status;
  final num amount;
}

class ManagedSubscription {
  ManagedSubscription.fromJson(Map<String, dynamic> json)
    : id = requiredText(json, 'id'),
      name = requiredText(json, 'packageName'),
      startAt = optionalText(json['startAt']),
      endAt = optionalText(json['endAt']),
      status = requiredText(json, 'status'),
      canCancel = json['canCancel'] == true,
      payments = List.unmodifiable(
        (json['payments'] as List? ?? []).map(
          (e) => PaymentReceipt.fromJson(objectJson(e)),
        ),
      );
  final String id, name, status;
  final String? startAt, endAt;
  final bool canCancel;
  final List<PaymentReceipt> payments;
}

class PaymentOrder {
  PaymentOrder.fromJson(Map<String, dynamic> json)
    : code = requiredText(json, 'orderCode'),
      packageName = requiredText(json, 'packageName'),
      amount = paymentAmount(json['amount']),
      qr = Uri.parse(requiredText(json, 'qrUrl')),
      account = requiredText(json, 'bankAccount'),
      bank = requiredText(json, 'bankName'),
      owner = requiredText(json, 'accountName'),
      content = requiredText(json, 'transferContent'),
      packageId = optionalText(json['packageId']),
      startAt = optionalText(json['startAt']),
      expiresAt = optionalText(json['expiresAt']),
      // Hạn chót của cửa sổ QR (15 phút kể từ lúc tạo đơn) — nguồn cho pill
      // đếm ngược; "expiresAt" là ngày kết thúc kỳ hạn dịch vụ.
      paymentExpiresAt = optionalText(json['paymentExpiresAt']) {
    if (json['success'] != true ||
        qr.scheme != 'https' ||
        qr.host.isEmpty ||
        qr.userInfo.isNotEmpty) {
      throw const FormatException('Invalid checkout');
    }
  }
  final String code, packageName, account, bank, owner, content;
  final String? packageId, startAt, expiresAt, paymentExpiresAt;
  final num amount;
  final Uri qr;
}

num paymentAmount(Object? value) {
  final amount = value is num ? value : num.tryParse(value?.toString() ?? '');
  if (amount == null || !amount.isFinite || amount < 0) {
    throw const FormatException('Invalid payment amount');
  }
  return amount;
}
