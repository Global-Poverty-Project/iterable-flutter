package com.lahaus.iterable_flutter

import com.iterable.iterableapi.IterableFirebaseMessagingService

/** The SDK's token-refresh handler registers even when auto registration is off. */
class IterableFlutterMessagingService : IterableFirebaseMessagingService() {
    override fun onNewToken(token: String) {
        if (getSharedPreferences("iterable_flutter", MODE_PRIVATE)
                .getBoolean("autoPushRegistration", true)) {
            super.onNewToken(token)
        }
    }
}
