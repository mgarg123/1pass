package com.onepass.app

import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.os.OutcomeReceiver
import androidx.annotation.RequiresApi
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.provider.BeginCreateCredentialRequest
import androidx.credentials.provider.BeginCreateCredentialResponse
import androidx.credentials.provider.BeginGetCredentialRequest
import androidx.credentials.provider.BeginGetCredentialResponse
import androidx.credentials.provider.CredentialProviderService
import androidx.credentials.provider.ProviderClearCredentialStateRequest
import androidx.credentials.provider.CreateEntry

@RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
class PasskeyProviderService : CredentialProviderService() {

    override fun onBeginCreateCredentialRequest(
        request: BeginCreateCredentialRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<BeginCreateCredentialResponse, CreateCredentialException>
    ) {
        var requestJsonStr = ""
        if (request is androidx.credentials.provider.BeginCreatePublicKeyCredentialRequest) {
            requestJsonStr = request.requestJson
        }

        // Create an intent to launch our native UI bridge
        val intent = Intent(this, PasskeyAuthActivity::class.java).apply {
            putExtra("TYPE", "CREATE")
            putExtra("REQUEST_JSON", requestJsonStr)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Build the CreateEntry UI slice
        val createEntry = CreateEntry.Builder(
            "Save Passkey to 1Pass",
            pendingIntent
        ).build()

        // Return the response to the OS
        val response = BeginCreateCredentialResponse.Builder()
            .setCreateEntries(listOf(createEntry))
            .build()
            
        callback.onResult(response)
    }

    override fun onBeginGetCredentialRequest(
        request: BeginGetCredentialRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<BeginGetCredentialResponse, GetCredentialException>
    ) {
        val entries = mutableListOf<androidx.credentials.provider.CredentialEntry>()
        var pubKeyOption: androidx.credentials.provider.BeginGetPublicKeyCredentialOption? = null
        
        for (option in request.beginGetCredentialOptions) {
            if (option is androidx.credentials.provider.BeginGetPublicKeyCredentialOption) {
                pubKeyOption = option
                break
            }
        }

        if (pubKeyOption != null) {
            try {
                val reqJson = org.json.JSONObject(pubKeyOption.requestJson)
                val rpId = reqJson.optString("rpId", "")
                
                val pendingFile = java.io.File(applicationContext.filesDir, "autofill_pending_saves.json")
                if (pendingFile.exists()) {
                    val pendingArray = org.json.JSONArray(pendingFile.readText(java.nio.charset.StandardCharsets.UTF_8))
                    for (i in 0 until pendingArray.length()) {
                        val obj = pendingArray.getJSONObject(i)
                        if (obj.optString("type") == "passkey") {
                            val domain = obj.optString("domain")
                            if (domain.contains(rpId)) {
                                val username = obj.optString("username", "Unknown User")
                                val userHandle = obj.optString("userHandle", "")
                                val credentialId = obj.optString("credentialId")
                                val privateKey = obj.optString("privateKey")
                                
                                val intent = Intent(this, PasskeyAuthActivity::class.java).apply {
                                    putExtra("TYPE", "GET")
                                    putExtra("REQUEST_JSON", pubKeyOption.requestJson)
                                    putExtra("PRIVATE_KEY", privateKey)
                                    putExtra("CREDENTIAL_ID", credentialId)
                                    putExtra("USER_HANDLE", userHandle)
                                }
                                
                                val pendingIntent = PendingIntent.getActivity(
                                    this,
                                    i + 100, // unique request code
                                    intent,
                                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                                )
                                
                                val entry = androidx.credentials.provider.PublicKeyCredentialEntry.Builder(
                                    this,
                                    username,
                                    pendingIntent,
                                    pubKeyOption
                                ).build()
                                
                                entries.add(entry)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("PasskeyProviderService", "Failed to parse get request", e)
            }
        }

        val response = BeginGetCredentialResponse.Builder()
            .setCredentialEntries(entries)
            .build()
        callback.onResult(response)
    }

    override fun onClearCredentialStateRequest(
        request: ProviderClearCredentialStateRequest,
        cancellationSignal: CancellationSignal,
        callback: OutcomeReceiver<Void?, ClearCredentialException>
    ) {
        callback.onResult(null)
    }
}
