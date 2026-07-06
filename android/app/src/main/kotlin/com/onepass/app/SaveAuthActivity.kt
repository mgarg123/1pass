package com.onepass.app

import android.app.Activity
import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class SaveAuthActivity : FragmentActivity() {
    private var flutterEngine: FlutterEngine? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val target = intent.getStringExtra("target_domain_or_package") ?: ""
        val username = intent.getStringExtra("username") ?: ""
        val password = intent.getStringExtra("password") ?: ""
        
        if (target.isBlank() || (username.isBlank() && password.isBlank())) {
            finish()
            return
        }

        val executor = ContextCompat.getMainExecutor(this)
        val biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    finish()
                }

                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    handleSuccessfulAuth(target, username, password)
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    // Allow retry
                }
            })

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Save to 1Pass")
            .setSubtitle("Use your biometric credential to save password")
            .setNegativeButtonText("Cancel")
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    private fun handleSuccessfulAuth(domain: String, username: String, password: String) {
        flutterEngine = FlutterEngine(this)
        flutterEngine?.dartExecutor?.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        
        val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "com.example.onepass/autofill")
        
        channel.invokeMethod("saveAutofillEntry", mapOf(
            "domain" to domain,
            "username" to username,
            "password" to password
        ), object : MethodChannel.Result {
            override fun success(result: Any?) {
                finish()
            }
            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                finish()
            }
            override fun notImplemented() {
                finish()
            }
        })
    }

    override fun onDestroy() {
        flutterEngine?.destroy()
        super.onDestroy()
    }
}
