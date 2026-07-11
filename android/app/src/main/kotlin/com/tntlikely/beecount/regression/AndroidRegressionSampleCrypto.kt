package com.tntlikely.beecount.regression

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

data class EncryptedPayload(val nonce: ByteArray, val ciphertext: ByteArray)
data class UnwrappedDataKey(val key: SecretKey, val version: Int)

class AndroidRegressionSampleCrypto(
    private val context: Context,
    private val keyAlias: String = DEFAULT_KEY_ALIAS,
) {
    private val secureRandom = SecureRandom()
    private val keyDirectory = File(context.filesDir, KEY_DIRECTORY).apply { mkdirs() }
    private val wrappedKeyFile = File(keyDirectory, "${safeAlias(keyAlias)}.json")

    fun loadDataKey(): UnwrappedDataKey {
        val wrappingKey = getOrCreateWrappingKey()
        if (!wrappedKeyFile.exists()) {
            val rawDataKey = ByteArray(DATA_KEY_BYTES).also(secureRandom::nextBytes)
            val wrapped = wrap(wrappingKey, rawDataKey)
            val record = JSONObject()
                .put("version", CURRENT_KEY_VERSION)
                .put("nonce", Base64.encodeToString(wrapped.nonce, Base64.NO_WRAP))
                .put("ciphertext", Base64.encodeToString(wrapped.ciphertext, Base64.NO_WRAP))
            wrappedKeyFile.writeText(record.toString())
            return UnwrappedDataKey(SecretKeySpec(rawDataKey, "AES"), CURRENT_KEY_VERSION)
        }

        val record = JSONObject(wrappedKeyFile.readText())
        val rawDataKey = decrypt(
            wrappingKey,
            Base64.decode(record.getString("nonce"), Base64.NO_WRAP),
            Base64.decode(record.getString("ciphertext"), Base64.NO_WRAP),
        )
        return UnwrappedDataKey(
            SecretKeySpec(rawDataKey, "AES"),
            record.getInt("version"),
        )
    }

    fun encrypt(key: SecretKey, plaintext: ByteArray): EncryptedPayload {
        val nonce = ByteArray(NONCE_BYTES).also(secureRandom::nextBytes)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(TAG_BITS, nonce))
        return EncryptedPayload(nonce, cipher.doFinal(plaintext))
    }

    private fun wrap(key: SecretKey, plaintext: ByteArray): EncryptedPayload {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key)
        return EncryptedPayload(cipher.iv, cipher.doFinal(plaintext))
    }

    fun decrypt(key: SecretKey, nonce: ByteArray, ciphertext: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, nonce))
        return cipher.doFinal(ciphertext)
    }

    private fun getOrCreateWrappingKey(): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
        (keyStore.getKey(keyAlias, null) as? SecretKey)?.let { return it }

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEY_STORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                keyAlias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    companion object {
        const val DEFAULT_KEY_ALIAS = "beecount_regression_sample_wrapping_v1"
        const val KEY_DIRECTORY = "regression_keys"
        private const val CURRENT_KEY_VERSION = 1
        private const val DATA_KEY_BYTES = 32
        private const val NONCE_BYTES = 12
        private const val TAG_BITS = 128
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val ANDROID_KEY_STORE = "AndroidKeyStore"

        private fun safeAlias(alias: String): String = alias.replace(Regex("[^A-Za-z0-9_.-]"), "_")

        fun deleteTestKey(alias: String) {
            require(alias.startsWith("beecount-regression-test-"))
            KeyStore.getInstance(ANDROID_KEY_STORE).apply {
                load(null)
                deleteEntry(alias)
            }
        }
    }
}
