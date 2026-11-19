import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iterable_flutter/iterable_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('iterable_flutter');
  const codec = StandardMethodCodec();
  final sdk = IterableFlutter.instance;

  Future<dynamic> nativeCall(String method, dynamic arguments) async {
    final result = Completer<ByteData?>();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(MethodCall(method, arguments)),
          result.complete,
        );
    return codec.decodeEnvelope((await result.future)!);
  }

  Future<void> initialize(IterableAuthHandler handler) => sdk.initialize(
    apiKey: 'test-mobile-key',
    pushIntegrationName: 'test-app',
    authHandler: handler,
    autoPushRegistration: false,
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });
  tearDown(() async {
    await sdk.signOut();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('requests a fresh JWT for each native refresh', () async {
    var requests = 0;
    await initialize((userKey) async => '$userKey-jwt-${++requests}');
    await sdk.setUserId('user-a');
    expect(await nativeCall('authTokenRequested', 'user-a'), 'user-a-jwt-1');
    expect(await nativeCall('authTokenRequested', 'user-a'), 'user-a-jwt-2');
  });

  test('rejects a native request for a different identity', () async {
    await initialize((_) async => fail('Must not request another user JWT'));
    await sdk.setUserId('user-b');
    expect(await nativeCall('authTokenRequested', 'user-a'), isNull);
  });

  test('discards an in-flight JWT after logout and signing in again', () async {
    final token = Completer<String>();
    final requested = Completer<void>();
    await initialize((_) {
      requested.complete();
      return token.future;
    });
    await sdk.setUserId('user-a');
    final result = nativeCall('authTokenRequested', 'user-a');
    await requested.future;
    await sdk.signOut();
    await sdk.setUserId('user-a');
    token.complete('old-session-jwt');
    expect(await result, isNull);
  });

  test('does not send exception details over the native channel', () async {
    final failures = <String>[];
    await sdk.initialize(
      apiKey: 'test-mobile-key',
      pushIntegrationName: 'test-app',
      authHandler: (_) async => throw StateError('secret-jwt'),
      onAuthFailure: failures.add,
    );
    await sdk.setUserId('user-a');
    expect(await nativeCall('authTokenRequested', 'user-a'), isNull);
    expect(failures, ['tokenRequestFailed']);
  });
}
