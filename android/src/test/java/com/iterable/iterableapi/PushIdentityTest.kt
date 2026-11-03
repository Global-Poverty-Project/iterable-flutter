package com.iterable.iterableapi

import com.lahaus.iterable_flutter.IterableFlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [34])
class PushIdentityTest {
    private lateinit var original: IterableApi
    private lateinit var sdk: RecordingApi
    private val plugin = IterableFlutterPlugin()
    private val result = object : MethodChannel.Result {
        override fun success(value: Any?) {}
        override fun error(code: String, message: String?, details: Any?) = fail(code)
        override fun notImplemented() = fail("unimplemented")
    }

    @Before fun setUp() {
        original = IterableApi.getInstance()
        sdk = RecordingApi()
        IterableApi.sharedInstance = sdk
    }

    @After fun tearDown() { IterableApi.sharedInstance = original }

    @Test fun logoutDisablesBeforeClearingEmailIdentity() {
        sdk.currentEmail = "a@example.com"
        plugin.onMethodCall(MethodCall("signOut", null), result)
        assertEquals(listOf("disable:a@example.com", "email:null"), sdk.calls)
        assertNull(sdk.email)
        assertNull(sdk.userId)
    }

    @Test fun logoutAlsoClearsUserIdIdentity() {
        sdk.currentUserId = "42"
        plugin.onMethodCall(MethodCall("signOut", null), result)
        assertEquals(listOf("disable:42", "email:null"), sdk.calls)
        assertNull(sdk.userId)
    }

    @Test fun signedOutRegistrationIsIgnored() {
        plugin.onMethodCall(MethodCall("registerForPush", null), result)
        assertTrue(sdk.calls.isEmpty())
    }

    @Test fun switchingAccountDisablesOutgoingIdentityBeforeSettingTheNext() {
        sdk.currentEmail = "a@example.com"
        plugin.onMethodCall(MethodCall("setEmail", "b@example.com"), result)
        assertEquals(listOf("disable:a@example.com", "email:null", "email:b@example.com"), sdk.calls)
        // Flutter explicitly registers once after identity is ready.
        plugin.onMethodCall(MethodCall("registerForPush", null), result)
        assertEquals("register:b@example.com", sdk.calls.last())
    }

    @Test fun refreshingSameIdentityDoesNotDisableIt() {
        sdk.currentEmail = "a@example.com"
        plugin.onMethodCall(MethodCall("setEmail", "a@example.com"), result)
        assertEquals(listOf("email:a@example.com"), sdk.calls)
    }

    private class RecordingApi : IterableApi() {
        var currentEmail: String? = null
        var currentUserId: String? = null
        val calls = mutableListOf<String>()
        override fun getEmail() = currentEmail
        override fun getUserId() = currentUserId
        override fun setEmail(value: String?) {
            calls += "email:$value"
            currentEmail = value
            currentUserId = null
        }
        override fun setUserId(value: String?) {
            calls += "id:$value"
            currentEmail = null
            currentUserId = value
        }
        override fun disablePush() { calls += "disable:${currentEmail ?: currentUserId}" }
        override fun registerForPush() { calls += "register:${currentEmail ?: currentUserId}" }
    }
}
