package de.ffuf.in_app_update

import android.app.Activity
import android.app.Activity.RESULT_OK
import android.app.Application
import android.content.Intent
import android.os.Bundle
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.PluginRegistry.Registrar

class InAppUpdatePlugin(private val activity: Activity) : MethodCallHandler,
    PluginRegistry.ActivityResultListener, Application.ActivityLifecycleCallbacks {

    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), "in_app_update")
            val instance = InAppUpdatePlugin(registrar.activity())
            registrar.addActivityResultListener(instance)
            registrar.activity().application.registerActivityLifecycleCallbacks(instance)
            channel.setMethodCallHandler(instance)
        }

        private const val REQUEST_CODE_START_UPDATE = 1388276
    }

    private var updateResult: Result? = null
    private var appUpdateInfo: AppUpdateInfo? = null

    // Creates instance of the manager.
    private val appUpdateManager by lazy {
        AppUpdateManagerFactory.create(activity)
    }


    override fun onMethodCall(call: MethodCall, result: Result) {
        when {
            call.method == "checkForUpdate" -> checkForUpdate(result)
            call.method == "performImmediateUpdate" -> performImmediateUpdate(result)
            call.method == "startFlexibleUpdate" -> startFlexibleUpdate(result)
            call.method == "completeFlexibleUpdate" -> completeFlexibleUpdate(result)
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_CODE_START_UPDATE) {
            requireNotNull(updateResult) {
                "Fix your code!"
            }
            if (resultCode != RESULT_OK) {
                updateResult?.error("Update failed", resultCode.toString(), null)
            } else {
                updateResult?.success(null)
            }
            return true
        }
        return false
    }

    override fun onActivityCreated(activity: Activity?, savedInstanceState: Bundle?) {}

    override fun onActivityPaused(activity: Activity?) {}

    override fun onActivityStarted(activity: Activity?) {}

    override fun onActivityDestroyed(activity: Activity?) {}

    override fun onActivitySaveInstanceState(activity: Activity?, outState: Bundle?) {}

    override fun onActivityStopped(activity: Activity?) {}

    override fun onActivityResumed(activity: Activity?) {
        appUpdateManager
            .appUpdateInfo
            .addOnSuccessListener { appUpdateInfo ->
                if (appUpdateInfo.updateAvailability()
                    == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                ) {
                    appUpdateManager.startUpdateFlowForResult(
                        appUpdateInfo,
                        AppUpdateType.IMMEDIATE,
                        activity,
                        REQUEST_CODE_START_UPDATE
                    )
                }
            }
    }

    private fun performImmediateUpdate(result: Result) {
        requireNotNull(appUpdateInfo) {
            result.error("Call checkForUpdate first!", null, null)
        }

        updateResult = result
        appUpdateManager.startUpdateFlowForResult(
            appUpdateInfo,
            AppUpdateType.IMMEDIATE,
            activity,
            REQUEST_CODE_START_UPDATE
        )
    }

    private fun startFlexibleUpdate(result: Result) {
        requireNotNull(appUpdateInfo) {
            result.error("Call checkForUpdate first!", null, null)
        }

        updateResult = result
        appUpdateManager.startUpdateFlowForResult(
            appUpdateInfo,
            AppUpdateType.FLEXIBLE,
            activity,
            REQUEST_CODE_START_UPDATE
        )
        appUpdateManager.registerListener { state ->
            if (state.installStatus() == InstallStatus.DOWNLOADED) {
                result.success(null)
            } else if (state.installErrorCode() != null) {
                result.error("Error during installation", state.installErrorCode().toString(), null)
            }
        }
    }

    private fun completeFlexibleUpdate(result: Result) {
        requireNotNull(appUpdateInfo) {
            result.error("Call checkForUpdate first!", null, null)
        }

        appUpdateManager.completeUpdate()
    }

    private fun checkForUpdate(result: Result) {

        // Returns an intent object that you use to check for an update.
        val appUpdateInfoTask = appUpdateManager.appUpdateInfo

        // Checks that the platform will allow the specified type of update.
        appUpdateInfoTask.addOnSuccessListener { info ->
            appUpdateInfo = info
            if (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE) {
                result.success(
                    mapOf(
                        "updateAvailable" to true,
                        "immediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                        "flexibleAllowed" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)
                    )
                )
            } else {
                result.success(
                    mapOf(
                        "updateAvailable" to false,
                        "immediateAllowed" to false,
                        "flexibleAllowed" to false
                    )
                )
            }
        }
        appUpdateInfoTask.addOnFailureListener {
            result.error(it.message, null, null)
        }
    }
}
