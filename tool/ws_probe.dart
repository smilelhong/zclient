// M1 diagnostic: replays the ws2 handshake from the desktop side so server
// verdicts can be compared across meta variants without touching the app.
//
// Usage:
//   dart run tool/ws_probe.dart <jwt> <sid> <mid> [name] [platform] [nomid|delay]
// Defaults: name=zic platform=android (matches the vendored client).
//   nomid — dial without the mid query param (fresh-pairing hypothesis)
//   delay — wait 2s between mint and dial (token-liveness race)

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    print('usage: dart run tool/ws_probe.dart <jwt> <sid> <mid> [name] [platform] [nomid|delay]');
    return;
  }
  final jwt = args[0];
  final sid = args[1];
  final mid = args[2];
  final name = args.length > 3 ? args[3] : 'zic';
  final platform = args.length > 4 ? args[4] : 'android';
  final flag = args.length > 5 ? args[5] : '';
  final useMid = flag != 'nomid';
  final delay = flag == 'delay';

  // 1) Mint a terminal token (same as the app).
  final mintRes = await http.post(
    Uri.parse('https://zcode.z.ai/api/v1/remote/token'),
    headers: {
      'Authorization': 'Bearer $jwt',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({'role': 'terminal'}),
  ).timeout(const Duration(seconds: 15));
  print('mint status=${mintRes.statusCode} body=${mintRes.body}');
  if (mintRes.statusCode != 200) return;
  final token = jsonDecode(mintRes.body)['data']['token'] as String;
  print('token=$token (${token.length} chars)');

  // 2) Dial ws2 and replay auth_init.
  final uri = Uri(
    scheme: 'wss',
    host: 'zcode.z.ai',
    path: '/api/v1/remote/ws2',
    queryParameters: {
      'token': token,
      if (useMid) 'mid': mid,
    },
  );
  if (delay) await Future<void>.delayed(const Duration(seconds: 2));
  print('dialing $uri');
  final ws = IOWebSocketChannel.connect(uri);
  final done = Completer<void>();
  final framesIn = <String>[];

  final sub = ws.stream.listen(
    (frame) {
      print('<< $frame');
      framesIn.add('$frame');
      final map = jsonDecode('$frame');
      if (map is Map && map['type'] == 'error') {
        print('RESULT: rejected (${map['code']})');
        if (!done.isCompleted) done.complete();
      }
      if (map is Map &&
          (map['type'] == 'pair_status_ack' || map['type'] == 'auth_ok')) {
        print('RESULT: accepted → $frame');
        if (!done.isCompleted) done.complete();
      }
    },
    onDone: () {
      print('socket closed (frames=${framesIn.length})');
      if (!done.isCompleted) done.complete();
    },
    onError: (e) {
      print('socket error: $e');
      if (!done.isCompleted) done.complete();
    },
  );

  await ws.ready.timeout(const Duration(seconds: 10));
  final authInit = jsonEncode({
    'type': 'auth_init',
    'device_sid': sid,
    'meta': {
      'platform': platform,
      'version': '3.17.2',
      'name': name,
    },
    'client_ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  });
  print('>> $authInit');
  ws.sink.add(authInit);

  try {
    await done.future.timeout(const Duration(seconds: 20));
  } on TimeoutException {
    print('RESULT: no verdict in 20s (frames=${framesIn.length}) — likely waiting_terminal');
  }
  await sub.cancel();
  await ws.sink.close();
}
