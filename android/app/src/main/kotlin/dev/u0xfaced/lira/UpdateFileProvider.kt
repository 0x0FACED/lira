package dev.u0xfaced.lira

import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileNotFoundException

class UpdateFileProvider : FileProvider() {
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw FileNotFoundException("Update APKs are read-only.")
        requireApkUri(uri)
        return super.openFile(uri, mode)
            ?: throw FileNotFoundException("The update APK could not be opened.")
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        requireApkUri(uri)
        return super.query(uri, projection, selection, selectionArgs, sortOrder)
    }

    override fun getType(uri: Uri): String {
        requireApkUri(uri)
        return "application/vnd.android.package-archive"
    }

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int {
        throw SecurityException("Update APKs cannot be deleted through the provider.")
    }

    private fun requireApkUri(uri: Uri) {
        val context = context ?: throw FileNotFoundException("The update provider is unavailable.")
        val segments = uri.pathSegments
        if (uri.scheme != "content" || uri.authority != "${context.packageName}.updates" ||
            segments.size != 2 || segments[0] != "updates" || !segments[1].endsWith(".apk")
        ) {
            throw FileNotFoundException("Only downloaded update APKs may be shared.")
        }
        val directory = File(context.noBackupFilesDir, "updates").canonicalFile
        val file = File(directory, segments[1]).canonicalFile
        if (file.parentFile != directory || !file.isFile) {
            throw FileNotFoundException("The update APK is unavailable.")
        }
    }
}
