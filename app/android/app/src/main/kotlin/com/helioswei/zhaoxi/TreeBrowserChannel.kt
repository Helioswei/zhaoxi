package com.helioswei.zhaoxi

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 自研文件列表的数据源（方案 C）。
 *
 * 为什么：部分 ROM 的系统文件选择器不显示文件名，家人分不清哪个是备份。
 * 这里只借系统界面做**一次性目录授权**（点一下「使用此文件夹」即可，不用看文件名），
 * 之后所有列表都在 App 里自己画：名字、大小、时间、搜索都归我们管。
 */
class TreeBrowserChannel(private val activity: Activity) {
    private var pending: MethodChannel.Result? = null

    fun attach(engine: FlutterEngine) {
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "com.helioswei.zhaoxi/tree"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openTree" -> openTree(result)
                "list" -> {
                    val uri = call.argument<String>("uri")
                    if (uri.isNullOrBlank()) {
                        result.error("bad_args", "缺少目录 uri", null)
                    } else {
                        listAsync(Uri.parse(uri), result)
                    }
                }
                "readText" -> {
                    val uri = call.argument<String>("uri")
                    if (uri.isNullOrBlank()) {
                        result.error("bad_args", "缺少文件 uri", null)
                    } else {
                        readTextAsync(Uri.parse(uri), result)
                    }
                }
                "createFile" -> {
                    val uri = call.argument<String>("uri")
                    val name = call.argument<String>("name")
                    val text = call.argument<String>("text")
                    val mime = call.argument<String>("mime") ?: "application/octet-stream"
                    if (uri.isNullOrBlank() || name.isNullOrBlank() || text == null) {
                        result.error("bad_args", "缺少目录、文件名或内容", null)
                    } else {
                        createFileAsync(Uri.parse(uri), name, mime, text, result)
                    }
                }
                "release" -> {
                    val uri = call.argument<String>("uri")
                    if (!uri.isNullOrBlank()) {
                        try {
                            activity.contentResolver.releasePersistableUriPermission(
                                Uri.parse(uri),
                                Intent.FLAG_GRANT_READ_URI_PERMISSION
                            )
                        } catch (_: Exception) {
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 交给 MainActivity 转发；返回 true 表示这个是我们的请求码。 */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null

        val treeUri = if (resultCode == Activity.RESULT_OK) data?.data else null
        if (treeUri == null) {
            result.success(null)
            return true
        }
        // 授权要立刻持久化，否则重启 App 就读不到了。
        try {
            activity.contentResolver.takePersistableUriPermission(
                treeUri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
        } catch (_: Exception) {
            try {
                activity.contentResolver.takePersistableUriPermission(
                    treeUri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (_: Exception) {
            }
        }

        Thread {
            val name = displayName(treeUri) ?: treeUri.lastPathSegment ?: "文件夹"
            val payload = mapOf("uri" to treeUri.toString(), "name" to name)
            activity.runOnUiThread { result.success(payload) }
        }.start()
        return true
    }

    private fun openTree(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "已经有一个授权界面打开了", null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PREFIX_URI_PERMISSION
            )
        }
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (e: Exception) {
            pending = null
            result.error("no_picker", e.message ?: "打不开目录选择", null)
        }
    }

    private fun listAsync(treeUri: Uri, result: MethodChannel.Result) {
        Thread {
            val out = ArrayList<Map<String, Any?>>()
            val error = try {
                val rootId = DocumentsContract.getTreeDocumentId(treeUri)
                walk(treeUri, rootId, "", 0, out)
                null
            } catch (e: Exception) {
                e.message ?: "读取失败"
            }
            activity.runOnUiThread {
                if (error == null) {
                    result.success(out)
                } else {
                    result.error("list_failed", error, null)
                }
            }
        }.start()
    }

    /**
     * 递归找 .json / .txt。深度最多 3 层、最多 300 个：
     * 家人的备份就几十 KB，扫太多反而是负担。
     */
    private fun walk(
        treeUri: Uri,
        docId: String,
        path: String,
        depth: Int,
        out: MutableList<Map<String, Any?>>,
    ) {
        if (depth > 3 || out.size >= MAX_FILES) return
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, docId)
        val cursor = try {
            activity.contentResolver.query(childrenUri, null, null, null, null)
        } catch (_: Exception) {
            null
        } ?: return

        cursor.use { c ->
            val idIdx = c.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIdx = c.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val mimeIdx = c.getColumnIndex(DocumentsContract.Document.COLUMN_MIME_TYPE)
            val sizeIdx = c.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
            val modIdx = c.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            if (idIdx < 0 || nameIdx < 0) return

            while (c.moveToNext() && out.size < MAX_FILES) {
                val childId = c.getString(idIdx) ?: continue
                val name = c.getString(nameIdx) ?: continue
                val mime = if (mimeIdx >= 0) c.getString(mimeIdx) else null
                if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                    val childPath = if (path.isEmpty()) name else "$path/$name"
                    walk(treeUri, childId, childPath, depth + 1, out)
                    continue
                }
                if (!isBackupName(name)) continue
                out.add(
                    mapOf(
                        "name" to name,
                        "uri" to DocumentsContract
                            .buildDocumentUriUsingTree(treeUri, childId).toString(),
                        "size" to if (sizeIdx >= 0 && !c.isNull(sizeIdx)) c.getLong(sizeIdx) else -1L,
                        "modified" to if (modIdx >= 0 && !c.isNull(modIdx)) c.getLong(modIdx) else 0L,
                        "folder" to path,
                    )
                )
            }
        }
    }

    private fun readTextAsync(uri: Uri, result: MethodChannel.Result) {
        Thread {
            val text = try {
                activity.contentResolver.openInputStream(uri)?.use { input ->
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
            activity.runOnUiThread { result.success(text) }
        }.start()
    }

    /**
     * 在已授权的文件夹根目录里直接建一个文件并写入文本。
     *
     * 不弹系统「新建文件」对话框：那个界面在部分 ROM 上名字都渲染不出来，
     * 而我们已经握着目录授权，`createDocument` 一句话就能落盘。
     */
    private fun createFileAsync(
        treeUri: Uri,
        name: String,
        mime: String,
        text: String,
        result: MethodChannel.Result,
    ) {
        Thread {
            var created: Uri? = null
            var errorCode = "create_failed"
            var errorMessage = "写入失败"
            try {
                val rootId = DocumentsContract.getTreeDocumentId(treeUri)
                val parent = DocumentsContract.buildDocumentUriUsingTree(treeUri, rootId)
                val file = DocumentsContract.createDocument(
                    activity.contentResolver,
                    parent,
                    mime,
                    name,
                ) ?: throw IllegalStateException("系统没有返回新文件")
                activity.contentResolver.openOutputStream(file, "wt")?.use { out ->
                    out.write(text.toByteArray(Charsets.UTF_8))
                } ?: throw IllegalStateException("打不开新文件")
                created = file
            } catch (e: SecurityException) {
                // 只读授权（网盘、或当年只授了读）：给上层一个好认的错误码。
                errorCode = "no_write"
                errorMessage = "这个文件夹没有写权限"
            } catch (e: Exception) {
                errorMessage = e.message ?: "写入失败"
            }
            activity.runOnUiThread {
                if (created != null) {
                    result.success(created.toString())
                } else {
                    result.error(errorCode, errorMessage, null)
                }
            }
        }.start()
    }

    private fun displayName(uri: Uri): String? {
        return try {
            val docUri = DocumentsContract.buildDocumentUriUsingTree(
                uri,
                DocumentsContract.getTreeDocumentId(uri)
            )
            activity.contentResolver.query(
                docUri,
                arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                null, null, null
            )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        } catch (_: Exception) {
            null
        }
    }

    private fun isBackupName(name: String): Boolean {
        val lower = name.lowercase()
        return lower.endsWith(".json") || lower.endsWith(".txt")
    }

    companion object {
        private const val REQUEST_CODE = 0x5A2E
        private const val MAX_FILES = 300
    }
}
