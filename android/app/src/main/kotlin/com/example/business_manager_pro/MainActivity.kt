package com.example.business_manager_pro

import android.os.Build
import android.os.Debug
import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.logitech.security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableScreenshotProtection" -> {
                    try {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FLAG_SECURE_ERROR", e.message, null)
                    }
                }
                "disableScreenshotProtection" -> {
                    try {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("FLAG_SECURE_ERROR", e.message, null)
                    }
                }
                "checkDeviceSecurity" -> {
                    try {
                        val isRooted = checkRoot()
                        val isEmulator = checkEmulator()
                        val isDebugger = checkDebugger()
                        val isFrida = checkFridaAndHooks()

                        val securityReport = mapOf(
                            "isRooted" to isRooted,
                            "isEmulator" to isEmulator,
                            "isDebuggerConnected" to isDebugger,
                            "isFridaDetected" to isFrida,
                            "isSecure" to (!isRooted && !isDebugger && !isFrida)
                        )
                        result.success(securityReport)
                    } catch (e: Exception) {
                        result.error("SECURITY_CHECK_ERROR", e.message, null)
                    }
                }
                "isBiometricAvailable" -> {
                    try {
                        val biometricManager = BiometricManager.from(this)
                        val canAuth = biometricManager.canAuthenticate(
                            BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.BIOMETRIC_WEAK
                        )
                        result.success(canAuth == BiometricManager.BIOMETRIC_SUCCESS)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "authenticateBiometrics" -> {
                    val title = call.argument<String>("title") ?: "Authentification LogiTech Pro"
                    val subtitle = call.argument<String>("subtitle") ?: "Veuillez vous authentifier"
                    val cancelText = call.argument<String>("cancelText") ?: "Annuler"

                    try {
                        val executor = ContextCompat.getMainExecutor(this)
                        val promptInfo = BiometricPrompt.PromptInfo.Builder()
                            .setTitle(title)
                            .setSubtitle(subtitle)
                            .setNegativeButtonText(cancelText)
                            .build()

                        val biometricPrompt = BiometricPrompt(
                            this,
                            executor,
                            object : BiometricPrompt.AuthenticationCallback() {
                                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                                    super.onAuthenticationSucceeded(authResult)
                                    result.success(true)
                                }

                                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                                    super.onAuthenticationError(errorCode, errString)
                                    result.success(false)
                                }

                                override fun onAuthenticationFailed() {
                                    super.onAuthenticationFailed()
                                }
                            }
                        )

                        biometricPrompt.authenticate(promptInfo)
                    } catch (e: Exception) {
                        result.error("BIOMETRIC_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun checkRoot(): Boolean {
        val buildTags = Build.TAGS
        if (buildTags != null && buildTags.contains("test-keys")) {
            return true
        }

        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su"
        )
        for (path in paths) {
            if (File(path).exists()) return true
        }

        return false
    }

    private fun checkEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.BOARD == "QC_Reference_Phone"
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.PRODUCT.contains("sdk_google")
                || Build.PRODUCT.contains("google_sdk")
                || Build.PRODUCT.contains("sdk")
                || Build.PRODUCT.contains("sdk_x86")
                || Build.PRODUCT.contains("vbox86p")
                || Build.PRODUCT.contains("emulator")
                || Build.PRODUCT.contains("simulator"))
    }

    private fun checkDebugger(): Boolean {
        return Debug.isDebuggerConnected() || Debug.waitingForDebugger()
    }

    private fun checkFridaAndHooks(): Boolean {
        val fridaPaths = arrayOf(
            "/data/local/tmp/frida-server",
            "/data/local/tmp/re.frida.server",
            "/sdcard/frida-server"
        )
        for (p in fridaPaths) {
            if (File(p).exists()) return true
        }

        try {
            Class.forName("de.robv.android.xposed.XposedBridge")
            return true
        } catch (_: ClassNotFoundException) {}

        return false
    }
}
