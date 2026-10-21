package com.helioswei.zhaoxi

import android.content.Intent
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 「分享到朝夕」的接收端。
 *
 * 为什么要有它：部分机型（小米等）的系统文件选择器会把文件名显示成空白，
 * 家人根本分不清哪个是备份。从微信里「用其他应用打开 / 分享」进本 App
 * 就完全绕开那个界面。
 */
class MainActivity : FlutterActivity() {
    /** 收到的文件内容（等 Flutter 来取）。 */
    private var pendingShare: Map<String, String>? = null

    /** 收到文件后主动通知 Flutter（App 在前台时也能立刻响应）。 */
    private var shareChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val share = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.helioswei.zhaoxi/share"
        )
        share.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePendingShare" -> {
                    val pendingFile = pendingShare
                    pendingShare = null
                    result.success(pendingFile)
                }
                else -> result.notImplemented()
            }
        }
        shareChannel = share
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        captureShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureShare(intent)
    }

    /** 把收到的文件（分享 / 用其他应用打开）读成文本。 */
    private fun captureShare(intent: Intent?) {
        if (intent == null) return
        val uri = try {
            when (intent.action) {
                Intent.ACTION_SEND ->
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                Intent.ACTION_VIEW -> intent.data
                else -> null
            }
        } catch (_: Exception) {
            null
        } ?: return

        Thread {
            val name = try {
                contentResolver.query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME),
                    null, null, null
                )?.use { c ->
                    if (c.moveToFirst()) c.getString(0) else null
                }
            } catch (_: Exception) {
                null
            } ?: uri.lastPathSegment ?: "共享文件"

            val text = try {
                contentResolver.openInputStream(uri)?.use { input ->
                    // 备份文件就几十 KB，最多读 4 MB，防止误收大文件。
                    val buf = ByteArray(4 * 1024 * 1024)
                    var total = 0
                    val out = java.io.ByteArrayOutputStream()
                    while (total < buf.size) {
                        val n = input.read(buf, total, buf.size - total)
                        if (n <= 0) break
                        out.write(buf, total, n)
                        total += n
                    }
                    String(out.toByteArray(), Charsets.UTF_8)
                }
            } catch (_: Exception) {
                null
            }

            runOnUiThread {
                if (text == null) {
                    // 读不到（常见于对方只给了路径、没给读取授权）
                    try {
                        shareChannel?.invokeMethod("onShareFailed", mapOf("name" to name))
                    } catch (_: Exception) {
                    }
                    return@runOnUiThread
                }
                pendingShare = mapOf("name" to name, "content" to text)
                try {
                    shareChannel?.invokeMethod("onShare", mapOf("name" to name))
                } catch (_: Exception) {
                }
            }
        }.start()
    }
}
