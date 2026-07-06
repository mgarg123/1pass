package com.onepass.app

import android.app.Activity
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Bundle
import android.service.autofill.Dataset
import android.service.autofill.FillResponse
import android.util.Base64
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
                // Read key
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
                    finishWithEmpty()
                    return@Thread
                }

                val keyBytes = Base64.decode(keyBase64, Base64.DEFAULT)
                
                // Read Hive
                val path = getDir("flutter", MODE_PRIVATE).absolutePath + "/test_box" // wait, it's vault_entries.hive
                val file = File(getDir("flutter", MODE_PRIVATE), "vault_entries.hive")
                val reader = HiveReader(file)
                val entries = reader.readAllEntries()

                val cryptoService = CryptoService()
                
                // Parse package/domain from Intent
                val target = intent.getStringExtra("target_domain_or_package") ?: ""

                val matches = mutableListOf<Map<String, String>>()
                
                for (entry in entries) {
                    val encryptedData = entry["encryptedData"] as? String
                    if (encryptedData != null) {
                        try {
                            val decrypted = cryptoService.decrypt(encryptedData, keyBytes)
                            val jsonStr = String(decrypted, StandardCharsets.UTF_8)
                            val json = JSONObject(jsonStr)
                            
                            val url = json.optString("url", "")
                            val title = entry["title"] as? String ?: ""
                            
                            if (fuzzyMatch(target, url) || fuzzyMatch(target, title)) {
                                val matchMap = mutableMapOf<String, String>()
                                matchMap["username"] = json.optString("username", "")
                                matchMap["password"] = json.optString("password", "")
                                matchMap["title"] = title
                                matches.add(matchMap)
                            }
                        } catch (e: Exception) {
                            // ignore decryption failure for a single entry
                        }
                    }
                }

                // If no matches, we'd normally show a search UI, but for now we just return empty
                // We'll return the matches in the FillResponse
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
