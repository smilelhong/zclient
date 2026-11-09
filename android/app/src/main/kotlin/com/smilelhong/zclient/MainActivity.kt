package com.smilelhong.zclient

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val storeChannel = "dev.zic.remote/store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Required by the vendored AppKv store (lib/state/app_kv.dart):
        // resolves the app-private files directory without going through
        // SharedPreferences, which is unreliable on some phones.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storeChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "filesDir") {
                    result.success(filesDir.path)
                } else {
                    result.notImplemented()
                }
            }
    }
}
