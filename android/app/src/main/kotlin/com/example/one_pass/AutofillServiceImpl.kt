package com.example.one_pass

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
        } else {
            // Below SDK 31, no mutability flag is required but acceptable
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            1001,
            authIntent,
            flags
        )

        val presentation = RemoteViews(packageName, android.R.layout.simple_list_item_1)
        presentation.setTextViewText(android.R.id.text1, "Unlock 1Pass")

        val autofillIds = mutableListOf<AutofillId>()
        autofillIds.addAll(usernameIds)
        autofillIds.addAll(passwordIds)

        val response = FillResponse.Builder()
            .setAuthentication(autofillIds.toTypedArray(), pendingIntent.intentSender, presentation)
            .build()
            
        callback.onSuccess(response)
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
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
                val type = htmlInfo.attributes?.find { it.first == "type" }?.second ?: ""
                val name = htmlInfo.attributes?.find { it.first == "name" }?.second ?: ""
                val id = htmlInfo.attributes?.find { it.first == "id" }?.second ?: ""
                
                if (type.contains("password", true) || name.contains("password", true) || id.contains("password", true)) {
                    isPassword = true
                } else if ((type.contains("email", true) || type.contains("text", true)) && 
                           (name.contains("user", true) || name.contains("email", true) || name.contains("login", true) || 
                            id.contains("user", true) || id.contains("email", true) || id.contains("login", true))) {
                    isUsername = true
                }
            } else {
                if (className.contains("EditText", true) || className.contains("AutoCompleteTextView", true)) {
                    if (inputType == android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD ||
                        inputType == 129 || inputType == 225) { 
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
