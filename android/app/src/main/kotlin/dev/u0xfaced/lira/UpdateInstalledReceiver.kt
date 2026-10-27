package dev.u0xfaced.lira

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class UpdateInstalledReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val pendingResult = goAsync()
        AppUpdateInstaller.onPackageReplaced(context) { pendingResult.finish() }
    }
}
