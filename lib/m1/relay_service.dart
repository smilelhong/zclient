import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/relay_token.dart';
import '../auth/session_auth.dart';
import '../protocol/connection_params.dart';
import '../protocol/conversation.dart';
import '../protocol/remote_client.dart';

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
      );
}

class M1Controller extends Notifier<M1State> {
  RemoteClient? _client;
  BridgeSession? _bridge;
  ConversationTransport? _conv;
  ConversationSubscription? _sub;

  static const loginHost = 'zcode.z.ai';

  @override
  M1State build() {
    ref.onDispose(() {
      _sub?.dispose();
      _bridge?.dispose();
      _client?.dispose();
    });
    unawaited(_checkJwt());
    return const M1State();
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
    try {
      final jwt = await sessionAuth.jwtFor(loginHost);
      if (jwt != null && jwt.isNotEmpty) {
        state = state.copyWith(jwtHost: loginHost);
        _log('已保存的登录：$loginHost');
      } else {
        _log('未登录（$loginHost 无 JWT）');
      }
    } catch (e) {
      _log('检查登录失败: $e');
    }
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
  bool setLink(String raw) {
    final params = RemoteConnectionParams.parse(raw);
    if (params == null) {
      _log('配对链接无法解析: ${raw.length > 80 ? '${raw.substring(0, 80)}…' : raw}');
      return false;
    }
    state = state.copyWith(linkUrl: raw, params: params, clearSession: true);
    _log('链接 OK · v${params.passHash.isEmpty ? 4 : 3} · sid=${params.deviceSid}'
        '${params.deviceName != null ? ' · ${params.deviceName}' : ''}');
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
      final sessionId = await conv
          .createSession(workspaceId, firstText: '你好，这是 ZClient M1 的第一条消息。')
          .timeout(const Duration(seconds: 30));
      _log('✓ 会话已创建: $sessionId');

      final sub = await conv.subscribe(sessionId).timeout(
            const Duration(seconds: 20),
          );
      _sub = sub;
      sub.state.addListener(_onRows);
      _onRows();
      state = state.copyWith(phase: 'ready', sessionId: sessionId);
      _log('✓ M1 READY — 可以发送消息');
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
}

final m1Provider =
    NotifierProvider<M1Controller, M1State>(M1Controller.new);
