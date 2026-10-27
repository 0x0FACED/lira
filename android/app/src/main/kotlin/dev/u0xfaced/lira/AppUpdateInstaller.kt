package dev.u0xfaced.lira

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

internal object AppUpdateInstaller {
    private const val TAG = "AppUpdateInstaller"
    private const val PREFERENCES = "app_updates"
    private const val PENDING_PATH = "pending_path"
    private const val PENDING_BUILD = "pending_build"
    private const val APK_MIME_TYPE = "application/vnd.android.package-archive"

    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "lira-app-updates").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())
    private val queueLock = Any()
    private val installingPaths = ConcurrentHashMap<String, Boolean>()
    private var startupScheduled = false

    fun start(context: Context) {
        synchronized(queueLock) {
            scheduleStartupLocked(context.applicationContext)
        }
    }

    fun getUpdateDirectory(context: Context, result: MethodChannel.Result) {
        enqueue(context) {
            try {
                val path = updateDirectory(context).absolutePath
                mainHandler.post { result.success(path) }
            } catch (error: Exception) {
                fail(result, error)
            }
        }
    }

    fun cleanupUpdates(context: Context, result: MethodChannel.Result) {
        scheduleCleanup(context) { error ->
            if (error == null) {
                mainHandler.post { result.success(null) }
            } else {
                fail(result, error)
            }
        }
    }

    fun onPackageReplaced(context: Context, finished: () -> Unit) {
        scheduleCleanup(context) { error ->
            if (error != null) Log.w(TAG, "Could not clean completed updates", error)
            finished()
        }
    }

    fun installUpdate(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val path = arguments?.get("path") as? String
        val version = arguments?.get("version") as? String
        val requestedBuild = arguments?.get("buildNumber")
        val buildNumber = when (requestedBuild) {
            is Int -> requestedBuild.toLong()
            is Long -> requestedBuild
            else -> null
        }
        if (path.isNullOrBlank() || version.isNullOrBlank() ||
            (requestedBuild != null && (buildNumber == null || buildNumber <= 0))
        ) {
            result.error("invalid_apk", "An APK path, version and optional positive build number are required.", null)
            return
        }

        val context = activity.applicationContext
        enqueue(context) {
            var protectedPath: String? = null
            try {
                val file = requireUpdateFile(context, path)
                protectedPath = file.path
                installingPaths[file.path] = true
                val archiveBuild = validateApk(context, file, version, buildNumber)
                val needsPermission = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    !context.packageManager.canRequestPackageInstalls()
                val intent = if (needsPermission) {
                    Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))
                } else {
                    val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", file)
                    Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, APK_MIME_TYPE)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        clipData = ClipData.newRawUri("Lira update", uri)
                    }
                }

                mainHandler.post {
                    try {
                        if (activity.isFinishing || activity.isDestroyed) {
                            throw IOException("The installer cannot be opened from a closed activity.")
                        }
                        activity.startActivity(intent)
                        if (needsPermission) {
                            installingPaths.remove(file.path)
                            result.success("permissionRequired")
                        } else {
                            // Only a successfully launched system installer creates a pending target.
                            executor.execute {
                                try {
                                    val stored = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                                        .edit()
                                        .putString(PENDING_PATH, file.path)
                                        .putLong(PENDING_BUILD, archiveBuild)
                                        .commit()
                                    if (!stored) Log.w(TAG, "Could not persist the launched update target")
                                } catch (error: Exception) {
                                    // Obsolete-APK scanning still handles replacement if persistence fails.
                                    Log.w(TAG, "Could not persist the launched update target", error)
                                } finally {
                                    installingPaths.remove(file.path)
                                    mainHandler.post { result.success("started") }
                                }
                            }
                        }
                    } catch (error: Exception) {
                        installingPaths.remove(file.path)
                        fail(result, error)
                    }
                }
            } catch (error: Exception) {
                protectedPath?.let { installingPaths.remove(it) }
                fail(result, error)
            }
        }
    }

    private fun enqueue(context: Context, task: () -> Unit) {
        synchronized(queueLock) {
            scheduleStartupLocked(context.applicationContext)
            executor.execute(task)
        }
    }

    private fun scheduleStartupLocked(context: Context) {
        if (startupScheduled) return
        startupScheduled = true
        executor.execute {
            try {
                cleanup(context, removePartialFiles = true)
            } catch (error: Exception) {
                Log.w(TAG, "Could not clean updates at startup", error)
            }
        }
    }

    private fun scheduleCleanup(context: Context, finished: (Exception?) -> Unit) {
        val applicationContext = context.applicationContext
        synchronized(queueLock) {
            val firstCleanup = !startupScheduled
            startupScheduled = true
            executor.execute {
                val error = try {
                    cleanup(applicationContext, removePartialFiles = firstCleanup)
                    null
                } catch (error: Exception) {
                    error
                }
                finished(error)
            }
        }
    }

    private fun updateDirectory(context: Context): File {
        val directory = File(context.noBackupFilesDir, "updates").canonicalFile
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("Could not create the private update directory.")
        }
        return directory
    }

    private fun requireUpdateFile(context: Context, path: String): File {
        val requested = File(path)
        val file = requested.canonicalFile
        if (!requested.isAbsolute || file.parentFile != updateDirectory(context) ||
            !file.name.endsWith(".apk") || !file.isFile || file.length() == 0L
        ) {
            throw InstallException("invalid_apk", "The APK must be a complete file in the private update directory.")
        }
        return file
    }

    private fun validateApk(context: Context, file: File, version: String, buildNumber: Long?): Long {
        val archive = readArchive(context.packageManager, file)
            ?: throw InstallException("invalid_apk", "The file is not a readable APK.")
        val archiveBuild = versionCode(archive)
        if (archive.packageName != context.packageName || archive.versionName != version ||
            (buildNumber != null && archiveBuild != buildNumber)
        ) {
            throw InstallException("invalid_apk", "The APK package or version does not match the requested update.")
        }
        val installed = readInstalled(context)
        if (archiveBuild <= versionCode(installed)) {
            throw InstallException("invalid_apk", "The update build must be newer than the installed build.")
        }
        if (!sameCurrentSigners(installed, archive)) {
            throw InstallException("incompatible_signature", "The APK is not signed by the installed app's current signer.")
        }
        return archiveBuild
    }

    private fun cleanup(context: Context, removePartialFiles: Boolean) {
        val directory = updateDirectory(context)
        val installed = readInstalled(context)
        val installedBuild = versionCode(installed)
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val pendingBuild = preferences.getLong(PENDING_BUILD, -1)
        val pendingPath = preferences.getString(PENDING_PATH, null)
        var failedDeletion = false
        val files = directory.listFiles() ?: throw IOException("Could not list the private update directory.")
        for (entry in files) {
            val file = entry.canonicalFile
            if (file.parentFile != directory || !file.isFile || installingPaths.containsKey(file.path)) continue
            val shouldDelete = if (file.name.endsWith(".part")) {
                // Startup precedes the first directory response. Later cleanup must never
                // race a Dart download, even one paused for a long time.
                removePartialFiles
            } else if (file.name.endsWith(".apk")) {
                val archive = readArchive(context.packageManager, file)
                if (archive == null) {
                    file.path == pendingPath && pendingBuild > 0 && installedBuild >= pendingBuild
                } else {
                    archive.packageName == context.packageName &&
                        versionCode(archive) <= installedBuild && sameCurrentSigners(installed, archive)
                }
            } else {
                false
            }
            if (shouldDelete && !file.delete()) failedDeletion = true
        }
        if (pendingBuild > 0 && installedBuild >= pendingBuild &&
            (pendingPath == null || !File(pendingPath).exists())
        ) {
            if (!preferences.edit().remove(PENDING_PATH).remove(PENDING_BUILD).commit()) {
                throw IOException("Could not clear the completed update target.")
            }
        }
        if (failedDeletion) throw IOException("Some obsolete update files could not be deleted.")
    }

    @Suppress("DEPRECATION")
    private fun readInstalled(context: Context): PackageInfo =
        context.packageManager.getPackageInfo(context.packageName, signingFlags())

    @Suppress("DEPRECATION")
    private fun readArchive(manager: PackageManager, file: File): PackageInfo? =
        manager.getPackageArchiveInfo(file.path, signingFlags())

    @Suppress("DEPRECATION")
    private fun signingFlags(): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        PackageManager.GET_SIGNING_CERTIFICATES
    } else {
        PackageManager.GET_SIGNATURES
    }

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        info.longVersionCode
    } else {
        info.versionCode.toLong()
    }

    @Suppress("DEPRECATION")
    private fun sameCurrentSigners(installed: PackageInfo, archive: PackageInfo): Boolean {
        val installedSigners = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            installed.signingInfo?.apkContentsSigners
        } else {
            installed.signatures
        }
        val archiveSigners = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            archive.signingInfo?.apkContentsSigners
        } else {
            archive.signatures
        }
        return !installedSigners.isNullOrEmpty() && !archiveSigners.isNullOrEmpty() &&
            installedSigners.size == archiveSigners.size &&
            installedSigners.all { signer -> archiveSigners.contains(signer) }
    }

    private fun fail(result: MethodChannel.Result, error: Exception) {
        val code = if (error is InstallException) error.code else "install_failed"
        mainHandler.post { result.error(code, error.message ?: "The Android update operation failed.", null) }
    }

    private class InstallException(val code: String, message: String) : Exception(message)
}
