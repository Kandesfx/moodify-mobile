import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../catalog/domain/catalog_models.dart';

final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(ref.watch(apiDioProvider)),
);

class InboxItem {
  InboxItem.fromJson(Map<String, dynamic> json)
    : id = requiredText(json, 'id'),
      title = requiredText(json, 'title'),
      message = optionalText(json['message']) ?? '',
      read = optionalText(json['readAt']) != null,
      link = optionalText(json['linkUrl']),
      createdAt = optionalText(json['createdAt']) ?? '';
  final String id, title, message, createdAt;
  final bool read;
  final String? link;
  String? get destination {
    final uri = Uri.tryParse(link ?? '');
    if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) {
      return null;
    }
    return uri.path == '/dashboard/premium' ? '/subscriptions' : null;
  }
}

class NotificationRepository {
  NotificationRepository(this.dio);
  final Dio dio;
  Future<List<InboxItem>> load() async {
    final json = objectJson(
      (await dio.get<Object?>(
        'notifications/me',
        queryParameters: {'limit': 50},
      )).data,
    );
    if (json['items'] is! List) throw const FormatException('Invalid inbox');
    return (json['items'] as List)
        .map((e) => InboxItem.fromJson(objectJson(e)))
        .toList();
  }

  Future<void> read(String? id) async => dio.post<Object?>(
    id == null ? 'notifications/read-all' : 'notifications/${segment(id)}/read',
  );
}
