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
          activeLogDebug: false
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
            {keyBody: contentBody},
          ),
        ),
        (ByteData? data) {});

    expect(contentBody, pushData[keyBody]);
  });

  test('updateUser', () async {
    await IterableFlutter.instance.updateUser(params: {});
    expect(calledMethod, <Matcher>[
      isMethodCall('updateUser', arguments: {"params": {}}),
    ]);
  });

  group('.sanitizeMap', () {
    group('when metadata comes from Android', () {
      test('should return a clear map', () {
        final additionalData = buildPushNotificationMetadataAndroid();

        final result =
            IterableFlutter.instance.sanitizeArguments(additionalData);

        expect(result['body'], 'test');
        expect(result['additionalData']['keyNumber'] as int, 1);
        expect(result['additionalData']['keyMap']['keyMap2'], 'value2');
        expect(
            result['additionalData']['keyMapChild']['keyMapChild3']
                ['keyMapChild32'],
            'value3');
        expect(
            result['additionalData']['itbl']['isGhostPush'] as bool, isFalse);
        expect(result['additionalData']['itbl']['defaultAction']['type'],
            'openApp');
      });
    });

    group('when metadata comes from iOS', () {
      group('when payload arrives clean', () {
        test('should return a clear map', () {
          final additionalData = buildPushNotificationMetadataIOS();

          final result =
              IterableFlutter.instance.sanitizeArguments(additionalData);

          expect(result['body'], 'test');
          expect(result['additionalData']['keyNumber'] as int, 1);
          expect(result['additionalData']['keyMap']['keyMap2'], 'value2');
          expect(
              result['additionalData']['keyMapChild']['keyMapChild3']
                  ['keyMapChild32'],
              'value3');
          expect(
              result['additionalData']['itbl']['isGhostPush'] as bool, isFalse);
          expect(result['additionalData']['itbl']['defaultAction']['type'],
              'openApp');
        });
      });

      group('when payload does not arrives clean', () {
        test('should return a clear map', () {
          final additionalData = buildPushNotificationMetadataIOSWithQuot();

          final result =
              IterableFlutter.instance.sanitizeArguments(additionalData);

          expect(result['body'], 'test');
          expect(result['additionalData']['keyNumber'] as int, 1);
          expect(result['additionalData']['keyMap']['keyMap2'], 'value2');
          expect(
              result['additionalData']['keyMapChild']['keyMapChild3']
                  ['keyMapChild32'],
              'value3');
          expect(
              result['additionalData']['itbl']['isGhostPush'] as bool, isFalse);
          expect(result['additionalData']['itbl']['defaultAction']['type'],
              'openApp');
        });
      });
    });
  });
}
