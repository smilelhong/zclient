import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// M1 login: opens the official `https://<host>/login` page in a WebView and
/// harvests `localStorage["zcodejwttoken"]` (the V4 terminal-token source).
class M1LoginPage extends StatefulWidget {
  const M1LoginPage({super.key, required this.host, required this.onHarvested});

  final String host;
  final void Function(String host, String jwt) onHarvested;

  @override
  State<M1LoginPage> createState() => _M1LoginPageState();
}

class _M1LoginPageState extends State<M1LoginPage> {
  static const _jwtProbeJs = '''
(function () {
  try {
    return JSON.stringify({
      zcodejwttoken: localStorage.getItem('zcodejwttoken') || ''
    });
  } catch (e) {
    return '';
  }
})()
''';

  late final WebViewController _controller;
  Timer? _harvestTimer;
  String? _candidateJwt;
  int _stablePolls = 0;
  bool _captured = false;

  @override
  void initState() {
    super.initState();
    final uri = Uri.parse('https://${widget.host}/login');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(uri);
    _harvestTimer = Timer.periodic(
      const Duration(seconds: 2),
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
    final jwt = await _extractJwt();
    if (jwt == null || jwt.isEmpty) {
      _stablePolls = 0;
      return;
    }
    if (jwt == _candidateJwt) {
      _stablePolls++;
      // Auto-capture once the value is stable across two consecutive polls
      // (~4s), so a login that just landed is not half-written.
      if (_stablePolls >= 2) _capture();
    } else {
      _candidateJwt = jwt;
      _stablePolls = 0;
      if (mounted) setState(() {});
    }
  }

  Future<String?> _extractJwt() async {
    dynamic raw;
    try {
      raw = await _controller.runJavaScriptReturningResult(_jwtProbeJs);
    } catch (_) {
      return null;
    }
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final v = decoded['zcodejwttoken'];
        return v is String ? v : null;
      }
    } catch (_) {
      // runJavaScriptReturningResult may hand back the bare string.
      return raw.length > 40 ? raw : null;
    }
    return null;
  }

  void _capture() {
    final jwt = _candidateJwt;
    if (jwt == null || jwt.isEmpty || _captured) return;
    _captured = true;
    _harvestTimer?.cancel();
    widget.onHarvested(widget.host, jwt);
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
              onPressed: _candidateJwt == null ? null : _capture,
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
                    '检测到登录凭证（${_candidateJwt!.length} 字符），稳定后自动抓取，或点右上角立即抓取',
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
