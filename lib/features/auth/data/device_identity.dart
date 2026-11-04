import 'package:uuid/uuid.dart';

import '../../../core/storage/key_value_store.dart';
import '../../../core/errors/app_failure.dart';

class DeviceIdentity {
  const DeviceIdentity({
    required this.uuid,
    required this.name,
    required this.platform,
  });
  final String uuid;
  final String name;
  final String platform;
  Map<String, dynamic> toJson() => {
    'deviceUuid': uuid,
    'deviceName': name,
    'platform': platform,
  };
}

class DeviceIdentityStore {
  DeviceIdentityStore(this._store, {required this.platform});
  static const storageKey = 'moodify.device.v1';
  final KeyValueStore _store;
  final String platform;
  Future<DeviceIdentity>? _pending;

  Future<DeviceIdentity> load() {
    final existing = _pending;
    if (existing != null) return existing;
    final work = _load();
    _pending = work;
    return work.catchError((Object error) {
      _pending = null;
      throw AppFailure.storage;
    });
  }

  Future<DeviceIdentity> _load() async {
    var uuid = await _store.read(storageKey);
    if (uuid == null || !Uuid.isValidUUID(fromString: uuid)) {
      uuid = const Uuid().v4();
      await _store.write(storageKey, uuid);
    }
    return DeviceIdentity(
      uuid: uuid,
      name: 'Moodify $platform',
      platform: platform,
    );
  }
}
