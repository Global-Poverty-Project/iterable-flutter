import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iterable_flutter/iterable_flutter.dart';

import 'factories/push_notification_metadata_factories.dart';

void main() {
  final calledMethod = <MethodCall>[];

  const MethodChannel channel = MethodChannel('iterable_flutter');
  const String apiKey = 'apiKey';
  const String pushIntegrationName = 'pushIntegrationName';
  const String activeLogDebug = 'activeLogDebug';
  const String email = 'my@email.com';
  const String userId = '11111';
  const String event = 'my_event';

  const contentBody = {'testKey': "Test body push"};
  const keyBody = "additionalData";

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      calledMethod.add(methodCall);

      switch (methodCall.method) {
        case 'init':
          return null;
        case 'setEmail':
          return null;
        case 'setUserId':
          return null;
        case 'track':
          return null;
        case 'registerForPush':
          return null;
        case 'signOut':
          return null;
        case 'checkRecentNotification':
          return null;
        case 'updateUser':
          return null;
        case 'showMobileInbox':
          return null;
        case 'getUnreadInboxMessagesCount':
          return 1;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    calledMethod.clear();
    channel.setMockMethodCallHandler(null);
  });

  test('initialize', () async {
    await IterableFlutter.instance.initialize(
      apiKey: apiKey,
      pushIntegrationName: pushIntegrationName,
    );
    expect(calledMethod, <Matcher>[
      isMethodCall(
        'initialize',
        arguments: {
          apiKey: apiKey,
          pushIntegrationName: pushIntegrationName,
          activeLogDebug: false,
          'allowedProtocols': ['https'],
          'authEnabled': false,
          'autoPushRegistration': true,
        },
      ),
    ]);
  });

  test('setEmail', () async {
    await IterableFlutter.instance.setEmail(email);
    expect(calledMethod, <Matcher>[
      isMethodCall('setEmail', arguments: email),
    ]);
  });

  test('setUserId', () async {
    await IterableFlutter.instance.setUserId(userId);
    expect(calledMethod, <Matcher>[
      isMethodCall('setUserId', arguments: userId),
    ]);
  });

  test('track', () async {
    await IterableFlutter.instance.track(event);
    expect(calledMethod, <Matcher>[
      isMethodCall('track', arguments: event),
    ]);
  });

  test('registerForPush', () async {
    await IterableFlutter.instance.registerForPush();
    expect(calledMethod, <Matcher>[
      isMethodCall('registerForPush', arguments: null),
    ]);
  });

  test('signOut', () async {
    await IterableFlutter.instance.signOut();
    expect(calledMethod, <Matcher>[
      isMethodCall('signOut', arguments: null),
    ]);
  });

  test('checkRecentNotification', () async {
    await IterableFlutter.instance.checkRecentNotification();
    expect(calledMethod, <Matcher>[
      isMethodCall('checkRecentNotification', arguments: null),
    ]);
  });

  test("actionHandler", () async {
    IterableFlutter.instance.initialize(
      apiKey: apiKey,
      pushIntegrationName: pushIntegrationName,
    );

    dynamic pushData;

    IterableFlutter.instance.setIterableActionHandler((openedResultMap) {
      pushData = openedResultMap;
    });

    await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'iterable_flutter',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(
            'actionHandler',
            {
              keyBody: contentBody,
              'itbl': {
                'defaultAction': {'type': 'openApp'},
              },
            },
          ),
        ),
        (ByteData? data) {});

    expect(contentBody, pushData[keyBody]);
  });

  test("actionHandler sent while initialize is in flight is delivered", () async {
    // Cold start: the native SDK replays a queued universal link as soon as
    // initialize completes, before the Dart await resumes.
    dynamic openedResult;
    IterableFlutter.instance.setIterableActionHandler((openedResultMap) {
      openedResult = openedResultMap;
    });
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'initialize') {
        await ServicesBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'iterable_flutter',
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('actionHandler', {
              'source': 'universalLink',
              'itbl': {
                'defaultAction': {'type': 'openUrl', 'data': 'https://gc.org/x'},
              },
            }),
          ),
          (ByteData? data) {},
        );
      }
      return null;
    });

    await IterableFlutter.instance.initialize(
      apiKey: apiKey,
      pushIntegrationName: pushIntegrationName,
    );

    expect(openedResult, isNotNull);
    expect(openedResult['source'], 'universalLink');
  });

  test('updateUser', () async {
    await IterableFlutter.instance.updateUser(params: {});
    expect(calledMethod, <Matcher>[
      isMethodCall('updateUser', arguments: {"params": {}}),
    ]);
  });
  test('showMobileInbox', () async {
    await IterableFlutter.instance.showMobileInbox(
        screenTitle: "Inbox",
        noMessagesTitle: "No messages",
        noMessagesBody: "Check later");
    expect(calledMethod, <Matcher>[
      isMethodCall('showMobileInbox', arguments: {
        "screenTitle": "Inbox",
        "noMessagesTitle": "No messages",
        "noMessagesBody": "Check later",
      }),
    ]);
  });

  test('getUnreadInboxMessagesCount', () async {
    final count = await IterableFlutter.instance.getUnreadInboxMessagesCount();
    expect(calledMethod, <Matcher>[
      isMethodCall('getUnreadInboxMessagesCount', arguments: null),
    ]);
    assert(count == 1);
  });

  group('inbox', () {
    const messageId = 'message-1';

    void mockResult(Object? value) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        calledMethod.add(methodCall);
        return value;
      });
    }

    test('showInboxMessage returns the native result', () async {
      mockResult(true);
      final shown = await IterableFlutter.instance
          .showInboxMessage(messageId: messageId);
      expect(shown, isTrue);
      expect(calledMethod, <Matcher>[
        isMethodCall('showInboxMessage', arguments: {'messageId': messageId}),
      ]);
    });

    test('showInboxMessage returns false when not shown', () async {
      mockResult(false);
      final shown = await IterableFlutter.instance
          .showInboxMessage(messageId: messageId);
      expect(shown, isFalse);
    });

    test('markInboxMessageRead returns the native result', () async {
      mockResult(true);
      final marked = await IterableFlutter.instance
          .markInboxMessageRead(messageId: messageId);
      expect(marked, isTrue);
      expect(calledMethod, <Matcher>[
        isMethodCall(
          'markInboxMessageRead',
          arguments: {'messageId': messageId},
        ),
      ]);
    });

    test('markInboxMessageRead returns false when native returns null',
        () async {
      mockResult(null);
      final marked = await IterableFlutter.instance
          .markInboxMessageRead(messageId: messageId);
      expect(marked, isFalse);
    });

    test('deleteInboxMessage returns false on failure', () async {
      mockResult(false);
      final deleted = await IterableFlutter.instance
          .deleteInboxMessage(messageId: messageId);
      expect(deleted, isFalse);
      expect(calledMethod, <Matcher>[
        isMethodCall('deleteInboxMessage', arguments: {'messageId': messageId}),
      ]);
    });

    test('session methods call the native side', () async {
      await IterableFlutter.instance.startInboxSession();
      await IterableFlutter.instance
          .updateVisibleInboxMessages(['message-1', 'message-2']);
      await IterableFlutter.instance.endInboxSession();
      expect(calledMethod, <Matcher>[
        isMethodCall('startInboxSession', arguments: null),
        isMethodCall(
          'updateVisibleInboxMessages',
          arguments: {
            'messageIds': ['message-1', 'message-2'],
          },
        ),
        isMethodCall('endInboxSession', arguments: null),
      ]);
    });

    test('inboxChanges emits when native sends inboxChanged', () async {
      await IterableFlutter.instance.initialize(
        apiKey: apiKey,
        pushIntegrationName: pushIntegrationName,
      );
      final events = <void>[];
      final subscription =
          IterableFlutter.instance.inboxChanges.listen(events.add);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'iterable_flutter',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('inboxChanged')),
        (ByteData? data) {},
      );
      await pumpEventQueue();

      expect(events, hasLength(1));
      await subscription.cancel();
    });
  });

  group('.sanitizeMap', () {
    group('when metadata comes from Android', () {
      test('should parse the itbl JSON string', () {
        final result = IterableFlutter.instance
            .sanitizeArguments(buildPushNotificationMetadataAndroid());

        expect(result['source'], 'push');
        expect(result['itbl']['isGhostPush'] as bool, isFalse);
        expect(result['itbl']['defaultAction']['type'], 'openApp');
      });
    });

    group('when metadata comes from iOS', () {
      group('when payload arrives clean', () {
        test('should keep the itbl map', () {
          final result = IterableFlutter.instance
              .sanitizeArguments(buildPushNotificationMetadataIOS());

          expect(result['source'], 'push');
          expect(result['itbl']['isGhostPush'] as bool, isFalse);
          expect(result['itbl']['defaultAction']['type'], 'openApp');
        });
      });

      group('when payload does not arrives clean', () {
        test('should decode &quot; and parse the itbl JSON string', () {
          final result = IterableFlutter.instance
              .sanitizeArguments(buildPushNotificationMetadataIOSWithQuot());

          expect(result['itbl']['isGhostPush'] as bool, isFalse);
          expect(result['itbl']['defaultAction']['type'], 'openApp');
        });
      });
    });
  });
}
