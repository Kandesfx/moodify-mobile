import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/bootstrap.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/presentation/session_controller.dart';
import '../domain/catalog_models.dart';

class ArtistProfile {
  ArtistProfile.fromJson(Map<String, dynamic> json)
    : id = requiredText(json, 'artistId'),
      name = requiredText(json, 'name'),
      image = optionalText(json['imageUrl']),
      bio = optionalText(json['bio']),
      followed = json['isFollowed'] == true,
      followers = (json['followersCount'] as num?)?.toInt(),
      albums = (json['albums'] as List? ?? [])
          .map((e) => MusicCollection.fromJson(objectJson(e), album: true))
          .toList();
  final String id, name;
  final String? image, bio;
  final bool followed;
  final int? followers;
  final List<MusicCollection> albums;
}

class ArtistRepository {
  ArtistRepository(this.dio);
  final Dio dio;
  Future<ArtistProfile> profile(String id) async => ArtistProfile.fromJson(
    objectJson((await dio.get<Object?>('artists/${segment(id)}')).data),
  );
  Future<List<Artist>> followed() async {
    final raw = (await dio.get<Object?>('artists/followed')).data;
    if (raw is! List) throw const FormatException('Invalid followed artists');
    return raw.map((e) {
      final j = objectJson(e);
      return Artist.fromJson({...j, 'id': requiredText(j, 'artistId')});
    }).toList();
  }

  Future<void> toggle(String id) async {
    final json = objectJson(
      (await dio.post<Object?>('artists/${segment(id)}/follow')).data,
    );
    if (json['isFollowed'] is! bool) {
      throw const FormatException('Invalid follow result');
    }
  }
}

final artistRepositoryProvider = Provider((ref) {
  final user = ref.watch(
    sessionControllerProvider.select((s) => s.session?.user.id),
  );
  return ArtistRepository(
    ref.watch(user == null ? authDioProvider : apiDioProvider),
  );
});
final followedArtistsProvider = FutureProvider.autoDispose<List<Artist>>((
  ref,
) async {
  if (ref.watch(sessionControllerProvider.select((s) => s.session?.user.id)) ==
      null) {
    return [];
  }
  return ref.watch(artistRepositoryProvider).followed();
});
final artistProfileProvider = FutureProvider.autoDispose
    .family<ArtistProfile, String>(
      (ref, id) => ref.watch(artistRepositoryProvider).profile(id),
    );
final artistFollowActionProvider = StateNotifierProvider.autoDispose
    .family<ArtistFollowAction, AsyncValue<void>, String>((ref, id) {
      ref.watch(sessionControllerProvider.select((s) => s.session?.user.id));
      return ArtistFollowAction(ref.watch(artistRepositoryProvider), id, () {
        ref.invalidate(artistProfileProvider(id));
        ref.invalidate(followedArtistsProvider);
      });
    });

class ArtistFollowAction extends StateNotifier<AsyncValue<void>> {
  ArtistFollowAction(this.repository, this.id, this.updated)
    : super(const AsyncData(null));
  final ArtistRepository repository;
  final String id;
  final void Function() updated;
  Future<void> run() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await repository.toggle(id);
      if (!mounted) return;
      updated();
      state = const AsyncData(null);
    } catch (e, stack) {
      if (mounted) state = AsyncError(AppFailure.from(e), stack);
    }
  }
}
