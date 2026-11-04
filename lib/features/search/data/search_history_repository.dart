import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap.dart';
import '../../catalog/domain/catalog_models.dart';

final searchHistoryRepositoryProvider = Provider(
  (ref) => SearchHistoryRepository(ref.watch(apiDioProvider)),
);

class SearchHistoryEntry {
  SearchHistoryEntry.fromJson(Map<String, dynamic> json)
    : id = requiredText(json, 'id'),
      keyword = requiredText(json, 'keyword'),
      mood = json['searchType'] == 'EMOTION';
  final String id, keyword;
  final bool mood;
}

class SearchHistoryRepository {
  SearchHistoryRepository(this.dio);
  final Dio dio;
  Future<List<SearchHistoryEntry>> load() async {
    final json = objectJson(
      (await dio.get<Object?>(
        'users/me/search-history',
        queryParameters: {'size': 20},
      )).data,
    );
    final items = json['content'];
    if (items is! List) throw const FormatException('Invalid history');
    return items
        .map((e) => SearchHistoryEntry.fromJson(objectJson(e)))
        .toList();
  }

  Future<void> record(String keyword, bool mood) async {
    await dio.post<Object?>(
      'users/me/search-history',
      data: {'keyword': keyword, 'searchType': mood ? 'EMOTION' : 'TRACK'},
    );
  }

  Future<void> remove(String? id) async {
    await dio.delete<Object?>(
      'users/me/search-history${id == null ? '' : '/${segment(id)}'}',
    );
  }
}
