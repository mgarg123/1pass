package com.example.one_pass

import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

class HiveReader(private val file: File) {

    fun readAllEntries(): List<Map<String, Any?>> {
        val entries = mutableListOf<Map<String, Any?>>()
        if (!file.exists()) return entries

        RandomAccessFile(file, "r").use { raf ->
            val channel = raf.channel
            val headerBuffer = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN)
            
            while (channel.position() < channel.size()) {
                headerBuffer.clear()
                val bytesRead = channel.read(headerBuffer)
                if (bytesRead < 4) break
                
                headerBuffer.flip()
                val frameLength = headerBuffer.getInt()
                
                if (frameLength <= 0 || channel.position() - 4 + frameLength > channel.size()) {
                    break // Corrupted or incomplete frame
                }
                
                val frameBuffer = ByteBuffer.allocate(frameLength - 4).order(ByteOrder.LITTLE_ENDIAN)
                channel.read(frameBuffer)
                frameBuffer.flip()
                
                try {
                    val isDeletedOrKeyLength = frameBuffer.get() // Hive framing byte
                    // Read key
                    val keyLength = frameBuffer.get().toInt()
                    val keyBytes = ByteArray(keyLength)
                    frameBuffer.get(keyBytes)
                    val keyStr = String(keyBytes, Charsets.UTF_8)
                    
                    // Now read the value
                    val value = readValue(frameBuffer)
                    if (value is Map<*, *>) {
                        @Suppress("UNCHECKED_CAST")
                        val mapValue = value as Map<String, Any?>
                        // In Hive, if a frame is updated, it's appended. So we might see the same key multiple times.
                        // We should probably keep the latest or store in a map.
                        entries.add(mapValue)
                    }
                } catch (e: Exception) {
                    // Ignore corrupted frame
                }
            }
        }
        
        // Return unique by ID, taking the latest (since it's an append-only log until compacted)
        return entries.associateBy { it["id"] as? String }.values.toList()
    }

    private fun readValue(buffer: ByteBuffer): Any? {
        if (!buffer.hasRemaining()) return null
        val typeId = buffer.get().toInt()
        return when (typeId) {
            0 -> null
            1 -> { buffer.position(buffer.position() + 8); 0 } // skip int
            2 -> { buffer.position(buffer.position() + 8); 0.0 } // skip double
            3 -> buffer.get() == 1.toByte() // bool
            4 -> {
                val length = buffer.getInt()
                val bytes = ByteArray(length)
                buffer.get(bytes)
                String(bytes, Charsets.UTF_8)
            }
            5, 6, 7, 8 -> { // IntList, DoubleList, BoolList, StringList
                val length = buffer.getInt()
                // Just skip lists since we don't strictly need tags for autofill
                // But StringList (8) would be size * length? No, StringList has lengths inside.
                // It's safer to just implement a generic skip or actually parse it.
                // Let's parse string list:
                if (typeId == 8) {
                    val list = mutableListOf<String>()
                    for (i in 0 until length) {
                        val strLen = buffer.getInt()
                        val bytes = ByteArray(strLen)
                        buffer.get(bytes)
                        list.add(String(bytes, Charsets.UTF_8))
                    }
                    list
                } else if (typeId == 9) { // Generic List
                    val list = mutableListOf<Any?>()
                    for (i in 0 until length) {
                        list.add(readValue(buffer))
                    }
                    list
                } else {
                    null // fallback
                }
            }
            9 -> { // Generic List
                val length = buffer.getInt()
                val list = mutableListOf<Any?>()
                for (i in 0 until length) {
                    list.add(readValue(buffer))
                }
                list
            }
            10, 11 -> { // Map
                val length = buffer.getInt()
                val map = mutableMapOf<Any?, Any?>()
                for (i in 0 until length) {
                    val key = readValue(buffer)
                    val value = readValue(buffer)
                    map[key] = value
                }
                map
            }
            else -> null
        }
    }
}
