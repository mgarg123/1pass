package com.onepass.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.fragment.app.FragmentActivity
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.charset.StandardCharsets
import java.util.UUID

class PasskeyAuthActivity : FragmentActivity() {
    companion object {
        private const val TAG = "PasskeyAuthActivity"
        const val PENDING_SAVES_FILE = "autofill_pending_saves.json"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val executor = ContextCompat.getMainExecutor(this)
        val biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    setResult(Activity.RESULT_CANCELED)
                    finish()
                }

                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    handleSuccessfulAuth()
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    // Allow retry
                }
            })

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Save Passkey to 1Pass")
            .setSubtitle("Use your biometric credential to create passkey")
            .setNegativeButtonText("Cancel")
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    private fun handleSuccessfulAuth() {
        try {
            // Retrieve request JSON from Intent Extra
            val requestJsonStr = intent.getStringExtra("REQUEST_JSON")
            val requestType = intent.getStringExtra("TYPE") ?: "CREATE"
            var origin = "unknown.origin"
            var challenge = "dummy_challenge"
            var username = "unknown_user"
            var userHandle = ""
            
            if (!requestJsonStr.isNullOrEmpty()) {
                try {
                    val reqJson = JSONObject(requestJsonStr)
                    challenge = reqJson.optString("challenge", "dummy_challenge")
                    val rp = reqJson.optJSONObject("rp")
                    if (rp != null) {
                        origin = "https://" + rp.optString("id", "webauthn.io")
                    } else if (reqJson.has("rpId")) {
                        origin = "https://" + reqJson.optString("rpId")
                    }
                    val userObj = reqJson.optJSONObject("user")
                    if (userObj != null) {
                        username = userObj.optString("name", "unknown_user")
                        userHandle = userObj.optString("id", "")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to parse public key request JSON", e)
                }
            }

            if (requestType == "GET") {
                val privateKey = intent.getStringExtra("PRIVATE_KEY") ?: ""
                val credentialId = intent.getStringExtra("CREDENTIAL_ID") ?: ""
                val savedUserHandle = intent.getStringExtra("USER_HANDLE") ?: ""
                
                Log.d(TAG, "GET Request Origin: $origin")
                Log.d(TAG, "GET Request Challenge: $challenge")
                Log.d(TAG, "GET Request Credential ID: $credentialId")
                
                val responseJson = PasskeyCrypto.authenticatePasskey(origin, challenge, privateKey, credentialId, savedUserHandle)
                Log.d(TAG, "GET Final Response JSON: $responseJson")
                
                val responseObj = androidx.credentials.PublicKeyCredential(responseJson)
                val replyIntent = Intent()
                androidx.credentials.provider.PendingIntentHandler.setGetCredentialResponse(replyIntent, androidx.credentials.GetCredentialResponse(responseObj))
                
                setResult(Activity.RESULT_OK, replyIntent)
                finish()
                return
            }

            // Generate real EC P-256 KeyPair, format CreateCredentialResponse
            val generationResult = PasskeyCrypto.generatePasskey(origin, challenge, username)
            
            // Queue the generated Passkey metadata to autofill_pending_saves.json
            val pendingFile = File(applicationContext.filesDir, PENDING_SAVES_FILE)
            val pendingArray = if (pendingFile.exists()) {
                try {
                    JSONArray(pendingFile.readText(StandardCharsets.UTF_8))
                } catch (e: Exception) {
                    JSONArray()
                }
            } else {
                JSONArray()
            }

            val saveRequest = JSONObject().apply {
                put("type", "passkey")
                put("domain", origin)
                put("username", username)
                put("userHandle", userHandle)
                put("credentialId", generationResult.credentialId)
                put("privateKey", generationResult.privateKeyBase64)
                put("timestamp", System.currentTimeMillis())
            }
            pendingArray.put(saveRequest)

            pendingFile.writeText(pendingArray.toString(), StandardCharsets.UTF_8)
            Log.d(TAG, "Queued real passkey save request for origin $origin")
            
            val responseObj = androidx.credentials.CreatePublicKeyCredentialResponse(generationResult.responseJson)
            val replyIntent = Intent()
            androidx.credentials.provider.PendingIntentHandler.setCreateCredentialResponse(replyIntent, responseObj)
            
            setResult(Activity.RESULT_OK, replyIntent)
            finish()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate passkey", e)
            setResult(Activity.RESULT_CANCELED)
            finish()
        }
    }
}
