import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/rxdart.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
Future<SharedPreferences> sharedPrefs = SharedPreferences.getInstance();
var counterSubject = PublishSubject<int>();

/// IMPORTANT: running the following code on its own won't work as there is setup required for each platform head project.
/// Please download the complete example app from the GitHub repository where all the setup has been done
void main() async {
  flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();

  // NOTE: if you want to find out if the app was launched via notification then you could use the following call and then do something like
  // change the default route of the app
  // var notificationAppLaunchDetails =
  //     await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  runApp(
    new MaterialApp(
      home: HomePage(),
    ),
  );
}

Future onNotification(int id, String title, String body, String payload) async {
  print(
      'on notification callback triggered with id: $id, title: $title, body: $body, payload: $payload');
  // update a counter in shared preferences to track how many times a notification has been shown
  // this example app will only display the counter on a cold start of the app to demonstrate headless execution
  if (Platform.isAndroid) {
    // IMPORTANT: Flutter currently only supports executing headless Dart code that uses other plugins on Android
    var sharedPreferences = await sharedPrefs;
    var shown = (sharedPreferences.getInt('shownCounter') ?? 0) + 1;
    sharedPreferences.setInt('shownCounter', shown);

    // use to send updates that can be handled in the UI
    final SendPort send =
        IsolateNameServer.lookupPortByName('notification_shown_port');
    send?.send(shown);
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => new _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ReceivePort port = ReceivePort();

  @override
  initState() {
    super.initState();
    // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    var initializationSettingsAndroid =
        new AndroidInitializationSettings('app_icon');
    var initializationSettingsIOS = new IOSInitializationSettings();
    var initializationSettings = new InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification,
        onNotification: onNotification);
    sharedPrefs.then((sharedPreferences) {
      var counter = sharedPreferences.getInt('shownCounter') ?? 0;
      counterSubject.sink.add(counter);
    });

    IsolateNameServer.registerPortWithName(
        port.sendPort, 'notification_shown_port');
    port.listen((dynamic data) {
      counterSubject.sink.add(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('Plugin example app'),
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: new Padding(
            padding: new EdgeInsets.all(8.0),
            child: new Center(
              child: new Column(
                children: <Widget>[
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new Text(
                        'Tap on a notification when it appears to trigger navigation'),
                  ),
                  // NOTE: the following text is demonstrate headless execution with plugins work in Android
                  /*new Padding(
                      padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                      child: new FutureBuilder(
                        future: sharedPrefs,
                        builder:
                            (BuildContext context, AsyncSnapshot snapshot) {
                          if (snapshot.hasData) {
                            SharedPreferences sharedPreferences = snapshot.data;
                            var counter =
                                sharedPreferences.getInt('shownCounter') ?? 0;
                            return new Text(
                                'Shown ${counter.toString()} Android notifications since the last cold start');
                          } else {
                            return CircularProgressIndicator();
                          }
                        },
                      )),*/
                  new Padding(
                      padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                      child: new StreamBuilder(
                        initialData: 0,
                        stream: counterSubject.stream,
                        builder: (BuildContext context,
                            AsyncSnapshot<int> snapshot) {
                          return new Text(
                              'Shown ${snapshot.data} Android notifications since the last cold start');
                        },
                      )),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text('Show plain notification with payload'),
                      onPressed: () async {
                        await _showNotification();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text('Cancel notification'),
                      onPressed: () async {
                        await _cancelNotification();
                      },
                    ),
                  ),
                  new Padding(
                      padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                      child: new RaisedButton(
                          child: new Text(
                              'Schedule notification to appear in 5 seconds, custom sound, red colour, large icon'),
                          onPressed: () async {
                            await _scheduleNotification();
                          })),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text('Repeat notification every minute'),
                      onPressed: () async {
                        await _repeatNotification();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text(
                          'Repeat notification every day at approximately 10:00:00 am'),
                      onPressed: () async {
                        await _showDailyAtTime();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text(
                          'Repeat notification weekly on Monday at approximately 10:00:00 am'),
                      onPressed: () async {
                        await _showWeeklyAtDayAndTime();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text('Show notification with no sound'),
                      onPressed: () async {
                        await _showNotificationWithNoSound();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child:
                          new Text('Show big picture notification [Android]'),
                      onPressed: () async {
                        await _showBigPictureNotification();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text('Show big text notification [Android]'),
                      onPressed: () async {
                        await _showBigTextNotification();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text('Show inbox notification [Android]'),
                      onPressed: () async {
                        await _showInboxNotification();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text('Show grouped notifications [Android]'),
                      onPressed: () async {
                        await _showGroupedNotifications();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text('Show ongoing notification [Android]'),
                      onPressed: () async {
                        await _showOngoingNotification();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text(
                          'Show notification with no badge, alert only once [Android]'),
                      onPressed: () async {
                        await _showNotificationWithNoBadge();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text(
                          'Show progress notification - updates every second [Android]'),
                      onPressed: () async {
                        await _showProgressNotification();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text(
                          'Show indeterminate progress notification [Android]'),
                      onPressed: () async {
                        await _showIndeterminateProgressNotification();
                      },
                    ),
                  ),
                  new Padding(
                    padding: new EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 8.0),
                    child: new RaisedButton(
                      child: new Text('cancel all notifications'),
                      onPressed: () async {
                        await _cancelAllNotifications();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future _showNotification() async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'your channel id', 'your channel name', 'your channel description',
        importance: Importance.Max, priority: Priority.High);
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0, 'plain title', 'plain body', platformChannelSpecifics,
        payload: 'item x');
  }

  Future _cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancel(0);
  }

  /// Schedules a notification that specifies a different icon, sound and vibration pattern
  Future _scheduleNotification() async {
    var scheduledNotificationDateTime =
        new DateTime.now().add(new Duration(seconds: 5));
    var vibrationPattern = new Int64List(4);
    vibrationPattern[0] = 0;
    vibrationPattern[1] = 1000;
    vibrationPattern[2] = 5000;
    vibrationPattern[3] = 2000;

    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'your other channel id',
        'your other channel name',
        'your other channel description',
        icon: 'secondary_icon',
        sound: 'slow_spring_board',
        largeIcon: 'sample_large_icon',
        largeIconBitmapSource: BitmapSource.Drawable,
        vibrationPattern: vibrationPattern,
        color: const Color.fromARGB(255, 255, 0, 0));
    var iOSPlatformChannelSpecifics =
        new IOSNotificationDetails(sound: "slow_spring_board.aiff");
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.schedule(
        0,
        'scheduled title',
        'scheduled body',
        scheduledNotificationDateTime,
        platformChannelSpecifics);
  }

  Future _showNotificationWithNoSound() async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'silent channel id',
        'silent channel name',
        'silent channel description',
        playSound: false,
        styleInformation: new DefaultStyleInformation(true, true));
    var iOSPlatformChannelSpecifics =
        new IOSNotificationDetails(presentSound: false);
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, '<b>silent</b> title',
        '<b>silent</b> body', platformChannelSpecifics);
  }

  Future _showBigPictureNotification() async {
    var directory = await getApplicationDocumentsDirectory();
    var largeIconResponse = await http.get('http://via.placeholder.com/48x48');
    var largeIconPath = '${directory.path}/largeIcon';
    var file = new File(largeIconPath);
    await file.writeAsBytes(largeIconResponse.bodyBytes);
    var bigPictureResponse =
        await http.get('http://via.placeholder.com/400x800');
    var bigPicturePath = '${directory.path}/bigPicture';
    file = new File(bigPicturePath);
    await file.writeAsBytes(bigPictureResponse.bodyBytes);
    var bigPictureStyleInformation = new BigPictureStyleInformation(
        bigPicturePath, BitmapSource.FilePath,
        largeIcon: largeIconPath,
        largeIconBitmapSource: BitmapSource.FilePath,
        contentTitle: 'overridden <b>big</b> content title',
        htmlFormatContentTitle: true,
        summaryText: 'summary <i>text</i>',
        htmlFormatSummaryText: true);
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'big text channel id',
        'big text channel name',
        'big text channel description',
        style: AndroidNotificationStyle.BigPicture,
        styleInformation: bigPictureStyleInformation);
    var platformChannelSpecifics =
        new NotificationDetails(androidPlatformChannelSpecifics, null);
    await flutterLocalNotificationsPlugin.show(
        0, 'big text title', 'silent body', platformChannelSpecifics);
  }

  Future _showBigTextNotification() async {
    var bigTextStyleInformation = new BigTextStyleInformation(
        'Lorem <i>ipsum dolor sit</i> amet, consectetur <b>adipiscing elit</b>, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
        htmlFormatBigText: true,
        contentTitle: 'overridden <b>big</b> content title',
        htmlFormatContentTitle: true,
        summaryText: 'summary <i>text</i>',
        htmlFormatSummaryText: true);
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'big text channel id',
        'big text channel name',
        'big text channel description',
        style: AndroidNotificationStyle.BigText,
        styleInformation: bigTextStyleInformation);
    var platformChannelSpecifics =
        new NotificationDetails(androidPlatformChannelSpecifics, null);
    await flutterLocalNotificationsPlugin.show(
        0, 'big text title', 'silent body', platformChannelSpecifics);
  }

  Future _showInboxNotification() async {
    var lines = new List<String>();
    lines.add('line <b>1</b>');
    lines.add('line <i>2</i>');
    var inboxStyleInformation = new InboxStyleInformation(lines,
        htmlFormatLines: true,
        contentTitle: 'overridden <b>inbox</b> context title',
        htmlFormatContentTitle: true,
        summaryText: 'summary <i>text</i>',
        htmlFormatSummaryText: true);
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'inbox channel id', 'inboxchannel name', 'inbox channel description',
        style: AndroidNotificationStyle.Inbox,
        styleInformation: inboxStyleInformation);
    var platformChannelSpecifics =
        new NotificationDetails(androidPlatformChannelSpecifics, null);
    await flutterLocalNotificationsPlugin.show(
        0, 'inbox title', 'inbox body', platformChannelSpecifics);
  }

  Future _showGroupedNotifications() async {
    var groupKey = 'com.android.example.WORK_EMAIL';
    var groupChannelId = 'grouped channel id';
    var groupChannelName = 'grouped channel name';
    var groupChannelDescription = 'grouped channel description';
    // example based on https://developer.android.com/training/notify-user/group.html
    var firstNotificationAndroidSpecifics = new AndroidNotificationDetails(
        groupChannelId, groupChannelName, groupChannelDescription,
        importance: Importance.Max,
        priority: Priority.High,
        groupKey: groupKey);
    var firstNotificationPlatformSpecifics =
        new NotificationDetails(firstNotificationAndroidSpecifics, null);
    await flutterLocalNotificationsPlugin.show(1, 'Alex Faarborg',
        'You will not believe...', firstNotificationPlatformSpecifics);
    var secondNotificationAndroidSpecifics = new AndroidNotificationDetails(
        groupChannelId, groupChannelName, groupChannelDescription,
        importance: Importance.Max,
        priority: Priority.High,
        groupKey: groupKey);
    var secondNotificationPlatformSpecifics =
        new NotificationDetails(secondNotificationAndroidSpecifics, null);
    await flutterLocalNotificationsPlugin.show(
        2,
        'Jeff Chang',
        'Please join us to celebrate the...',
        secondNotificationPlatformSpecifics);

    // create the summary notification required for older devices that pre-date Android 7.0 (API level 24)
    var lines = new List<String>();
    lines.add('Alex Faarborg  Check this out');
    lines.add('Jeff Chang    Launch Party');
    var inboxStyleInformation = new InboxStyleInformation(lines,
        contentTitle: '2 new messages', summaryText: 'janedoe@example.com');
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        groupChannelId, groupChannelName, groupChannelDescription,
        style: AndroidNotificationStyle.Inbox,
        styleInformation: inboxStyleInformation,
        groupKey: groupKey,
        setAsGroupSummary: true);
    var platformChannelSpecifics =
        new NotificationDetails(androidPlatformChannelSpecifics, null);
    await flutterLocalNotificationsPlugin.show(
        3, 'Attention', 'Two new messages', platformChannelSpecifics);
  }

  Future _cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future onSelectNotification(String payload) async {
    if (payload != null) {
      debugPrint('notification payload: ' + payload);
    }

    await Navigator.push(
      context,
      new MaterialPageRoute(builder: (context) => new SecondScreen(payload)),
    );
  }

  Future _showOngoingNotification() async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'your channel id', 'your channel name', 'your channel description',
        importance: Importance.Max,
        priority: Priority.High,
        ongoing: true,
        autoCancel: false);
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, 'ongoing notification title',
        'ongoing notification body', platformChannelSpecifics);
  }

  Future _repeatNotification() async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'repeating channel id',
        'repeating channel name',
        'repeating description');
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.periodicallyShow(0, 'repeating title',
        'repeating body', RepeatInterval.EveryMinute, platformChannelSpecifics);
  }

  Future _showDailyAtTime() async {
    var time = new Time(10, 0, 0);
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'repeatDailyAtTime channel id',
        'repeatDailyAtTime channel name',
        'repeatDailyAtTime description');
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.showDailyAtTime(
        0,
        'show daily title',
        'Daily notification shown at approximately ${_toTwoDigitString(time.hour)}:${_toTwoDigitString(time.minute)}:${_toTwoDigitString(time.second)}',
        time,
        platformChannelSpecifics);
  }

  Future _showWeeklyAtDayAndTime() async {
    var time = new Time(10, 0, 0);
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'show weekly channel id',
        'show weekly channel name',
        'show weekly description');
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
        0,
        'show weekly title',
        'Weekly notification shown on Monday at approximately ${_toTwoDigitString(time.hour)}:${_toTwoDigitString(time.minute)}:${_toTwoDigitString(time.second)}',
        Day.Monday,
        time,
        platformChannelSpecifics);
  }

  Future _showNotificationWithNoBadge() async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'no badge channel', 'no badge name', 'no badge description',
        channelShowBadge: false,
        importance: Importance.Max,
        priority: Priority.High,
        onlyAlertOnce: true);
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0, 'no badge title', 'no badge body', platformChannelSpecifics,
        payload: 'item x');
  }

  Future _showProgressNotification() async {
    var maxProgress = 5;
    for (var i = 0; i <= maxProgress; i++) {
      await Future.delayed(Duration(seconds: 1), () async {
        var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
            'progress channel',
            'progress channel',
            'progress channel description',
            channelShowBadge: false,
            importance: Importance.Max,
            priority: Priority.High,
            onlyAlertOnce: true,
            showProgress: true,
            maxProgress: maxProgress,
            progress: i);
        var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
        var platformChannelSpecifics = new NotificationDetails(
            androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
        await flutterLocalNotificationsPlugin.show(
            0,
            'progress notification title',
            'progress notification body',
            platformChannelSpecifics,
            payload: 'item x');
      });
    }
  }

  Future _showIndeterminateProgressNotification() async {
    var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
        'indeterminate progress channel',
        'indeterminate progress channel',
        'indeterminate progress channel description',
        channelShowBadge: false,
        importance: Importance.Max,
        priority: Priority.High,
        onlyAlertOnce: true,
        showProgress: true,
        indeterminate: true);
    var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
    var platformChannelSpecifics = new NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
        0,
        'indeterminate progress notification title',
        'indeterminate progress notification body',
        platformChannelSpecifics,
        payload: 'item x');
  }

  String _toTwoDigitString(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class SecondScreen extends StatefulWidget {
  final String payload;
  SecondScreen(this.payload);
  @override
  State<StatefulWidget> createState() => new SecondScreenState();
}

class SecondScreenState extends State<SecondScreen> {
  String _payload;
  @override
  void initState() {
    super.initState();
    _payload = widget.payload;
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text("Second Screen with payload: " + _payload),
      ),
      body: new Center(
        child: new RaisedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: new Text('Go back!'),
        ),
      ),
    );
  }
}
