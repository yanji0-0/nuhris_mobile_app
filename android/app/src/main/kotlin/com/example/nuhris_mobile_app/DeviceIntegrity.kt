package com.example.nuhris_mobile_app

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import java.io.File
import java.net.InetSocketAddress
import java.net.Socket
import java.security.MessageDigest

/**
 * Client-side resilience checks (MASVS-RESILIENCE / CODE-4). They raise the
 * cost of tampering and instrumentation but can be bypassed by a determined
 * attacker; server-side controls (RLS) remain the real protection.
 */
class DeviceIntegrity(private val context: Context) {

    fun inspect(): Map<String, Any?> = mapOf(
        "rooted" to isRooted(),
        "emulator" to isEmulator(),
        "debuggable" to
            ((context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0),
        "debuggerAttached" to isDebuggerAttached(),
        "hookingDetected" to isHookingDetected(),
        "signingCertSha256" to signingCertSha256(),
    )

    private fun isRooted(): Boolean {
        if (Build.TAGS?.contains("test-keys") == true) return true
        val suPaths = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/system/su",
            "/system/bin/.ext/.su", "/system/usr/we-need-root/su-backup",
            "/data/local/su", "/data/local/bin/su", "/data/local/xbin/su",
            "/su/bin/su", "/system/app/Superuser.apk", "/system/app/SuperSU.apk",
            "/sbin/.magisk", "/cache/.disable_magisk", "/dev/.magisk.unblock",
        )
        if (suPaths.any { File(it).exists() }) return true
        val rootApps = listOf(
            "com.topjohnwu.magisk", "eu.chainfire.supersu",
            "com.koushikdutta.superuser", "com.noshufou.android.su",
            "me.weishu.kernelsu",
        )
        return rootApps.any { isInstalled(it) }
    }

    private fun isInstalled(packageName: String): Boolean = try {
        context.packageManager.getPackageInfo(packageName, 0)
        true
    } catch (e: PackageManager.NameNotFoundException) {
        false
    }

    private fun isEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT.orEmpty()
        val model = Build.MODEL.orEmpty()
        val product = Build.PRODUCT.orEmpty()
        val hardware = Build.HARDWARE.orEmpty()
        return fingerprint.startsWith("generic") ||
            fingerprint.startsWith("unknown") ||
            fingerprint.contains("emulator") ||
            model.contains("google_sdk") ||
            model.contains("Emulator") ||
            model.contains("Android SDK built for") ||
            Build.MANUFACTURER.orEmpty().contains("Genymotion") ||
            (Build.BRAND.orEmpty().startsWith("generic") &&
                Build.DEVICE.orEmpty().startsWith("generic")) ||
            product.contains("sdk_gphone") ||
            product == "google_sdk" ||
            product.contains("emulator") ||
            product.contains("simulator") ||
            hardware.contains("goldfish") ||
            hardware.contains("ranchu")
    }

    private fun isDebuggerAttached(): Boolean {
        if (Debug.isDebuggerConnected() || Debug.waitingForDebugger()) return true
        return try {
            File("/proc/self/status").readLines()
                .firstOrNull { it.startsWith("TracerPid:") }
                ?.substringAfter(":")?.trim()?.toIntOrNull()
                ?.let { it != 0 } ?: false
        } catch (e: Exception) {
            false
        }
    }

    private fun isHookingDetected(): Boolean {
        val markers = listOf("frida", "gadget", "xposed", "lsposed", "edxp", "substrate")
        val maps = try {
            File("/proc/self/maps").readText().lowercase()
        } catch (e: Exception) {
            ""
        }
        if (markers.any { maps.contains(it) }) return true

        val threadNames = try {
            File("/proc/self/task").listFiles().orEmpty().mapNotNull {
                try {
                    File(it, "comm").readText().trim()
                } catch (e: Exception) {
                    null
                }
            }
        } catch (e: Exception) {
            emptyList()
        }
        if (threadNames.any { it == "gum-js-loop" || it.startsWith("pool-frida") }) {
            return true
        }

        try {
            Class.forName("de.robv.android.xposed.XposedBridge")
            return true
        } catch (e: ClassNotFoundException) {
            // Not present.
        }

        // Default frida-server port.
        return try {
            Socket().use { it.connect(InetSocketAddress("127.0.0.1", 27042), 150) }
            true
        } catch (e: Exception) {
            false
        }
    }

    /** SHA-256 (uppercase hex) of the certificate that signed this APK. */
    @Suppress("DEPRECATION")
    private fun signingCertSha256(): String? {
        val info = context.packageManager.getPackageInfo(
            context.packageName,
            PackageManager.GET_SIGNING_CERTIFICATES,
        )
        val signingInfo = info.signingInfo ?: return null
        val signers = if (signingInfo.hasMultipleSigners()) {
            signingInfo.apkContentsSigners
        } else {
            signingInfo.signingCertificateHistory
        }
        val cert = signers?.lastOrNull() ?: return null
        return MessageDigest.getInstance("SHA-256").digest(cert.toByteArray())
            .joinToString("") { "%02X".format(it) }
    }
}
