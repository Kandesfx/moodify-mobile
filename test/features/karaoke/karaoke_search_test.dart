import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodify_flutter/features/karaoke/data/karaoke_repository.dart';

import '../../support/auth_harness.dart';

void main() {
  test(
    'searches song and artist without accents across catalog pages',
    () async {
      final pages = <int>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/'));
      dio.httpClientAdapter = TestAdapter((request) {
        final page = int.parse(request.queryParameters['page'].toString());
        pages.add(page);
        return jsonResponse({
          'totalPages': 2,
          'content': page == 0
              ? [
                  {'title': 'Bóng Phù Hoa', 'artist': 'Phương Mỹ Chi'},
                ]
              : [
                  {'title': 'Một bài khác', 'artist': 'Quân A.P'},
                ],
        });
      });
      final repository = KaraokeRepository(dio);
      expect(
        (await repository.tracks(query: 'bong phu')).single['title'],
        'Bóng Phù Hoa',
      );
      expect(
        (await repository.tracks(query: 'quan')).single['artist'],
        'Quân A.P',
      );
      expect(await repository.tracks(query: 'không tồn tại'), isEmpty);
      expect(pages, [0, 1, 0, 1, 0, 1]);
      dio.close();
    },
  );
}
