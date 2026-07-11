package com.onepass.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.onepass/autofill"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "requestSetAutofillService") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE)
                        intent.data = android.net.Uri.parse("package:$packageName")
                        startActivity(intent)
                    } catch (e: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE))
                        } catch (e2: Exception) {
                            // Ignore if settings intent not found
                        }
                    }
                    result.success(true)
                } else {
                    result.success(false)
                }
            } else if (call.method == "isCredentialProviderAvailable") {
                result.success(Build.VERSION.SDK_INT >= 34)
            } else if (call.method == "requestSetCredentialProvider") {
                if (Build.VERSION.SDK_INT >= 34) { // Android 14+
                    try {
                        val intent = Intent(Settings.ACTION_CREDENTIAL_PROVIDER)
                        intent.data = android.net.Uri.parse("package:$packageName")
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            // Fallback without package URI if the first one fails
                            startActivity(Intent(Settings.ACTION_CREDENTIAL_PROVIDER))
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("INTENT_FAILED", "Could not launch Credential Provider Settings", e2.message)
                        }
                    }
                } else {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
