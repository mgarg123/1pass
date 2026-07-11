package com.onepass.app

import android.util.Base64
import com.upokecenter.cbor.CBORObject
import org.json.JSONObject
import java.nio.ByteBuffer
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.MessageDigest
import java.security.SecureRandom
import java.security.spec.ECGenParameterSpec
import java.security.interfaces.ECPublicKey

object PasskeyCrypto {

    data class PasskeyGenerationResult(
        val credentialId: String,
        val responseJson: String,
        val privateKeyBase64: String
    )

    private var lastSignCount: Int = 0

    fun generatePasskey(origin: String, challengeBase64: String, username: String): PasskeyGenerationResult {
        // 1. Generate EC P-256 Key Pair
        val keyPairGenerator = KeyPairGenerator.getInstance("EC")
        keyPairGenerator.initialize(ECGenParameterSpec("secp256r1"))
        val keyPair = keyPairGenerator.generateKeyPair()
        
        val privateKeyBytes = keyPair.private.encoded
        val privateKeyBase64 = Base64.encodeToString(privateKeyBytes, Base64.DEFAULT)

        val publicKey = keyPair.public as ECPublicKey
        val w = publicKey.w
        // Ensure X and Y are exactly 32 bytes
        val xBytes = padTo32(w.affineX.toByteArray())
        val yBytes = padTo32(w.affineY.toByteArray())

        // 2. Generate Credential ID
        val credIdBytes = ByteArray(32)
        SecureRandom().nextBytes(credIdBytes)
        val credIdBase64Url = Base64.encodeToString(credIdBytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

        // 4. Build clientDataJSON manually to avoid JSONObject escaping forward slashes
        val clientDataJsonStr = """{"type":"webauthn.create","challenge":"$challengeBase64","origin":"$origin","crossOrigin":false}"""
        val clientDataJsonBase64Url = Base64.encodeToString(clientDataJsonStr.toByteArray(Charsets.UTF_8), Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

        // 4. Build authData
        val rpId = origin.replace("https://", "").replace("http://", "")
        val rpIdHash = MessageDigest.getInstance("SHA-256").digest(rpId.toByteArray(Charsets.UTF_8))
        
        // Flags: UP (0x01) | AT (0x40) = 0x41
        val flags: Byte = 0x41
        
        // Sign count (4 bytes): 0
        val signCount = ByteArray(4) { 0 }
        
        // AAGUID (16 bytes): 0
        val aaguid = ByteArray(16) { 0 }
        
        // Credential ID length (2 bytes)
        val credIdLen = ByteBuffer.allocate(2).putShort(credIdBytes.size.toShort()).array()
        
        // COSE Key CBOR map
        val coseKey = CBORObject.NewMap().apply {
            set(1, CBORObject.FromObject(2)) // kty: EC2
            set(3, CBORObject.FromObject(-7)) // alg: ES256
            set(-1, CBORObject.FromObject(1)) // crv: P-256
            set(-2, CBORObject.FromObject(xBytes)) // x
            set(-3, CBORObject.FromObject(yBytes)) // y
        }.EncodeToBytes()
        
        // Assemble authData
        val authData = ByteBuffer.allocate(
            rpIdHash.size + 1 + 4 + 16 + 2 + credIdBytes.size + coseKey.size
        ).apply {
            put(rpIdHash)
            put(flags)
            put(signCount)
            put(aaguid)
            put(credIdLen)
            put(credIdBytes)
            put(coseKey)
        }.array()

        // 5. Build attestationObject
        val attStmt = CBORObject.NewMap() // empty map for fmt="none"
        val attObj = CBORObject.NewMap().apply {
            set("fmt", CBORObject.FromObject("none"))
            set("attStmt", attStmt)
            set("authData", CBORObject.FromObject(authData))
        }.EncodeToBytes()
        
        val attObjBase64Url = Base64.encodeToString(attObj, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

        // Generate SPKI bytes for publicKey field
        val spkiBytes = publicKey.encoded
        val spkiBase64Url = Base64.encodeToString(spkiBytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

        // 6. Build the final JSON response expected by Credential Manager
        val responseJsonObj = JSONObject().apply {
            put("id", credIdBase64Url)
            put("rawId", credIdBase64Url)
            put("type", "public-key")
            put("authenticatorAttachment", "platform")
            put("clientExtensionResults", JSONObject())
            put("response", JSONObject().apply {
                put("clientDataJSON", clientDataJsonBase64Url)
                put("attestationObject", attObjBase64Url)
                val transports = org.json.JSONArray()
                transports.put("internal")
                put("transports", transports)
                put("publicKeyAlgorithm", -7)
                put("publicKey", spkiBase64Url)
                put("authenticatorData", Base64.encodeToString(authData, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP))
            })
        }
        
        return PasskeyGenerationResult(
            credentialId = credIdBase64Url,
            responseJson = responseJsonObj.toString(),
            privateKeyBase64 = privateKeyBase64
        )
    }

    private fun padTo32(array: ByteArray): ByteArray {
        if (array.size == 32) return array
        if (array.size > 32) return array.copyOfRange(array.size - 32, array.size)
        val result = ByteArray(32)
        System.arraycopy(array, 0, result, 32 - array.size, array.size)
        return result
    }

    fun authenticatePasskey(origin: String, challengeBase64: String, privateKeyBase64: String, credentialIdBase64Url: String, userHandle: String = ""): String {
        // 1. Reconstruct Private Key
        val privateKeyBytes = Base64.decode(privateKeyBase64, Base64.DEFAULT)
        val keyFactory = java.security.KeyFactory.getInstance("EC")
        val privateKey = keyFactory.generatePrivate(java.security.spec.PKCS8EncodedKeySpec(privateKeyBytes))

        // 4. Build clientDataJSON manually to avoid JSONObject escaping forward slashes
        val clientDataJsonStr = """{"type":"webauthn.get","challenge":"$challengeBase64","origin":"$origin","crossOrigin":false}"""
        val clientDataJsonBase64Url = Base64.encodeToString(clientDataJsonStr.toByteArray(Charsets.UTF_8), Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
        
        val clientDataHash = MessageDigest.getInstance("SHA-256").digest(clientDataJsonStr.toByteArray(Charsets.UTF_8))

        // 3. Build authData
        val rpId = origin.replace("https://", "").replace("http://", "")
        val rpIdHash = MessageDigest.getInstance("SHA-256").digest(rpId.toByteArray(Charsets.UTF_8))
        
        // Flags: UP (0x01)
        val flags: Byte = 0x01
        
        // Sign count (4 bytes): must be monotonically increasing.
        // We use the Unix timestamp in seconds, which always goes up.
        // If multiple authentications happen in the same second, we add an offset.
        val currentSeconds = (System.currentTimeMillis() / 1000).toInt()
        val countToUse = if (currentSeconds > lastSignCount) currentSeconds else lastSignCount + 1
        lastSignCount = countToUse
        val signCount = ByteBuffer.allocate(4).putInt(countToUse).array()
        
        val authData = ByteBuffer.allocate(rpIdHash.size + 1 + 4).apply {
            put(rpIdHash)
            put(flags)
            put(signCount)
        }.array()

        // 4. Create Signature
        val signature = java.security.Signature.getInstance("SHA256withECDSA").apply {
            initSign(privateKey)
            update(authData)
            update(clientDataHash)
        }.sign()
        
        val signatureBase64Url = Base64.encodeToString(signature, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
        val authDataBase64Url = Base64.encodeToString(authData, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

        // 5. Build JSON
        val responseJsonObj = JSONObject().apply {
            put("id", credentialIdBase64Url)
            put("rawId", credentialIdBase64Url)
            put("type", "public-key")
            put("authenticatorAttachment", "platform")
            put("clientExtensionResults", JSONObject())
            put("response", JSONObject().apply {
                put("clientDataJSON", clientDataJsonBase64Url)
                put("authenticatorData", authDataBase64Url)
                put("signature", signatureBase64Url)
                if (userHandle.isNotEmpty()) {
                    put("userHandle", userHandle)
                }
            })
        }
        
        return responseJsonObj.toString()
    }
}
