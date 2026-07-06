package com.example.one_pass

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.nio.charset.StandardCharsets
import java.util.Base64

class CryptoServiceTest {

    @Test
    fun `test AES-GCM decrypt with known dart vector`() {
        val cryptoService = CryptoService()
        
        // Vectors generated from Dart CryptoService
        val keyHex = "00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f".replace(" ", "")
        val nonceHex = "51 52 c7 d4 9f 68 fe 9e b1 25 7b 0e".replace(" ", "")
        val cipherHex = "48 d2 5b ab 16 38 8c 00 40 68 c6 42 0b 8f fb 75 b2 ff b2 d1 b6 ae da a4".replace(" ", "")
        val macHex = "b4 72 1f 5e de 7e 0b de 70 e6 7c 2a 3d c7 60 80".replace(" ", "")
        
        val key = hexStringToByteArray(keyHex)
        val nonce = hexStringToByteArray(nonceHex)
        val cipherText = hexStringToByteArray(cipherHex)
        val mac = hexStringToByteArray(macHex)
        
        val decrypted = cryptoService.decrypt(cipherText, nonce, mac, key)
        val plaintext = String(decrypted, StandardCharsets.UTF_8)
        
        assertEquals("Hello, Kotlin from Dart!", plaintext)
    }

    @Test
    fun `test tamper detection throws exception`() {
        val cryptoService = CryptoService()
        
        val keyHex = "00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f".replace(" ", "")
        val nonceHex = "51 52 c7 d4 9f 68 fe 9e b1 25 7b 0e".replace(" ", "")
        val cipherHex = "48 d2 5b ab 16 38 8c 00 40 68 c6 42 0b 8f fb 75 b2 ff b2 d1 b6 ae da a4".replace(" ", "")
        val macHex = "b4 72 1f 5e de 7e 0b de 70 e6 7c 2a 3d c7 60 80".replace(" ", "")
        
        val key = hexStringToByteArray(keyHex)
        val nonce = hexStringToByteArray(nonceHex)
        var cipherText = hexStringToByteArray(cipherHex)
        val mac = hexStringToByteArray(macHex)
        
        // Tamper ciphertext
        cipherText[0] = (cipherText[0].toInt() xor 0xFF).toByte()
        
        val exception = assertThrows(DecryptionFailedException::class.java) {
            cryptoService.decrypt(cipherText, nonce, mac, key)
        }
        assert(exception.message!!.contains("Decryption failed"))
    }
    
    @Test
    fun `test wrong key throws exception`() {
        val cryptoService = CryptoService()
        
        val keyHex = "ff 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f 10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f".replace(" ", "")
        val nonceHex = "51 52 c7 d4 9f 68 fe 9e b1 25 7b 0e".replace(" ", "")
        val cipherHex = "48 d2 5b ab 16 38 8c 00 40 68 c6 42 0b 8f fb 75 b2 ff b2 d1 b6 ae da a4".replace(" ", "")
        val macHex = "b4 72 1f 5e de 7e 0b de 70 e6 7c 2a 3d c7 60 80".replace(" ", "")
        
        val key = hexStringToByteArray(keyHex) // Wrong key (first byte modified)
        val nonce = hexStringToByteArray(nonceHex)
        val cipherText = hexStringToByteArray(cipherHex)
        val mac = hexStringToByteArray(macHex)
        
        val exception = assertThrows(DecryptionFailedException::class.java) {
            cryptoService.decrypt(cipherText, nonce, mac, key)
        }
        assert(exception.message!!.contains("Decryption failed"))
    }

    private fun hexStringToByteArray(s: String): ByteArray {
        val len = s.length
        val data = ByteArray(len / 2)
        var i = 0
        while (i < len) {
            data[i / 2] = ((Character.digit(s[i], 16) shl 4)
                    + Character.digit(s[i + 1], 16)).toByte()
            i += 2
        }
        return data
    }
}
