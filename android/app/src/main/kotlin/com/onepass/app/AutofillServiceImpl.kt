package com.onepass.app

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.service.autofill.SaveInfo
import android.util.Log
import android.view.autofill.AutofillId
import android.widget.RemoteViews
import java.util.ArrayList

class AutofillServiceImpl : AutofillService() {
    companion object {
        private const val TAG = "AutofillServiceImpl"
    }

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        Log.d(TAG, "onFillRequest called")
        
        val context = request.fillContexts.last()
        val structure = context.structure
        
        var targetDomainOrPackage = structure.activityComponent.packageName ?: ""
        
        val usernameIds = ArrayList<AutofillId>()
        val passwordIds = ArrayList<AutofillId>()
        
        traverseStructure(structure, usernameIds, passwordIds)
        
        if (usernameIds.isEmpty() && passwordIds.isEmpty()) {
            callback.onSuccess(null)
            return
        }

        // Try to get web domain if it's a browser
        val webDomain = getWebDomain(structure)
        if (webDomain != null) {
            targetDomainOrPackage = webDomain
        }

        val authIntent = Intent(this, AuthActivity::class.java)
        authIntent.putExtra("target_domain_or_package", targetDomainOrPackage)
        authIntent.putParcelableArrayListExtra("username_ids", usernameIds)
        authIntent.putParcelableArrayListExtra("password_ids", passwordIds)

        var flags = PendingIntent.FLAG_CANCEL_CURRENT
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.nanoTime().toInt(),
            authIntent,
            flags
        )

        val presentation = RemoteViews(packageName, android.R.layout.simple_list_item_1)
        presentation.setTextViewText(android.R.id.text1, "Unlock 1Pass")

        val autofillIds = mutableListOf<AutofillId>()
        autofillIds.addAll(usernameIds)
        autofillIds.addAll(passwordIds)

        // Determine required IDs for SaveInfo: password is required, username is optional
        val requiredIds = if (passwordIds.isNotEmpty()) {
            passwordIds.toTypedArray()
        } else {
            usernameIds.toTypedArray()
        }

        val saveInfoBuilder = SaveInfo.Builder(
            SaveInfo.SAVE_DATA_TYPE_USERNAME or SaveInfo.SAVE_DATA_TYPE_PASSWORD,
            requiredIds
        ).setFlags(SaveInfo.FLAG_SAVE_ON_ALL_VIEWS_INVISIBLE)

        // Set username IDs as optional if password IDs are the required ones
        if (passwordIds.isNotEmpty() && usernameIds.isNotEmpty()) {
            saveInfoBuilder.setOptionalIds(usernameIds.toTypedArray())
        }

        val saveInfo = saveInfoBuilder.build()

        val response = FillResponse.Builder()
            .setSaveInfo(saveInfo)
            .setAuthentication(autofillIds.toTypedArray(), pendingIntent.intentSender, presentation)
            .build()
            
        callback.onSuccess(response)
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        val context = request.fillContexts.last()
        val structure = context.structure
        
        var targetDomainOrPackage = structure.activityComponent.packageName ?: ""
        val webDomain = getWebDomain(structure)
        if (webDomain != null) {
            targetDomainOrPackage = webDomain
        }

        val usernameIds = ArrayList<AutofillId>()
        val passwordIds = ArrayList<AutofillId>()
        traverseStructure(structure, usernameIds, passwordIds)

        var username = ""
        var password = ""

        // Extract submitted values
        val dataset = request.fillContexts.last().structure
        extractValues(dataset, usernameIds, passwordIds, { u -> username = u }, { p -> password = p })

        val intent = Intent(this, SaveAuthActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("target_domain_or_package", targetDomainOrPackage)
            putExtra("username", username)
            putExtra("password", password)
        }
        
        try {
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start SaveAuthActivity", e)
        }
        
        callback.onSuccess()
    }

    private fun extractValues(
        structure: AssistStructure,
        usernameIds: ArrayList<AutofillId>,
        passwordIds: ArrayList<AutofillId>,
        onUsername: (String) -> Unit,
        onPassword: (String) -> Unit
    ) {
        val nodes = structure.windowNodeCount
        for (i in 0 until nodes) {
            val windowNode = structure.getWindowNodeAt(i)
            val viewNode = windowNode.rootViewNode
            if (viewNode != null) {
                extractValuesFromNode(viewNode, usernameIds, passwordIds, onUsername, onPassword)
            }
        }
    }

    private fun extractValuesFromNode(
        viewNode: AssistStructure.ViewNode,
        usernameIds: ArrayList<AutofillId>,
        passwordIds: ArrayList<AutofillId>,
        onUsername: (String) -> Unit,
        onPassword: (String) -> Unit
    ) {
        val id = viewNode.autofillId
        val text = viewNode.text?.toString() ?: ""
        
        if (id != null && text.isNotEmpty()) {
            if (usernameIds.contains(id)) {
                onUsername(text)
            }
            if (passwordIds.contains(id)) {
                onPassword(text)
            }
        }
        
        for (i in 0 until viewNode.childCount) {
            extractValuesFromNode(viewNode.getChildAt(i), usernameIds, passwordIds, onUsername, onPassword)
        }
    }

    private fun traverseStructure(structure: AssistStructure, usernameIds: ArrayList<AutofillId>, passwordIds: ArrayList<AutofillId>) {
        val nodes = structure.windowNodeCount
        for (i in 0 until nodes) {
            val windowNode = structure.getWindowNodeAt(i)
            val viewNode = windowNode.rootViewNode
            if (viewNode != null) {
                traverseNode(viewNode, usernameIds, passwordIds)
            }
        }
    }

    private fun traverseNode(viewNode: AssistStructure.ViewNode, usernameIds: ArrayList<AutofillId>, passwordIds: ArrayList<AutofillId>) {
        val hints = viewNode.autofillHints
        val className = viewNode.className ?: ""
        val hint = viewNode.hint ?: ""
        
        Log.d(TAG, "Node: class=$className, hint=$hint, hints=${hints?.joinToString(",")}, focused=${viewNode.isFocused}")
        val htmlInfo = viewNode.htmlInfo
        if (htmlInfo != null) {
            val htmlAttrs = htmlInfo.attributes?.joinToString(",") { "${it.first}=${it.second}" }
            Log.d(TAG, "  HTML: tag=${htmlInfo.tag}, attrs=$htmlAttrs")
        }

        var isUsername = false
        var isPassword = false
        
        if (hints != null) {
            val hintsStr = hints.joinToString(",")
            if (hintsStr.contains("username", true) || hintsStr.contains("email", true) || hintsStr.contains("login", true)) {
                isUsername = true
            }
            if (hintsStr.contains("password", true)) {
                isPassword = true
            }
        } 
        
        if (!isUsername && !isPassword) {
            val inputType = viewNode.inputType
            
            if (htmlInfo != null) {
                var type = ""
                var name = ""
                var id = ""
                val attrs = htmlInfo.attributes
                if (attrs != null) {
                    for (i in 0 until attrs.size) {
                        val attr = attrs[i]
                        val first = attr.first as? String ?: continue
                        val second = attr.second as? String ?: ""
                        if (first == "type") type = second
                        if (first == "name") name = second
                        if (first == "id") id = second
                    }
                }
                
                if (type.contains("password", true) || name.contains("password", true) || id.contains("password", true)) {
                    isPassword = true
                } else if ((type.contains("email", true) || type.contains("text", true)) && 
                           (name.contains("user", true) || name.contains("email", true) || name.contains("login", true) || 
                            id.contains("user", true) || id.contains("email", true) || id.contains("login", true))) {
                    isUsername = true
                }
            } else {
                if (className.contains("EditText", true) || className.contains("AutoCompleteTextView", true)) {
                    val variation = inputType and android.text.InputType.TYPE_MASK_VARIATION
                    if (variation == android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                        variation == android.text.InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD ||
                        variation == android.text.InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
                        variation == android.text.InputType.TYPE_NUMBER_VARIATION_PASSWORD) {
                        isPassword = true
                    } else if (hint.contains("password", true)) {
                        isPassword = true
                    } else if (hint.contains("user", true) || hint.contains("email", true) || hint.contains("login", true)) {
                        isUsername = true
                    }
                }
            }
        }

        if (isPassword) {
            viewNode.autofillId?.let { passwordIds.add(it) }
        } else if (isUsername) {
            viewNode.autofillId?.let { usernameIds.add(it) }
        }

        for (i in 0 until viewNode.childCount) {
            traverseNode(viewNode.getChildAt(i), usernameIds, passwordIds)
        }
    }
    
    private fun getWebDomain(structure: AssistStructure): String? {
        val nodes = structure.windowNodeCount
        for (i in 0 until nodes) {
            val windowNode = structure.getWindowNodeAt(i)
            val viewNode = windowNode.rootViewNode
            if (viewNode != null) {
                val domain = getWebDomain(viewNode)
                if (domain != null) return domain
            }
        }
        return null
    }

    private fun getWebDomain(viewNode: AssistStructure.ViewNode): String? {
        if (viewNode.webDomain != null) {
            return viewNode.webDomain
        }
        for (i in 0 until viewNode.childCount) {
            val domain = getWebDomain(viewNode.getChildAt(i))
            if (domain != null) return domain
        }
        return null
    }
}
