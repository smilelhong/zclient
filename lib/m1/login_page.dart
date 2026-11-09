import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../auth/session_auth.dart';

/// M1 login: opens the official `https://<host>/login` page in a WebView and
/// harvests `localStorage["zcodejwttoken"]` (the V4 terminal-token source).
class M1LoginPage extends StatefulWidget {
  const M1LoginPage({super.key, required this.host, required this.onHarvested});

  final String host;
  final void Function(String host, String jwt, {String? cookieHeader})
      onHarvested;

  @override
  State<M1LoginPage> createState() => _M1LoginPageState();
}

class _M1LoginPageState extends State<M1LoginPage> {
  static const _jwtProbeJs = '''
(function () {
  try {
    return JSON.stringify({
      zcodejwttoken: localStorage.getItem('zcodejwttoken') || '',
      cookie: document.cookie || ''
    });
  } catch (e) {
    return '';
  }
})()
''';

  /// Auto-clicks the BigModel entry once per page instance (zic mode): the
  /// relay binds terminals by account realm, and the desktop is virtually
  /// always logged in via BigModel — going straight there avoids the
  /// wrong-realm JWT that pairing then rejects with AUTH_FAILED.
  static const _autoBigModelJs = '''
(function () {
  if (window.__zcAutoEntry) return 'already';
  window.__zcAutoEntry = 1;
  var re = new RegExp("continue\\\\s*with\\\\s*bigmodel|使用\\\\s*BigModel\\\\s*账号登录", 'i');
  var nodes = document.querySelectorAll('button, a, [role="tab"], span, div, li');
  for (var i = 0; i < nodes.length; i++) {
    var t = (nodes[i].innerText || '').trim();
    if (t && t.length <= 30 && re.test(t)) {
      nodes[i].click();
      return 'clicked:' + t;
    }
  }
  return 'notfound';
})()
''';

  late final WebViewController _controller;
  Timer? _harvestTimer;
  String? _candidateJwt;
  DateTime? _candidateChangedAt;
  bool _captured = false;

  /// zic parity: the candidate must hold steady for 2s before capture is
  /// offered, so a half-finished SSO redirect never gets grabbed mid-write.
  static const _stabilityWindow = Duration(seconds: 2);

  bool get _candidateStable =>
      _candidateJwt != null &&
      _candidateChangedAt != null &&
      DateTime.now().difference(_candidateChangedAt!) >= _stabilityWindow;

  @override
  void initState() {
    super.initState();
    final uri = Uri.parse('https://${widget.host}/login');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(uri);
    _harvestTimer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => _probe(),
    );
  }

  @override
  void dispose() {
    _harvestTimer?.cancel();
    super.dispose();
  }

  Future<void> _probe() async {
    if (_captured) return;
    unawaited(_autoClickBigModel());
    final jwt = await _extractJwt();
    if (jwt == null || jwt.isEmpty) return;
    final wasStable = _candidateStable;
    if (jwt != _candidateJwt) {
      _candidateJwt = jwt;
      _candidateChangedAt = DateTime.now();
      if (mounted) setState(() {});
    } else if (!wasStable && _candidateStable && mounted) {
      // Crossing the stability threshold re-enables the capture button.
      setState(() {});
    }
  }

  Future<void> _autoClickBigModel() async {
    try {
      await _controller.runJavaScript(_autoBigModelJs);
    } catch (_) {
      // The page may not have a DOM yet; the next poll retries.
    }
  }

  Future<String?> _extractJwt() async {
    dynamic raw;
    try {
      raw = await _controller.runJavaScriptReturningResult(_jwtProbeJs);
    } catch (_) {
      return null;
    }
    // Vendored parser: handles Map / bare string / Android WebView's
    // double-JSON-encoding, and validates the JWT shape before use.
    return jwtFromStorageProbe(raw);
  }

  void _capture() async {
    final jwt = _candidateJwt;
    if (jwt == null || jwt.isEmpty || _captured) return;
    _captured = true;
    _harvestTimer?.cancel();
    // Persist the domain cookies too (zic parity): they back the JWT for
    // hosts where the web client relies on session cookies.
    String? cookie;
    try {
      final raw = await _controller.runJavaScriptReturningResult('document.cookie || ""');
      if (raw is String && raw.isNotEmpty) cookie = raw;
    } catch (_) {}
    widget.onHarvested(widget.host, jwt, cookieHeader: cookie);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('登录 ${widget.host}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonal(
              onPressed: _candidateStable ? _capture : null,
              child: const Text('抓取凭证'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_candidateJwt != null && !_captured)
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _candidateStable
                        ? '检测到登录凭证（${_candidateJwt!.length} 字符）— 确认是 BigModel 账号后，点右上角「抓取凭证」（会先验证可用性）'
                        : '检测到登录凭证，等待稳定（2 秒）…',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
