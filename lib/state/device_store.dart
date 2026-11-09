import 'dart:convert';

import '../protocol/connection_params.dart';
import 'app_kv.dart';

/// One paired desktop, persisted as JSON in AppKv (`zc.devices`).
class PairedDevice {
  const PairedDevice({
    required this.sid,
    required this.link,
    required this.addedAt,
    this.name,
    this.lastUsedAt,
  });

  final String sid;
  final String link;
  final String? name;
  final int addedAt;
  final int? lastUsedAt;

  PairedDevice copyWith({String? name, int? lastUsedAt}) => PairedDevice(
        sid: sid,
        link: link,
        addedAt: addedAt,
        name: name ?? this.name,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );

  Map<String, dynamic> toJson() => {
        'sid': sid,
        'link': link,
        'addedAt': addedAt,
        if (name != null) 'name': name,
        if (lastUsedAt != null) 'lastUsedAt': lastUsedAt,
      };

  static PairedDevice? fromJson(Map raw) {
    final sid = '${raw['sid'] ?? ''}';
    final link = '${raw['link'] ?? ''}';
    if (sid.isEmpty || link.isEmpty) return null;
    return PairedDevice(
      sid: sid,
      link: link,
      addedAt: (raw['addedAt'] as num?)?.toInt() ?? 0,
      name: raw['name'] as String?,
      lastUsedAt: (raw['lastUsedAt'] as num?)?.toInt(),
    );
  }

  static PairedDevice? fromLink(String raw) {
    final params = RemoteConnectionParams.parse(raw);
    if (params == null) return null;
    return PairedDevice(
      sid: params.deviceSid,
      link: raw.trim(),
      addedAt: DateTime.now().millisecondsSinceEpoch,
      name: params.deviceName,
    );
  }
}

/// Multi-device persistence on top of the vendored AppKv store.
class DeviceStore {
  static const _key = 'zc.devices';
  static const _activeKey = 'zc.devices.active';
  static const _legacyLinkKey = 'zc.pairing.link';

  DeviceStore._();
  static final instance = DeviceStore._();

  List<PairedDevice> _cache = [];
  String? _activeSid;

  List<PairedDevice> get devices => List.unmodifiable(_cache);
  String? get activeSid => _activeSid;
  PairedDevice? get active =>
      _cache.where((d) => d.sid == _activeSid).firstOrNull;

  Future<void> load() async {
    await _migrateLegacy();
    final raw = await AppKv.instance.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          _cache = list
              .whereType<Map>()
              .map(PairedDevice.fromJson)
              .whereType<PairedDevice>()
              .toList();
        }
      } catch (_) {}
    }
    // Restore the active device too — without this the auto-reconnect
    // after a restart silently no-ops.
    try {
      final sid = await AppKv.instance.getString(_activeKey);
      if (sid != null && _cache.any((d) => d.sid == sid)) {
        _activeSid = sid;
      }
    } catch (_) {}
  }

  /// Converts the M2 single-link key into the devices list (once).
  Future<void> _migrateLegacy() async {
    try {
      final legacy = await AppKv.instance.getString(_legacyLinkKey);
      if (legacy == null || legacy.isEmpty) return;
      final device = PairedDevice.fromLink(legacy);
      if (device != null) {
        await upsert(device, activate: true);
      }
      await AppKv.instance.remove(_legacyLinkKey);
    } catch (_) {}
  }

  /// Inserts or updates by sid. Returns false when the link doesn't parse.
  Future<bool> addFromLink(String raw, {bool activate = true}) async {
    final device = PairedDevice.fromLink(raw);
    if (device == null) return false;
    await upsert(device, activate: activate);
    return true;
  }

  Future<void> upsert(PairedDevice device, {bool activate = false}) async {
    final idx = _cache.indexWhere((d) => d.sid == device.sid);
    if (idx >= 0) {
      _cache[idx] = _cache[idx].copyWith(
        name: device.name,
        lastUsedAt: device.lastUsedAt,
      );
    } else {
      _cache.add(device);
    }
    if (activate) _activeSid = device.sid;
    await _flush();
  }

  Future<void> activate(String sid) async {
    _activeSid = sid;
    final idx = _cache.indexWhere((d) => d.sid == sid);
    if (idx >= 0) {
      _cache[idx] = _cache[idx]
          .copyWith(lastUsedAt: DateTime.now().millisecondsSinceEpoch);
    }
    await _flush();
  }

  Future<void> remove(String sid) async {
    _cache.removeWhere((d) => d.sid == sid);
    if (_activeSid == sid) _activeSid = null;
    await _flush();
  }

  Future<void> _flush() async {
    try {
      await AppKv.instance.setString(
        _key,
        jsonEncode(_cache.map((d) => d.toJson()).toList()),
      );
      if (_activeSid == null) {
        await AppKv.instance.remove(_activeKey);
      } else {
        await AppKv.instance.setString(_activeKey, _activeSid!);
      }
    } catch (_) {}
  }
}
