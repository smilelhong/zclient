import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/relay_token.dart';
import '../auth/session_auth.dart';
import '../protocol/connection_params.dart';
import '../protocol/conversation.dart';
import '../protocol/remote_client.dart';
import '../state/app_kv.dart';
import '../state/device_store.dart';

/// M1 protocol console state — deliberately raw: this milestone is about
/// proving the vendored protocol path end to end, not about UI.
@immutable
class M1State {
  const M1State({
    this.jwtHost,
    this.linkUrl,
    this.params,
    this.phase = 'idle',
    this.error,
    this.log = const [],
    this.sessionId,
    this.rows = const [],
    this.sending = false,
    this.devices = const [],
    this.sessionsTick = 0,
  });

  /// Host that has a stored ZCode login JWT (from the WebView harvest).
  final String? jwtHost;
  final String? linkUrl;
  final RemoteConnectionParams? params;

  /// idle → connecting → paired → bootstrapped → ready | error
  final String phase;
  final String? error;
  final List<String> log;
  final String? sessionId;

  /// Rendered transcript rows from ConversationState.
  final List<String> rows;
  final bool sending;

  /// Paired desktops (DeviceStore view) + bump counter for the sessions
  /// index so Riverpod rebuilds list pages on index frames.
  final List<PairedDevice> devices;
  final int sessionsTick;

  M1State copyWith({
    String? jwtHost,
    String? linkUrl,
    RemoteConnectionParams? params,
    String? phase,
    String? error,
    List<String>? log,
    String? sessionId,
    List<String>? rows,
    bool? sending,
    List<PairedDevice>? devices,
    int? sessionsTick,
    bool clearError = false,
    bool clearSession = false,
  }) =>
      M1State(
        jwtHost: jwtHost ?? this.jwtHost,
        linkUrl: linkUrl ?? this.linkUrl,
        params: params ?? this.params,
        phase: phase ?? this.phase,
        error: clearError ? null : (error ?? this.error),
        log: log ?? this.log,
        sessionId: clearSession ? null : (sessionId ?? this.sessionId),
        rows: rows ?? this.rows,
        sending: sending ?? this.sending,
        devices: devices ?? this.devices,
        sessionsTick: sessionsTick ?? this.sessionsTick,
      );
}

class M1Controller extends Notifier<M1State> {
  RemoteClient? _client;
  BridgeSession? _bridge;
  ConversationTransport? _conv;
  ConversationSubscription? _sub;
  SessionsIndexSubscription? _indexSub;

  static const loginHost = 'zcode.z.ai';
  static const _linkKey = 'zc.pairing.link';
  static const _sessionKey = 'zc.session.id';

  DeviceStore get _store => DeviceStore.instance;

  /// Sessions index of the connected workspace (live list of sessions).
  SessionsIndexState? get sessionsIndex => _indexSub?.state;

  @override
  M1State build() {
    ref.onDispose(() {
      _indexSub?.dispose();
      _sub?.dispose();
      _bridge?.dispose();
      _client?.dispose();
    });
    unawaited(_restoreSession());
    return const M1State();
  }

  /// Restores the persisted pairing link and, when a login exists for its
  /// host, reconnects automatically so re-entering the app lands straight
  /// back in the session.
  Future<void> _restoreSession() async {
    await _checkJwt();
    try {
      await _store.load();
    } catch (_) {}
    _syncDevices();
    if (state.jwtHost == null) return;
    final active = _store.active;
    if (active == null) return;
    if (!setLink(active.link, persist: false)) return;
    _log('恢复上次配对（${active.name ?? active.sid}），自动重连…');
    await connect();
  }

  void _syncDevices() {
    state = state.copyWith(devices: _store.devices);
  }

  // ------------------------------------------------------------ devices

  /// Adds (or refreshes) a paired desktop from a scanned/pasted link and
  /// connects to it. Returns false when the link doesn't parse.
  Future<bool> addDeviceFromLink(String raw) async {
    final ok = await _store.addFromLink(raw, activate: true);
    _syncDevices();
    if (!ok) {
      _log('配对链接无法解析');
      return false;
    }
    if (!setLink(raw, persist: false)) return false;
    await connect();
    return state.phase == 'ready';
  }

  Future<void> connectDevice(PairedDevice device) async {
    await _store.activate(device.sid);
    _syncDevices();
    if (!setLink(device.link, persist: false)) return;
    _log('切换设备：${device.name ?? device.sid}');
    await connect();
  }

  Future<void> removeDevice(String sid) async {
    await _store.remove(sid);
    _syncDevices();
    _log('已移除设备 $sid');
    if (_store.active == null && state.params?.deviceSid == sid) {
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    _indexSub?.dispose();
    _indexSub = null;
    _sub?.dispose();
    _sub = null;
    _conv = null;
    _bridge?.dispose();
    _bridge = null;
    _client?.dispose();
    _client = null;
    state = state.copyWith(
      phase: 'idle',
      clearSession: true,
      rows: const [],
      clearError: true,
    );
    _log('已断开');
  }

  // ------------------------------------------------------------ sessions

  /// Subscribes the workspace sessions index after the chat transport is
  /// ready; every index frame bumps [M1State.sessionsTick].
  Future<void> _subscribeIndex() async {
    final conv = _conv;
    if (conv == null) return;
    try {
      final sub = await conv.subscribeSessionsIndex().timeout(
            const Duration(seconds: 20),
          );
      _indexSub?.dispose();
      _indexSub = sub;
      sub.state.addListener(_onIndex);
      _onIndex();
      _log('会话索引就绪（${sub.state.list.length} 个会话）');
    } catch (e) {
      _log('会话索引订阅失败: $e');
    }
  }

  void _onIndex() {
    state = state.copyWith(sessionsTick: state.sessionsTick + 1);
  }

  /// Switches the live chat subscription to another session.
  Future<void> switchSession(String sessionId) async {
    final conv = _conv;
    if (conv == null || sessionId == state.sessionId) return;
    try {
      final sub = await conv.subscribe(sessionId).timeout(
            const Duration(seconds: 20),
          );
      _sub?.dispose();
      _sub = sub;
      sub.state.addListener(_onRows);
      _onRows();
      state = state.copyWith(sessionId: sessionId);
      unawaited(() async {
        try {
          await AppKv.instance.setString(_sessionKey, sessionId);
        } catch (_) {}
      }());
      _log('切换会话: $sessionId');
    } catch (e) {
      _log('✗ 切换会话失败: $e');
    }
  }

  void _log(String line) {
    debugPrint('[m1] $line');
    final log = [...state.log, '${_ts()} $line'];
    state = state.copyWith(log: log.length > 400 ? log.sublist(log.length - 400) : log);
  }

  String _ts() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
  }

  Future<void> _checkJwt() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final jwt = await sessionAuth.jwtFor(loginHost);
        if (jwt != null && jwt.isNotEmpty) {
          state = state.copyWith(jwtHost: loginHost);
          _log('已保存的登录：$loginHost');
          return;
        }
      } catch (e) {
        _log('检查登录失败: $e');
        return;
      }
      // Right after an install the first launch can stall the platform
      // thread past AppKv's 3s filesDir-channel timeout, leaving the store
      // degraded with a cached failed open (open() short-circuits on the
      // cached future). Force a clean reopen before giving up.
      // ignore: invalid_use_of_visible_for_testing_member
      AppKv.instance.debugReset();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await AppKv.instance.open();
    }
    _log('未登录（$loginHost 无 JWT）');
  }

  Future<void> onLoginHarvested(String host, String jwt) async {
    await sessionAuth.saveJwt(host, jwt);
    state = state.copyWith(jwtHost: host);
    _log('登录凭证已保存（$host，${jwt.length} 字符）');
    _logJwtHint(jwt);
  }

  /// Decodes the JWT payload (no network) so the account on the phone can be
  /// eyeballed against the desktop's account when pairing fails.
  void _logJwtHint(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) {
        _log('JWT 非标准三段式，无法解码比对');
        return;
      }
      final normalized = base64Url.normalize(parts[1]);
      final map = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (map is! Map) return;
      final keys = map.keys.join(',');
      final sub = '${map['sub'] ?? map['uid'] ?? map['user_id'] ?? '?'}';
      final masked = sub.length <= 6
          ? sub
          : '${sub.substring(0, 3)}…${sub.substring(sub.length - 3)}';
      final exp = map['exp'];
      final expStr = exp is int
          ? DateTime.fromMillisecondsSinceEpoch(exp * 1000).toIso8601String()
          : '$exp';
      _log('JWT 账号标识: $masked · 过期: $expStr · payload键: $keys');
    } catch (e) {
      _log('JWT 解码失败: $e');
    }
  }

  /// Accepts a pasted or scanned pairing link.
  bool setLink(String raw, {bool persist = true}) {
    final params = RemoteConnectionParams.parse(raw);
    if (params == null) {
      _log('配对链接无法解析: ${raw.length > 80 ? '${raw.substring(0, 80)}…' : raw}');
      return false;
    }
    state = state.copyWith(linkUrl: raw, params: params, clearSession: true);
    _log('链接 OK · v${params.passHash.isEmpty ? 4 : 3} · sid=${params.deviceSid}'
        '${params.deviceName != null ? ' · ${params.deviceName}' : ''}');
    if (persist) {
      unawaited(() async {
        try {
          await AppKv.instance.setString(_linkKey, raw.trim());
        } catch (_) {}
      }());
    }
    return true;
  }

  Future<void> connect() async {
    final params = state.params;
    if (params == null) {
      state = state.copyWith(phase: 'error', error: '先提供配对链接', clearError: true);
      return;
    }
    state = state.copyWith(phase: 'connecting', clearError: true);
    try {
      // v4 links carry no HMAC pair — mint a terminal relay token once and
      // prime it into the first dial (mirrors zic's connect()).
      Future<String?> Function()? tokenProvider;
      if (params.passHash.isEmpty) {
        if (state.jwtHost == null) {
          throw const RelayTokenException(
            'auth-required',
            'v4 链接需要先登录 ZCode',
          );
        }
        _log('v4 链接 · 铸造 terminal relay token…');
        final minted = await issueTerminalRelayTokenForHost(
          host: params.source.host,
          secure: params.uriSchemeIsSecure,
        ).timeout(const Duration(seconds: 20));
        if (minted == null || minted.isEmpty) {
          throw const RelayTokenException(
            'auth-required',
            '该主机没有可用登录，请先登录',
          );
        }
        _log('token 已铸造（${minted.length} 字符）');
        tokenProvider = () async => minted;
      } else {
        _log('v3 链接 · 走 HMAC 证明路径');
      }

      final client = RemoteClient(
        params,
        onLog: _log,
        accessTokenProvider: tokenProvider,
      );
      _client = client;
      client.relay.failures.listen((f) {
        _log('relay 失败: ${f.reason} — ${f.message}');
        state = state.copyWith(
          phase: 'error',
          error: '配对失败（${f.reason}）：${f.message}',
          clearError: true,
        );
      });
      _log('连接 relay…');
      await client.connect().timeout(const Duration(seconds: 30));
      _log('socket 已建立，等待配对…');
      await client.waitPaired(timeout: const Duration(seconds: 25));
      state = state.copyWith(phase: 'paired');
      _log('✓ 配对成功');

      final bootstrap = await client.bootstrap().timeout(
            const Duration(seconds: 15),
          );
      final workspaces = bootstrap['workspaces'];
      _log('bootstrap · workspaces=${workspaces is List ? workspaces.length : workspaces}');
      if (workspaces is List && workspaces.isNotEmpty) {
        final first = workspaces.first;
        if (first is Map) {
          _log('首个 workspace 键: ${first.keys.toList().join(',')}');
        }
      }
      state = state.copyWith(phase: 'bootstrapped');

      final workspace = _firstWorkspace(workspaces);
      if (workspace == null) {
        throw StateError('bootstrap 未返回 workspace，无法继续');
      }
      final workspaceKey = _workspaceKeyOf(workspace);
      _log('打开 workspace bridge · key=$workspaceKey');
      final bridge = await client
          .openBridge(workspaceKey)
          .timeout(const Duration(seconds: 30));
      _bridge = bridge;

      final scope = <String, dynamic>{
        'workspacePath': workspace['workspacePath'],
        if (workspace['workspaceIdentity'] != null)
          'workspaceIdentity': workspace['workspaceIdentity'],
      };
      final conv = bridge.conversation(scope, onLog: _log);
      _conv = conv;

      final workspaceId = _chatWorkspaceId(workspace);
      _log('workspaceId=$workspaceId');

      // Resume the last session when one exists (re-entering the app lands
      // back in the same conversation); otherwise create a fresh empty one.
      String? savedSid;
      try {
        savedSid = await AppKv.instance.getString(_sessionKey);
      } catch (_) {}
      ConversationSubscription? sub;
      var sessionId = '';
      if (savedSid != null && savedSid.isNotEmpty) {
        try {
          sub = await conv.subscribe(savedSid).timeout(
                const Duration(seconds: 20),
              );
          sessionId = savedSid;
          _log('✓ 恢复上次会话: $sessionId');
        } catch (_) {
          sub = null;
        }
      }
      if (sub == null) {
        sessionId = await conv.createSession(workspaceId).timeout(
              const Duration(seconds: 30),
            );
        _log('✓ 会话已创建: $sessionId');
        sub = await conv.subscribe(sessionId).timeout(
              const Duration(seconds: 20),
            );
      }
      unawaited(() async {
        try {
          await AppKv.instance.setString(_sessionKey, sessionId);
        } catch (_) {}
      }());
      _sub = sub;
      sub.state.addListener(_onRows);
      _onRows();
      final active = _store.active;
      if (active != null) {
        await _store.activate(active.sid);
        _syncDevices();
      }
      state = state.copyWith(phase: 'ready', sessionId: sessionId);
      _log('✓ M3 READY — 会话就绪');
      unawaited(_subscribeIndex());
    } on RelayTokenException catch (e) {
      state = state.copyWith(phase: 'error', error: '${e.reason}: ${e.message}');
      _log('✗ ${e.reason}: ${e.message}');
    } catch (e) {
      state = state.copyWith(phase: 'error', error: '$e');
      _log('✗ $e');
    }
  }

  Map<String, dynamic>? _firstWorkspace(dynamic workspaces) {
    if (workspaces is List && workspaces.isNotEmpty) {
      final first = workspaces.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return first.cast<String, dynamic>();
    }
    return null;
  }

  /// Mirrors zic's workspaceKeyOf: identity → path → workspaceKey/key/id.
  String _workspaceKeyOf(Map<String, dynamic> w) {
    final identity = w['workspaceIdentity'];
    if (identity is String && identity.trim().isNotEmpty) {
      return identity.trim();
    }
    final path = w['workspacePath'];
    if (path is String && path.isNotEmpty) return path;
    for (final key in const ['workspaceKey', 'key', 'id']) {
      final v = w[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return '';
  }

  /// Mirrors zic's chatWorkspaceId: explicit workspaceId, else the key.
  String _chatWorkspaceId(Map<String, dynamic> w) {
    final id = w['workspaceId'];
    if (id is String && id.isNotEmpty) return id;
    return _workspaceKeyOf(w);
  }

  void _onRows() {
    final rows = _sub?.state.rows ?? const [];
    final rendered = rows.map(_renderRow).toList(growable: false);
    state = state.copyWith(rows: rendered);
  }

  String _renderRow(Map row) {
    final role = row['role'] ?? row['type'] ?? row['kind'] ?? row['sender'] ?? '?';
    dynamic text = row['text'] ?? row['content'] ?? row['body'] ?? row['message'];
    String body;
    if (text is String && text.trim().isNotEmpty) {
      body = text;
    } else {
      body = jsonEncode(row);
    }
    if (body.length > 500) body = '${body.substring(0, 500)}…';
    return '[$role] $body';
  }

  Future<void> send(String text) async {
    final conv = _conv;
    final sessionId = state.sessionId;
    if (conv == null || sessionId == null) {
      _log('未连接，先完成配对');
      return;
    }
    state = state.copyWith(sending: true);
    try {
      await conv.sendText(sessionId, text).timeout(const Duration(seconds: 30));
      _log('已发送: ${text.length > 80 ? '${text.substring(0, 80)}…' : text}');
    } catch (e) {
      _log('✗ 发送失败: $e');
    } finally {
      state = state.copyWith(sending: false);
    }
  }

  // ------------------------------------------------------------ M2 ops

  /// Live conversation state for the chat screen (ChangeNotifier).
  ConversationState? get convState => _sub?.state;
  String? get deviceName => state.params?.deviceName;
  bool get hasMoreHistory =>
      convState?.hasMore == true && convState?.firstRowId != null;

  Future<void> loadOlder() async {
    final conv = _conv;
    final sessionId = state.sessionId;
    final st = convState;
    if (conv == null || sessionId == null || st == null || _loadingOlder) {
      return;
    }
    if (st.hasMore != true || st.firstRowId == null) return;
    _loadingOlder = true;
    try {
      final res = await conv
          .rowsRange(sessionId, beforeRowId: st.firstRowId, limit: 60)
          .timeout(const Duration(seconds: 20));
      if (res is Map) {
        final rows = res['rows'];
        st.prependOlderRows(
          rows is List
              ? rows.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList()
              : const <Map<String, dynamic>>[],
          res['firstRowId'] as int?,
        );
        _log('历史加载: +${rows is List ? rows.length : 0} 行'
            '${res['hasMore'] == true ? ' · 还有更早' : ' · 已到顶'}');
      }
    } catch (e) {
      _log('历史加载失败: $e');
    } finally {
      _loadingOlder = false;
    }
  }

  bool _loadingOlder = false;

  /// Answers a pending interaction (待确认卡) with the chosen option.
  Future<void> resolveInteraction(
    String interactionId, {
    String? optionId,
  }) async {
    final conv = _conv;
    final sessionId = state.sessionId;
    if (conv == null || sessionId == null) return;
    try {
      await conv
          .resolveInteraction(sessionId, interactionId, optionId: optionId)
          .timeout(const Duration(seconds: 15));
      _log('待确认已处理 (${optionId ?? 'free'})');
    } catch (e) {
      _log('✗ 待确认处理失败: $e');
    }
  }

  /// Trusts everything in a workspace-hook review prompt.
  Future<void> trustHookReview(Map payload) async {
    final conv = _conv;
    final sessionId = state.sessionId;
    if (conv == null || sessionId == null) return;
    try {
      await conv
          .respondWorkspaceHookReview(sessionId, payload, const [])
          .timeout(const Duration(seconds: 15));
      _log('Hook 审查已信任通过');
    } catch (e) {
      _log('✗ Hook 审查失败: $e');
    }
  }

  /// Web rewind precheck — reports what the desktop would revert.
  Future<Map<String, dynamic>?> rewindPreview(
      Map<String, dynamic> row) async {
    final conv = _conv;
    final sessionId = state.sessionId;
    if (conv == null || sessionId == null) return null;
    final target = <String, dynamic>{
      'rowId': row['rowId'],
      if (row['entityId'] != null) 'entityId': row['entityId'],
    };
    try {
      final res = await conv
          .fileRewindPreview(sessionId, target: target)
          .timeout(const Duration(seconds: 20));
      _log('回滚预检完成');
      return res is Map<String, dynamic>
          ? res
          : res is Map
              ? res.cast<String, dynamic>()
              : null;
    } catch (e) {
      _log('✗ 回滚预检失败: $e');
      return null;
    }
  }

  /// Applies the rewind after the user confirms the preview.
  Future<void> applyRewind(Map<String, dynamic> row) async {
    final conv = _conv;
    final sessionId = state.sessionId;
    if (conv == null || sessionId == null) return;
    final target = <String, dynamic>{
      'rowId': row['rowId'],
      if (row['entityId'] != null) 'entityId': row['entityId'],
    };
    try {
      await conv
          .applyFileRewind(sessionId, target)
          .timeout(const Duration(seconds: 30));
      _log('✓ 文件已回滚');
    } catch (e) {
      _log('✗ 回滚失败: $e');
    }
  }
}

final m1Provider =
    NotifierProvider<M1Controller, M1State>(M1Controller.new);
