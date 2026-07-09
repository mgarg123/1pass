package com.onepass.app

import android.os.Bundle
import android.util.Log
import androidx.fragment.app.FragmentActivity
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.charset.StandardCharsets

/**
 * Handles the "Save password?" flow triggered by the autofill framework.
 * 
 * Instead of spawning a new FlutterEngine (which races with Dart initialization),
 * we write the pending save request to a JSON file that Flutter's main engine
 * processes on next launch or resume via AutofillCacheService.processPendingSaves().
 */
class SaveAuthActivity : FragmentActivity() {
    companion object {
        private const val TAG = "SaveAuthActivity"
        const val PENDING_SAVES_FILE = "autofill_pending_saves.json"
    }

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
        try {
            // Write the pending save to a JSON file for Flutter to process
            val pendingFile = File(applicationContext.filesDir, PENDING_SAVES_FILE)
            
            val pendingArray = if (pendingFile.exists()) {
                try {
                    JSONArray(pendingFile.readText(StandardCharsets.UTF_8))
                } catch (e: Exception) {
                    Log.w(TAG, "Could not parse existing pending saves, starting fresh", e)
                    JSONArray()
                }
            } else {
                JSONArray()
            }

            val saveRequest = JSONObject().apply {
                put("domain", domain)
                put("username", username)
                put("password", password)
                put("timestamp", System.currentTimeMillis())
            }
            pendingArray.put(saveRequest)

            pendingFile.writeText(pendingArray.toString(), StandardCharsets.UTF_8)
            Log.d(TAG, "Queued save request for domain: $domain")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to queue save request", e)
        }
        
        finish()
    }
}
