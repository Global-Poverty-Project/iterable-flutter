import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_config/flutter_config.dart';
import 'package:iterable_flutter/iterable_flutter.dart';
import 'package:iterable_flutter_example/second_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required by FlutterConfig
  await FlutterConfig.loadEnvVariables();

  runApp(MaterialApp(
    title: "App",
    home: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initIterable();
    listener();
  }

  Future<void> initIterable() async {
    final apiKey = FlutterConfig.get('ITERABLE_API_KEY');
    final pushIntegrationName = Platform.isAndroid
        ? FlutterConfig.get('ITERABLE_PUSH_INTEGRATION_NAME_ANDROID')
        : FlutterConfig.get('ITERABLE_PUSH_INTEGRATION_NAME_IOS');

    return await IterableFlutter.instance.initialize(
      apiKey: apiKey,
      pushIntegrationName: pushIntegrationName,
    );
  }

  /// Don't set an email and user ID in the same session.
  /// Doing so causes the SDK to treat them as different users.
  Future<void> setEmail(String email) async {
    await IterableFlutter.instance.setEmail(email);
  }

  /// Don't set an email and user ID in the same session.
  /// Doing so causes the SDK to treat them as different users.
  Future<void> setUserId(String userId) async {
    await IterableFlutter.instance.setUserId(userId);
  }

  Future<void> track(String event) async {
    await IterableFlutter.instance.track(event);
  }

  Future<void> signOut() async {
    await IterableFlutter.instance.signOut();
  }

  /// Call it to register device for current user if calling setEmail or
  /// setUserId after the app has already launched
  /// (for example, when a new user logs in)
  Future<void> registerForPush() async {
    await IterableFlutter.instance.registerForPush();
  }

  Future<void> updateUser(Map<String, dynamic> userInfo) async {
    await IterableFlutter.instance.updateUser(params: userInfo);
  }

  Map<dynamic, dynamic> pushData = {};

  void listener() {
    IterableFlutter.instance.setIterableActionHandler((openedResult) {
      setPushData(openedResult);
    });
  }

  void setPushData(Map<dynamic, dynamic> newData) {
    setState(() {
      pushData = newData;
    });
    var data = pushData['additionalData'];
    if (data?['type'] == 'test') {
      navigationToSecondPage(data?['name']);
    }
  }

  void navigationToSecondPage(String name) {
    Navigator.push(
        context, MaterialPageRoute(builder: (context) => SecondPage(name)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Iterable Example App'),
      ),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 48, right: 96),
              child: TextFormField(
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (value) {
                  setEmail(value);
                  track('event_tracking_ios');
                },
                decoration: InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'Email:',
                ),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.only(left: 48, right: 96),
              child: TextFormField(
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (value) {
                  updateUser({'firstName': value});
                },
                decoration: InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: 'First Name:',
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                signOut();
              },
              child: Text('Sign Out'),
            ),
            SizedBox(height: 20),
            Text("Push: $pushData"),
            Text("Body: ${pushData['body']}"),
            Text("Title: ${pushData['title']}"),
            Text("Type: ${pushData['additionalData']?['type']}"),
            Text("name: ${pushData['additionalData']?['name']}"),
            SizedBox(
              height: 20,
            ),
            ElevatedButton(
                onPressed: () {
                  navigationToSecondPage(pushData['additionalData']?['name']);
                },
                child: Text('Button'))
          ],
        ),
      ),
    );
  }
}
