package com.lahaus.iterable_flutter

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import com.iterable.iterableapi.IterableActionSource
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class PushNotificationForegroundTest {
    private val application = RuntimeEnvironment.getApplication()
    private val packageManager = application.packageManager

    @Test
    fun pushResolvesCurrentIconAliasAndKeepsTask() {
        val defaultAlias = addLauncher("DefaultIconAlias")
        val alternateAlias = addLauncher("GoldAppIconAlias")
        setEnabled(alternateAlias, false)

        foregroundAppForPushAction(application, IterableActionSource.PUSH)
        val first = shadowOf(application).nextStartedActivity
        assertEquals(defaultAlias, first.component)
        assertSafeLaunch(first)
        assertNull(shadowOf(application).nextStartedActivity)

        setEnabled(alternateAlias, true)
        setEnabled(defaultAlias, false)
        foregroundAppForPushAction(application, IterableActionSource.PUSH)
        val second = shadowOf(application).nextStartedActivity
        assertEquals(alternateAlias, second.component)
        assertSafeLaunch(second)
        assertNull(shadowOf(application).nextStartedActivity)
        assertEquals(PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            packageManager.getComponentEnabledSetting(defaultAlias))
        assertEquals(PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            packageManager.getComponentEnabledSetting(alternateAlias))
    }

    @Test
    fun nonPushActionsDoNotLaunchApp() {
        addLauncher("DefaultIconAlias")
        for (source in IterableActionSource.values().filter { it != IterableActionSource.PUSH }) {
            foregroundAppForPushAction(application, source)
        }
        assertNull(shadowOf(application).nextStartedActivity)
    }

    @Test
    fun missingContextOrLauncherDoesNotLaunchApp() {
        foregroundAppForPushAction(null, IterableActionSource.PUSH)
        foregroundAppForPushAction(application, IterableActionSource.PUSH)
        assertNull(shadowOf(application).nextStartedActivity)
    }

    @Test
    fun unavailableLauncherDoesNotInterruptActionHandling() {
        addLauncher("DefaultIconAlias")
        val unavailableContext = object : ContextWrapper(application) {
            override fun startActivity(intent: Intent) {
                throw ActivityNotFoundException()
            }
        }
        foregroundAppForPushAction(unavailableContext, IterableActionSource.PUSH)
    }

    private fun addLauncher(name: String): ComponentName {
        val component = ComponentName(application.packageName, "${application.packageName}.$name")
        shadowOf(packageManager).addActivityIfNotPresent(component).apply {
            targetActivity = "${application.packageName}.LauncherActivity"
            enabled = true
            exported = true
        }
        shadowOf(packageManager).addIntentFilterForActivity(component,
            IntentFilter(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_LAUNCHER) })
        return component
    }

    private fun setEnabled(component: ComponentName, enabled: Boolean) {
        packageManager.setComponentEnabledSetting(component,
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP)
    }

    private fun assertSafeLaunch(intent: Intent) {
        assertEquals(Intent.ACTION_MAIN, intent.action)
        assertTrue(intent.hasCategory(Intent.CATEGORY_LAUNCHER))
        assertTrue(intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK != 0)
        assertEquals(0, intent.flags and (Intent.FLAG_ACTIVITY_CLEAR_TASK or
            Intent.FLAG_ACTIVITY_MULTIPLE_TASK or Intent.FLAG_ACTIVITY_NEW_DOCUMENT))
        assertNull(intent.data)
        assertNull(intent.extras)
    }
}
