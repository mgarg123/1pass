package com.onepass.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.service.autofill.Dataset
import android.service.autofill.FillResponse
import android.util.Base64
import android.util.Log
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews
import androidx.fragment.app.FragmentActivity
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import com.it_nomads.fluttersecurestorage.FlutterSecureStorage
import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig
import com.it_nomads.fluttersecurestorage.SecurePreferencesCallback
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import java.nio.charset.StandardCharsets

class AuthActivity : FragmentActivity() {
    companion object {
        private const val TAG = "AuthActivity"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // No layout, we just show the biometric prompt

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
            .setTitle("Unlock 1Pass Autofill")
            .setSubtitle("Use your biometric credential to access passwords")
            .setNegativeButtonText("Cancel")
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    private fun handleSuccessfulAuth() {
        Thread {
            try {
                // Read key from FlutterSecureStorage
                val options = HashMap<String, Any>()
                val config = FlutterSecureStorageConfig(options)
                val storage = FlutterSecureStorage(applicationContext)

                val latch = CountDownLatch(1)
                storage.initialize(config, object : SecurePreferencesCallback<Void> {
                    override fun onSuccess(unused: Void?) { latch.countDown() }
                    override fun onError(e: Exception) { latch.countDown() }
                })
                latch.await(2, TimeUnit.SECONDS)

                val keyBase64 = storage.read("biometric_derived_key")
                if (keyBase64 == null) {
                    Log.e(TAG, "No biometric key found in secure storage")
                    finishWithEmpty()
                    return@Thread
                }

                val keyBytes = Base64.decode(keyBase64, Base64.DEFAULT)
                
                // Read entries from JSON cache (written by Flutter's AutofillCacheService)
                val cacheFile = File(applicationContext.filesDir, "autofill_cache.json")
                if (!cacheFile.exists()) {
                    Log.e(TAG, "Autofill cache file not found at: ${cacheFile.absolutePath}")
                    finishWithEmpty()
                    return@Thread
                }

                val cacheJson = JSONObject(cacheFile.readText(StandardCharsets.UTF_8))
                val entriesArray = cacheJson.getJSONArray("entries")

                val cryptoService = CryptoService()
                
                // Parse package/domain from Intent
                val target = intent.getStringExtra("target_domain_or_package") ?: ""

                val matches = mutableListOf<Map<String, String>>()
                
                for (i in 0 until entriesArray.length()) {
                    val entry = entriesArray.getJSONObject(i)
                    val encryptedData = entry.optString("encryptedData", "")
                    val title = entry.optString("title", "")
                    
                    if (encryptedData.isNotEmpty()) {
                        try {
                            val decrypted = cryptoService.decrypt(encryptedData, keyBytes)
                            val jsonStr = String(decrypted, StandardCharsets.UTF_8)
                            val json = JSONObject(jsonStr)
                            
                            val url = json.optString("url", "")
                            
                            if (fuzzyMatch(target, url) || fuzzyMatch(target, title)) {
                                val matchMap = mutableMapOf<String, String>()
                                matchMap["username"] = json.optString("username", "")
                                matchMap["password"] = json.optString("password", "")
                                matchMap["title"] = title
                                matches.add(matchMap)
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Failed to decrypt entry: ${entry.optString("id", "?")}", e)
                        }
                    }
                }

                // Build the FillResponse with matched datasets
                val responseBuilder = FillResponse.Builder()
                
                val usernameIds = intent.getParcelableArrayListExtra<AutofillId>("username_ids") ?: ArrayList()
                val passwordIds = intent.getParcelableArrayListExtra<AutofillId>("password_ids") ?: ArrayList()

                if (matches.isNotEmpty() && (usernameIds.isNotEmpty() || passwordIds.isNotEmpty())) {
                    for (match in matches) {
                        val datasetBuilder = Dataset.Builder()
                        val presentation = RemoteViews(packageName, android.R.layout.simple_list_item_1)
                        presentation.setTextViewText(android.R.id.text1, "1Pass: ${match["title"]}")
                        
                        var added = false
                        for (uid in usernameIds) {
                            datasetBuilder.setValue(uid, AutofillValue.forText(match["username"]), presentation)
                            added = true
                        }
                        for (pid in passwordIds) {
                            datasetBuilder.setValue(pid, AutofillValue.forText(match["password"]), presentation)
                            added = true
                        }
                        if (added) {
                            responseBuilder.addDataset(datasetBuilder.build())
                        }
                    }
                }

                val replyIntent = Intent()
                replyIntent.putExtra(android.view.autofill.AutofillManager.EXTRA_AUTHENTICATION_RESULT, responseBuilder.build())
                setResult(Activity.RESULT_OK, replyIntent)
                finish()

            } catch (e: Exception) {
                Log.e(TAG, "Error during autofill auth", e)
                e.printStackTrace()
                finishWithEmpty()
            }
        }.start()
    }
    
    private fun finishWithEmpty() {
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    private fun fuzzyMatch(target: String, urlOrTitle: String): Boolean {
        if (target.isBlank() || urlOrTitle.isBlank()) return false
        val t = target.lowercase()
        val u = urlOrTitle.lowercase()
        if (u.contains(t) || t.contains(u)) return true
        
        // basic domain extraction for fuzzy match
        val cleanU = u.replace("https://", "").replace("http://", "").replace("www.", "").substringBefore("/")
        if (t.contains(cleanU) || cleanU.contains(t)) return true
        
        return false
    }
}
