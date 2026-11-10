import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:iterable_flutter/iterable_in_app_message_preview.dart';

typedef IterableActionHandler = void Function(
    Map<String, dynamic> openedResult);

/// Supplies a fresh JWT for the SDK's current user ID or email.
/// Return null when that user is no longer signed in. Never log the token.
typedef IterableAuthHandler = Future<String?> Function(String userKey);
typedef IterableAuthFailureHandler = void Function(String reason);

// ignore: avoid_classes_with_only_static_members
class IterableFlutter {
  static const MethodChannel _channel = MethodChannel('iterable_flutter');

  static IterableActionHandler? _actionHandler;
  static IterableAuthHandler? _authHandler;
  static IterableAuthFailureHandler? _authFailureHandler;
  static String? _userKey;
  static Object? _identity;

  static final StreamController<void> _inboxChangesController =
      StreamController<void>.broadcast();

  const IterableFlutter._();
  static IterableFlutter? _singleton;
  static IterableFlutter get instance {
    _singleton ??= IterableFlutter._();
    return _singleton!;
  }

  Future<void> initialize({
    required String apiKey,
    required String pushIntegrationName,
    bool activeLogDebug = false,
    List<String> allowedProtocols = const ['https'],
    IterableAuthHandler? authHandler,
    IterableAuthFailureHandler? onAuthFailure,
    bool autoPushRegistration = true,
  }) async {
    _authHandler = authHandler;
    _authFailureHandler = onAuthFailure;
    _userKey = null;
    _identity = null;
    // Registered first: a link queued during a cold start is replayed by the
    // native SDK as soon as initialize completes.
    _channel.setMethodCallHandler(_nativeMethodCallHandler);
    await _channel.invokeMethod(
      'initialize',
      {
        'apiKey': apiKey,
        'pushIntegrationName': pushIntegrationName,
        'activeLogDebug': activeLogDebug,
        'allowedProtocols': allowedProtocols,
        'authEnabled': authHandler != null,
        'autoPushRegistration': autoPushRegistration,
      },
    );
  }

  Future<void> setEmail(String email) async {
    _userKey = email;
    _identity = Object();
    await _channel.invokeMethod('setEmail', email);
  }

  Future<void> setUserId(String userId) async {
    _userKey = userId;
    _identity = Object();
    await _channel.invokeMethod('setUserId', userId);
  }

  Future<void> track(String event) async {
    await _channel.invokeMethod('track', event);
  }

  Future<void> registerForPush() async {
    await _channel.invokeMethod('registerForPush');
  }

  Future<void> signOut() async {
    _userKey = null;
    _identity = null;
    await _channel.invokeMethod('signOut');
  }

  Future<void> checkRecentNotification() async {
    await _channel.invokeMethod('checkRecentNotification');
  }

  Future<void> updateUser({required Map<String, dynamic> params}) async {
    await _channel.invokeMethod(
      'updateUser',
      {
        'params': params,
      },
    );
  }

  Future<void> showMobileInbox({
    String? screenTitle,
    String? noMessagesTitle,
    String? noMessagesBody,
  }) async {
    await _channel.invokeMethod(
      'showMobileInbox',
      {
        'screenTitle': screenTitle,
        'noMessagesTitle': noMessagesTitle,
        'noMessagesBody': noMessagesBody,
      },
    );
  }

  Future<int?> getUnreadInboxMessagesCount() {
    return _channel.invokeMethod<int>('getUnreadInboxMessagesCount');
  }

  Future<List<IterableInAppMessagePreview?>?> getInboxMessages() async {
    final jsonMessages =
        await _channel.invokeMethod<List<dynamic>>('getInboxMessages');

    final messages = jsonMessages?.map((e) {
      try {
        return IterableInAppMessagePreview.fromJson(json.decode(e.toString()));
      } catch (e) {
        return null;
      }
    }).toList();

    return messages;
  }

  Future<bool> showInboxMessage({required String messageId}) async {
    final result = await _channel.invokeMethod(
      'showInboxMessage',
      {
        'messageId': messageId,
      },
    );

    return result;
  }

  Future<void> setRead({required String messageId}) async {
    await _channel.invokeMethod(
      'setRead',
      {
        'messageId': messageId,
      },
    );
  }

  Future<bool> markInboxMessageRead({required String messageId}) async {
    final result = await _channel.invokeMethod<bool>(
      'markInboxMessageRead',
      {
        'messageId': messageId,
      },
    );

    return result ?? false;
  }

  Future<bool> deleteInboxMessage({required String messageId}) async {
    final result = await _channel.invokeMethod(
      'deleteInboxMessage',
      {
        'messageId': messageId,
      },
    );

    return result;
  }

  Future<void> startInboxSession() async {
    await _channel.invokeMethod('startInboxSession');
  }

  Future<void> endInboxSession() async {
    await _channel.invokeMethod('endInboxSession');
  }

  Future<void> updateVisibleInboxMessages(List<String> messageIds) async {
    await _channel.invokeMethod(
      'updateVisibleInboxMessages',
      {
        'messageIds': messageIds,
      },
    );
  }

  Stream<void> get inboxChanges => _inboxChangesController.stream;

  // ignore: use_setters_to_change_properties
  void setIterableActionHandler(IterableActionHandler handler) {
    _actionHandler = handler;
  }

  Future<dynamic> _nativeMethodCallHandler(MethodCall methodCall) async {
    if (methodCall.method == 'authTokenRequested') {
      final userKey = methodCall.arguments as String?;
      final identity = _identity;
      if (userKey == null || userKey != _userKey || identity == null) {
        return null;
      }
      try {
        final token = await _authHandler?.call(userKey);
        // A native refresh can finish after logout or an account switch.
        return identical(identity, _identity) ? token : null;
      } catch (_) {
        // Platform-channel error envelopes otherwise include exception text.
        _authFailureHandler?.call('tokenRequestFailed');
        return null;
      }
    }
    if (methodCall.method == 'authFailure') {
      _authFailureHandler?.call(methodCall.arguments as String);
      return;
    }
    if (methodCall.method == 'inboxChanged') {
      _inboxChangesController.add(null);
      return;
    }

    final arguments = methodCall.arguments as Map<dynamic, dynamic>;
    final argumentsCleaned = sanitizeArguments(arguments);

    switch (methodCall.method) {
      case "actionHandler":
        _actionHandler?.call(argumentsCleaned);
        return;
      default:
        return;
    }
  }

  @visibleForTesting
  Map<String, dynamic> sanitizeArguments(Map<dynamic, dynamic> arguments) {
    final result = arguments;

    final data = (result['itbl'] is String)
        ? _stringJsonToMap(result['itbl'])
        : result['itbl'];
    data.forEach((key, value) {
      if (value is String) {
        if (value.isNotEmpty && [0] == '{' && value[value.length - 1] == '}') {
          data[key] = _stringJsonToMap(value);
        }
      }
    });
    result['itbl'] = data;

    return Map<String, dynamic>.from(result);
  }

  Map<dynamic, dynamic> _stringJsonToMap(String stringJson) {
    final stringClean = stringJson.replaceAll('&quot;', '"');

    return jsonDecode(stringClean) as Map<dynamic, dynamic>;
  }
}
