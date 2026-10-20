package com.verssuite.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import androidx.webkit.ProxyConfig
import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.verssuite.mobile/native"
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Enable Chrome DevTools Remote Debugging via chrome://inspect
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            android.webkit.WebView.setWebContentsDebuggingEnabled(true)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFilesDir" -> {
                    result.success(filesDir.absolutePath)
                }
                "startForegroundService" -> {
                    startProxyService()
                    result.success(true)
                }
                "stopForegroundService" -> {
                    stopProxyService()
                    result.success(true)
                }
                "saveCertToDownloads" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val filename = call.argument<String>("filename") ?: "verssuite_ca.pem"
                    if (bytes != null) {
                        val success = saveBytesToDownloads(bytes, filename)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARG", "bytes is null", null)
                    }
                }
                "acquireWakeLock" -> {
                    acquireWakeLock()
                    result.success(true)
                }
                "releaseWakeLock" -> {
                    releaseWakeLock()
                    result.success(true)
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARG", "url is null", null)
                    }
                }
                "setWebViewProxy" -> {
                    val host = call.argument<String>("host") ?: "127.0.0.1"
                    val port = call.argument<Int>("port") ?: 8080
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    setWebViewProxy(host, port, enabled)
                    result.success(true)
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val ok = installApk(filePath)
                        result.success(ok)
                    } else {
                        result.error("INVALID_ARG", "filePath is null", null)
                    }
                }
                "getDeviceAbi" -> {
                    result.success(getDeviceAbi())
                }
                "getAppVersion" -> {
                    result.success(getAppVersion())
                }
                "isNetworkConnected" -> {
                    result.success(isNetworkConnected())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setWebViewProxy(host: String, port: Int, enabled: Boolean) {
        try {
            if (WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
                val controller = ProxyController.getInstance()
                if (enabled) {
                    val proxyConfig = ProxyConfig.Builder()
                        .addProxyRule("$host:$port")
                        .build()
                    controller.setProxyOverride(proxyConfig, { }, { })
                } else {
                    controller.clearProxyOverride({ }, { })
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startProxyService() {
        val intent = Intent(this, ProxyForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopProxyService() {
        val intent = Intent(this, ProxyForegroundService::class.java)
        stopService(intent)
    }

    private fun saveBytesToDownloads(bytes: ByteArray, filename: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, filename)
                    put(MediaStore.Downloads.MIME_TYPE, "application/x-pem-file")
                    put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                }
                val uri: Uri? = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                uri?.let {
                    contentResolver.openOutputStream(it)?.use { out ->
                        out.write(bytes)
                    }
                }
                true
            } else {
                @Suppress("DEPRECATION")
                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val file = File(dir, filename)
                file.writeBytes(bytes)
                true
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "verssuite:proxy")
            wakeLock?.acquire(60 * 60 * 1000L) // 1 hour max
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }

    private fun installApk(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val apkUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    this,
                    "${applicationContext.packageName}.fileprovider",
                    file
                )
            } else {
                Uri.fromFile(file)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (!packageManager.canRequestPackageInstalls()) {
                    val settingsIntent = Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName")
                    ).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(settingsIntent)
                }
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(apkUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun getDeviceAbi(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
        } else {
            @Suppress("DEPRECATION")
            Build.CPU_ABI ?: "arm64-v8a"
        }
    }

    private fun getAppVersion(): String {
        return try {
            val pInfo = packageManager.getPackageInfo(packageName, 0)
            pInfo.versionName ?: "1.0.0"
        } catch (e: Exception) {
            "1.0.0"
        }
    }

    private fun isNetworkConnected(): Boolean {
        return try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = cm.activeNetwork ?: return false
                val capabilities = cm.getNetworkCapabilities(network) ?: return false
                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            } else {
                @Suppress("DEPRECATION")
                val ni = cm.activeNetworkInfo
                ni?.isConnected == true
            }
        } catch (e: Exception) {
            true
        }
    }
}
