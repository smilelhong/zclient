import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../protocol/connection_params.dart';

/// M1 pairing: scan the desktop's remote-control QR, or paste the link.
/// Returns the raw link string via Navigator.pop when it parses.
class M1ScanPage extends StatefulWidget {
  const M1ScanPage({super.key});

  @override
  State<M1ScanPage> createState() => _M1ScanPageState();
}

class _M1ScanPageState extends State<M1ScanPage> {
  final _pasteCtrl = TextEditingController();
  String? _error;
  final _scannerCtrl = MobileScannerController();

  @override
  void dispose() {
    _pasteCtrl.dispose();
    _scannerCtrl.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final parsed = RemoteConnectionParams.parse(raw);
    if (parsed == null) {
      setState(() => _error = '链接无法解析——需要包含 sid 的 ZCode 远控链接');
      return;
    }
    Navigator.of(context).pop(raw.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫码配对')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerCtrl,
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      final raw = barcode.rawValue;
                      if (raw != null && raw.isNotEmpty) {
                        _scannerCtrl.stop();
                        _submit(raw);
                        return;
                      }
                    }
                  },
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                TextField(
                  controller: _pasteCtrl,
                  decoration: const InputDecoration(
                    labelText: '或粘贴配对链接',
                    hintText: 'https://zcode.z.ai/remote/v4?sid=…',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _submit,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    final raw = _pasteCtrl.text;
                    if (raw.trim().isNotEmpty) _submit(raw);
                  },
                  child: const Text('使用此链接'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
