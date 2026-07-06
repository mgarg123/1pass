package com.example.one_pass

import java.nio.ByteBuffer
import java.security.InvalidAlgorithmParameterException
import java.security.InvalidKeyException
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import android.util.Base64

class DecryptionFailedException(message: String) : Exception(message)

class CryptoService {

    fun decrypt(blobStorageString: String, keyBytes: ByteArray): ByteArray {
        val parts = blobStorageString.split(":")
        if (parts.size != 3) {
            throw IllegalArgumentException("Invalid EncryptedBlob storage format.")
        }
        
        val nonce = Base64.decode(parts[0], Base64.DEFAULT)
        val cipherText = Base64.decode(parts[1], Base64.DEFAULT)
        val mac = Base64.decode(parts[2], Base64.DEFAULT)
        
        return decrypt(cipherText, nonce, mac, keyBytes)
    }

    fun decrypt(cipherText: ByteArray, nonce: ByteArray, mac: ByteArray, keyBytes: ByteArray): ByteArray {
        if (keyBytes.size != 32) {
            throw IllegalArgumentException("Key must be 32 bytes")
        }
        if (nonce.size != 12) {
            throw IllegalArgumentException("Nonce must be 12 bytes")
        }
        if (mac.size != 16) {
            throw IllegalArgumentException("MAC must be 16 bytes")
        }

        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            val secretKeySpec = SecretKeySpec(keyBytes, "AES")
            val gcmParameterSpec = GCMParameterSpec(128, nonce)
            
            cipher.init(Cipher.DECRYPT_MODE, secretKeySpec, gcmParameterSpec)
            
            // Java's AES/GCM expects the ciphertext and MAC to be concatenated
            val combined = ByteBuffer.allocate(cipherText.size + mac.size)
                .put(cipherText)
                .put(mac)
                .array()
                
            return cipher.doFinal(combined)
        } catch (e: AEADBadTagException) {
            throw DecryptionFailedException("Decryption failed: tampered data or wrong key.")
        } catch (e: Exception) {
            throw DecryptionFailedException("Decryption failed: ${e.message}")
        }
    }
}
