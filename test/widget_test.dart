import 'package:flutter_test/flutter_test.dart';
import 'package:zclient/protocol/connection_params.dart';

void main() {
  group('RemoteConnectionParams.parse', () {
    test('parses a v4 pairing link (no hash pair)', () {
      const raw =
          'https://zcode.z.ai/remote/v4?sid=abc123&mid=mid-1&name=MacBook&app_version=1.2.3';
      final params = RemoteConnectionParams.parse(raw);
      expect(params, isNotNull);
      expect(params!.deviceSid, 'abc123');
      expect(params.passHash, isEmpty); // v4: token path, not HMAC
      expect(params.deviceName, 'MacBook');
      expect(params.source.host, 'zcode.z.ai');
      expect(params.v2RelayWsUri('t'.padRight(22, 'x')).path,
          '/api/v1/remote/ws2');
    });

    test('parses a legacy v3 link with hash + t', () {
      const raw =
          'https://zcode.z.ai/remote?sid=abc&hash=deadbeef&t=1730000000';
      final params = RemoteConnectionParams.parse(raw);
      expect(params, isNotNull);
      expect(params!.passHash, 'deadbeef');
      expect(params.timestamp, 1730000000);
      expect(params.relayWsUri.path, '/ws');
    });

    test('rejects junk', () {
      expect(RemoteConnectionParams.parse('not a url'), isNull);
      expect(RemoteConnectionParams.parse('https://zcode.z.ai/remote'), isNull);
    });
  });
}
