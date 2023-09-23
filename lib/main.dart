import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ignore: unnecessary_import
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'info_value_string.dart';
import 'linux_notifications.dart';

int id = 0;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Streams are created so that app can respond to notification-related events
/// since the plugin is initialised in the `main` function
final StreamController<ReceivedNotification> didReceiveLocalNotificationStream =
    StreamController<ReceivedNotification>.broadcast();

final StreamController<String?> selectNotificationStream =
    StreamController<String?>.broadcast();

const MethodChannel platform =
    MethodChannel('dexterx.dev/flutter_local_notifications_example');

const String portName = 'notification_send_port';

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;

/// A notification action which triggers a url launch event
const String urlLaunchActionId = 'id_1';

/// A notification action which triggers a App navigation event
const String navigationActionId = 'id_3';

/// Defines a iOS/MacOS notification category for text input actions.
const String darwinNotificationCategoryText = 'textCategory';

/// Defines a iOS/MacOS notification category for plain actions.
const String darwinNotificationCategoryPlain = 'plainCategory';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // ignore: avoid_print
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  if (notificationResponse.input?.isNotEmpty ?? false) {
    // ignore: avoid_print
    print(
        'notification action tapped with input: ${notificationResponse.input}');
  }
}

/// IMPORTANT: running the following code on its own won't work as there is
/// setup required for each platform head project.
///
/// Please download the complete example app from the GitHub repository where
/// all the setup has been done
Future<void> main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  await _configureLocalTimeZone();

  final NotificationAppLaunchDetails? notificationAppLaunchDetails = !kIsWeb &&
          Platform.isLinux
      ? null
      : await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  String initialRoute = HomePage.routeName;
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    selectedNotificationPayload =
        notificationAppLaunchDetails!.notificationResponse?.payload;
    initialRoute = SecondPage.routeName;
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');

  final List<DarwinNotificationCategory> darwinNotificationCategories =
      <DarwinNotificationCategory>[
    DarwinNotificationCategory(
      darwinNotificationCategoryText,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.text(
          'text_1',
          'Action 1',
          buttonTitle: 'Send',
          placeholder: 'Placeholder',
        ),
      ],
    ),
    DarwinNotificationCategory(
      darwinNotificationCategoryPlain,
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain('id_1', 'Action 1'),
        DarwinNotificationAction.plain(
          'id_2',
          'Action 2 (destructive)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.destructive,
          },
        ),
        DarwinNotificationAction.plain(
          navigationActionId,
          'Action 3 (foreground)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.foreground,
          },
        ),
        DarwinNotificationAction.plain(
          'id_4',
          'Action 4 (auth required)',
          options: <DarwinNotificationActionOption>{
            DarwinNotificationActionOption.authenticationRequired,
          },
        ),
      ],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    )
  ];

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
    onDidReceiveLocalNotification:
        (int id, String? title, String? body, String? payload) async {
      didReceiveLocalNotificationStream.add(
        ReceivedNotification(
          id: id,
          title: title,
          body: body,
          payload: payload,
        ),
      );
    },
    notificationCategories: darwinNotificationCategories,
  );
  final LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(
    defaultActionName: 'Open notification',
    defaultIcon: AssetsLinuxIcon('icons/app_icon.png'),
  );
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
    linux: initializationSettingsLinux,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) {
      switch (notificationResponse.notificationResponseType) {
        case NotificationResponseType.selectedNotification:
          selectNotificationStream.add(notificationResponse.payload);
          break;
        case NotificationResponseType.selectedNotificationAction:
          if (notificationResponse.actionId == navigationActionId) {
            selectNotificationStream.add(notificationResponse.payload);
          }
          break;
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
  runApp(
    MaterialApp(
      initialRoute: initialRoute,
      routes: <String, WidgetBuilder>{
        HomePage.routeName: (_) => HomePage(notificationAppLaunchDetails),
        SecondPage.routeName: (_) => SecondPage(selectedNotificationPayload)
      },
    ),
  );
}

Future<void> _configureLocalTimeZone() async {
  if (kIsWeb || Platform.isLinux) {
    return;
  }
  tz.initializeTimeZones();
  final String? timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(timeZoneName!));
}

class PaddedElevatedButton extends StatelessWidget {
  const PaddedElevatedButton({
    required this.buttonText,
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: ElevatedButton(
          onPressed: onPressed,
          child: Text(buttonText),
        ),
      );
}

class HomePage extends StatefulWidget {
  const HomePage(
    this.notificationAppLaunchDetails, {
    Key? key,
  }) : super(key: key);

  static const String routeName = '/';

  final NotificationAppLaunchDetails? notificationAppLaunchDetails;

  bool get didNotificationLaunchApp =>
      notificationAppLaunchDetails?.didNotificationLaunchApp ?? false;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _linuxIconPathController =
      TextEditingController();

  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _isAndroidPermissionGranted();
    _requestPermissions();
    _configureDidReceiveLocalNotificationSubject();
    _configureSelectNotificationSubject();
  }

  Future<void> _isAndroidPermissionGranted() async {
    if (Platform.isAndroid) {
      final bool granted = await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;

      setState(() {
        _notificationsEnabled = granted;
      });
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? grantedNotificationPermission =
          await androidImplementation?.requestNotificationsPermission();
      setState(() {
        _notificationsEnabled = grantedNotificationPermission ?? false;
      });
    }
  }

  void _configureDidReceiveLocalNotificationSubject() {
    didReceiveLocalNotificationStream.stream
        .listen((ReceivedNotification receivedNotification) async {
      await showDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: receivedNotification.title != null
              ? Text(receivedNotification.title!)
              : null,
          content: receivedNotification.body != null
              ? Text(receivedNotification.body!)
              : null,
          actions: <Widget>[
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        SecondPage(receivedNotification.payload),
                  ),
                );
              },
              child: const Text('Ok'),
            )
          ],
        ),
      );
    });
  }

  void _configureSelectNotificationSubject() {
    selectNotificationStream.stream.listen((String? payload) async {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (BuildContext context) => SecondPage(payload),
      ));
    });
  }

  @override
  void dispose() {
    didReceiveLocalNotificationStream.close();
    selectNotificationStream.close();
    super.dispose();
  }

  List<Widget> commonWidgets() {
    final List<Widget> buttons = <Widget>[
      const Padding(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Text('Tap on a notification when it appears to trigger'
            ' navigation'),
      ),
      InfoValueString(
        title: 'Did notification launch app?',
        value: widget.didNotificationLaunchApp,
      ),
      if (widget.didNotificationLaunchApp) ...<Widget>[
        const Text('Launch notification details'),
        InfoValueString(
            title: 'Notification id',
            value:
                widget.notificationAppLaunchDetails!.notificationResponse?.id),
        InfoValueString(
            title: 'Action id',
            value: widget
                .notificationAppLaunchDetails!.notificationResponse?.actionId),
        InfoValueString(
            title: 'Input',
            value: widget
                .notificationAppLaunchDetails!.notificationResponse?.input),
        InfoValueString(
          title: 'Payload:',
          value: widget
              .notificationAppLaunchDetails!.notificationResponse?.payload,
        ),
      ],
      PaddedElevatedButton(
        buttonText: 'Show notification with custom sound',
        onPressed: () async {
          await _showNotificationCustomSound();
        },
      ),
    ];
    return buttons;
  }

  List<Widget> androidButtons() {
    final List<Widget> buttons = <Widget>[
      const Text(
        'Android-specific examples',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      Text('notifications enabled: $_notificationsEnabled'),
      PaddedElevatedButton(
        buttonText: 'Check if notifications are enabled for this app',
        onPressed: _areNotifcationsEnabledOnAndroid,
      ),
      PaddedElevatedButton(
        buttonText: 'Request permission (API 33+ android 13)',
        onPressed: () => _requestPermissions(),
      ),
      PaddedElevatedButton(
        buttonText: 'Show notification with sound controlled by '
            'alarm volume',
        onPressed: () async {
          await _showNotificationWithAudioAttributeAlarm();
        },
      ),
      PaddedElevatedButton(
        buttonText: 'Create notification channel',
        onPressed: () async {
          await _createNotificationChannel();
        },
      ),
      PaddedElevatedButton(
        buttonText: 'Delete notification channel',
        onPressed: () async {
          await _deleteNotificationChannel();
        },
      ),
      PaddedElevatedButton(
        buttonText: 'Get notification channels',
        onPressed: () async {
          await _getNotificationChannels();
        },
      ),
    ];
    return buttons;
  }

  List<Widget> linuxButtons() {
    final List<Widget> buttons = <Widget>[
      const Text(
        'Linux-specific examples',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      FutureBuilder<LinuxServerCapabilities>(
        future: getLinuxCapabilities(),
        builder: (
          BuildContext context,
          AsyncSnapshot<LinuxServerCapabilities> snapshot,
        ) {
          if (snapshot.hasData) {
            final LinuxServerCapabilities caps = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Capabilities of the current system:',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InfoValueString(
                    title: 'Body text:',
                    value: caps.body,
                  ),
                  InfoValueString(
                    title: 'Hyperlinks in body text:',
                    value: caps.bodyHyperlinks,
                  ),
                  InfoValueString(
                    title: 'Images in body:',
                    value: caps.bodyImages,
                  ),
                  InfoValueString(
                    title: 'Markup in the body text:',
                    value: caps.bodyMarkup,
                  ),
                  InfoValueString(
                    title: 'Animated icons:',
                    value: caps.iconMulti,
                  ),
                  InfoValueString(
                    title: 'Static icons:',
                    value: caps.iconStatic,
                  ),
                  InfoValueString(
                    title: 'Notification persistence:',
                    value: caps.persistence,
                  ),
                  InfoValueString(
                    title: 'Sound:',
                    value: caps.sound,
                  ),
                  InfoValueString(
                    title: 'Actions:',
                    value: caps.actions,
                  ),
                  InfoValueString(
                    title: 'Action icons:',
                    value: caps.actionIcons,
                  ),
                  InfoValueString(
                    title: 'Other capabilities:',
                    value: caps.otherCapabilities,
                  ),
                ],
              ),
            );
          } else {
            return const CircularProgressIndicator();
          }
        },
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: TextField(
          controller: _linuxIconPathController,
          decoration: InputDecoration(
            hintText: 'Enter the icon path',
            constraints: const BoxConstraints.tightFor(
              width: 300,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _linuxIconPathController.clear(),
            ),
          ),
        ),
      ),
    ];
    return buttons;
  }

  List<Widget> nonLinuxButtons() {
    final List<Widget> list = <Widget>[
      PaddedElevatedButton(
        buttonText: 'Schedule notification to appear in 5 seconds '
            'based on local time zone using alarm clock',
        onPressed: () async {
          await _zonedScheduleAlarmClockNotification();
        },
      ),
      PaddedElevatedButton(
        buttonText: 'Repeat notification every minute',
        onPressed: () async {
          await _repeatNotification();
        },
      ),
      PaddedElevatedButton(
        buttonText: 'Schedule daily 10:00:00 am notification in your '
            'local time zone',
        onPressed: () async {
          await _scheduleDailyTenAMNotification();
        },
      ),
      PaddedElevatedButton(
        buttonText: 'Check pending notifications',
        onPressed: () async {
          await _checkPendingNotificationRequests();
        },
      ),
      PaddedElevatedButton(
        buttonText: 'Get active notifications',
        onPressed: () async {
          await _getActiveNotifications();
        },
      ),
    ];
    return list;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Center(
              child: Column(
                children: <Widget>[
                  ...commonWidgets(),
                  if (kIsWeb || !Platform.isLinux) ...nonLinuxButtons(),
                  ...<Widget>[
                    PaddedElevatedButton(
                      buttonText:
                          'Schedule monthly Monday 10:00:00AM notification in '
                          'your local time zone',
                      onPressed: () async {
                        await _scheduleMonthlyMondayTenAMNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Cancel latest notification',
                      onPressed: () async {
                        await _cancelNotification();
                      },
                    ),
                    PaddedElevatedButton(
                      buttonText: 'Cancel all notifications',
                      onPressed: () async {
                        await _cancelAllNotifications();
                      },
                    ),
                  ],
                  const Divider(),
                  const Text(
                    'Notifications with actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (Platform.isLinux)
                    PaddedElevatedButton(
                      buttonText:
                          'Show notification with icon action (if supported)',
                      onPressed: () async {
                        await _showNotificationWithIconAction();
                      },
                    ),
                  const Divider(),
                  if (Platform.isAndroid) ...androidButtons(),
                  if (!kIsWeb &&
                      (Platform.isIOS || Platform.isMacOS)) ...<Widget>[
                    const Text(
                      'iOS and macOS-specific examples',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                  if (!kIsWeb && Platform.isLinux) ...linuxButtons(),
                ],
              ),
            ),
          ),
        ),
      );

  String _formatPerson(Person? person) {
    if (person == null) {
      return 'null';
    }

    final List<String> attrs = <String>[];
    if (person.name != null) {
      attrs.add('name: "${person.name}"');
    }
    if (person.uri != null) {
      attrs.add('uri: "${person.uri}"');
    }
    if (person.key != null) {
      attrs.add('key: "${person.key}"');
    }
    if (person.important) {
      attrs.add('important: true');
    }
    if (person.bot) {
      attrs.add('bot: true');
    }
    if (person.icon != null) {
      attrs.add('icon: ${_formatAndroidIcon(person.icon)}');
    }
    return 'Person(${attrs.join(', ')})';
  }

  String _formatAndroidIcon(Object? icon) {
    if (icon == null) {
      return 'null';
    }
    if (icon is DrawableResourceAndroidIcon) {
      return 'DrawableResourceAndroidIcon("${icon.data}")';
    } else if (icon is ContentUriAndroidIcon) {
      return 'ContentUriAndroidIcon("${icon.data}")';
    } else {
      return 'AndroidIcon()';
    }
  }

  tz.TZDateTime _nextInstanceOfTenAM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfMondayTenAM() {
    tz.TZDateTime scheduledDate = _nextInstanceOfTenAM();
    while (scheduledDate.weekday != DateTime.monday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel androidNotificationChannel =
        AndroidNotificationChannel(
      'your channel id 2',
      'your channel name 2',
      description: 'your channel description 2',
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidNotificationChannel);

    await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              content:
                  Text('Channel with name ${androidNotificationChannel.name} '
                      'created'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ));
  }

  Future<void> _deleteNotificationChannel() async {
    const String channelId = 'your channel id 2';
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannel(channelId);

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: const Text('Channel with id $channelId deleted'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPendingNotificationRequests() async {
    final List<PendingNotificationRequest> pendingNotificationRequests =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content:
            Text('${pendingNotificationRequests.length} pending notification '
                'requests'),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _areNotifcationsEnabledOnAndroid() async {
    final bool? areEnabled = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              content: Text(areEnabled == null
                  ? 'ERROR: received null'
                  : (areEnabled
                      ? 'Notifications are enabled'
                      : 'Notifications are NOT enabled')),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            ));
  }

  Future<void> _getActiveNotifications() async {
    final Widget activeNotificationsDialogContent =
        await _getActiveNotificationsDialogContent();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: activeNotificationsDialogContent,
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<Widget> _getActiveNotificationsDialogContent() async {
    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt < 23) {
        return const Text(
          '"getActiveNotifications" is available only for Android 6.0 or newer',
        );
      }
    } else if (Platform.isIOS) {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      final List<String> fullVersion = iosInfo.systemVersion!.split('.');
      if (fullVersion.isNotEmpty) {
        final int? version = int.tryParse(fullVersion[0]);
        if (version != null && version < 10) {
          return const Text(
            '"getActiveNotifications" is available only for iOS 10.0 or newer',
          );
        }
      }
    }

    try {
      final List<ActiveNotification>? activeNotifications =
          await flutterLocalNotificationsPlugin.getActiveNotifications();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'Active Notifications',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.black),
          if (activeNotifications!.isEmpty)
            const Text('No active notifications'),
          if (activeNotifications.isNotEmpty)
            for (final ActiveNotification activeNotification
                in activeNotifications)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'id: ${activeNotification.id}\n'
                    'channelId: ${activeNotification.channelId}\n'
                    'groupKey: ${activeNotification.groupKey}\n'
                    'tag: ${activeNotification.tag}\n'
                    'title: ${activeNotification.title}\n'
                    'body: ${activeNotification.body}',
                  ),
                  if (Platform.isAndroid && activeNotification.id != null)
                    TextButton(
                      child: const Text('Get messaging style'),
                      onPressed: () {
                        _getActiveNotificationMessagingStyle(
                            activeNotification.id!, activeNotification.tag);
                      },
                    ),
                  const Divider(color: Colors.black),
                ],
              ),
        ],
      );
    } on PlatformException catch (error) {
      return Text(
        'Error calling "getActiveNotifications"\n'
        'code: ${error.code}\n'
        'message: ${error.message}',
      );
    }
  }

  Future<void> _getActiveNotificationMessagingStyle(int id, String? tag) async {
    Widget dialogContent;
    try {
      final MessagingStyleInformation? messagingStyle =
          await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()!
              .getActiveNotificationMessagingStyle(id, tag: tag);
      if (messagingStyle == null) {
        dialogContent = const Text('No messaging style');
      } else {
        dialogContent = SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('person: ${_formatPerson(messagingStyle.person)}\n'
                'conversationTitle: ${messagingStyle.conversationTitle}\n'
                'groupConversation: ${messagingStyle.groupConversation}'),
            const Divider(color: Colors.black),
            if (messagingStyle.messages == null) const Text('No messages'),
            if (messagingStyle.messages != null)
              for (final Message msg in messagingStyle.messages!)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('text: ${msg.text}\n'
                        'timestamp: ${msg.timestamp}\n'
                        'person: ${_formatPerson(msg.person)}'),
                    const Divider(color: Colors.black),
                  ],
                ),
          ],
        ));
      }
    } on PlatformException catch (error) {
      dialogContent = Text(
        'Error calling "getActiveNotificationMessagingStyle"\n'
        'code: ${error.code}\n'
        'message: ${error.message}',
      );
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Messaging style'),
        content: dialogContent,
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _getNotificationChannels() async {
    final Widget notificationChannelsDialogContent =
        await _getNotificationChannelsDialogContent();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: notificationChannelsDialogContent,
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<Widget> _getNotificationChannelsDialogContent() async {
    try {
      final List<AndroidNotificationChannel>? channels =
          await flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()!
              .getNotificationChannels();

      return Container(
        width: double.maxFinite,
        child: ListView(
          children: <Widget>[
            const Text(
              'Notifications Channels',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.black),
            if (channels?.isEmpty ?? true)
              const Text('No notification channels')
            else
              for (final AndroidNotificationChannel channel in channels!)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('id: ${channel.id}\n'
                        'name: ${channel.name}\n'
                        'description: ${channel.description}\n'
                        'groupId: ${channel.groupId}\n'
                        'importance: ${channel.importance.value}\n'
                        'playSound: ${channel.playSound}\n'
                        'sound: ${channel.sound?.sound}\n'
                        'enableVibration: ${channel.enableVibration}\n'
                        'vibrationPattern: ${channel.vibrationPattern}\n'
                        'showBadge: ${channel.showBadge}\n'
                        'enableLights: ${channel.enableLights}\n'
                        'ledColor: ${channel.ledColor}\n'),
                    const Divider(color: Colors.black),
                  ],
                ),
          ],
        ),
      );
    } on PlatformException catch (error) {
      return Text(
        'Error calling "getNotificationChannels"\n'
        'code: ${error.code}\n'
        'message: ${error.message}',
      );
    }
  }

  Future<void> _zonedScheduleAlarmClockNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        123,
        'scheduled alarm clock title',
        'scheduled alarm clock body',
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'alarm_clock_channel', 'Alarm Clock Channel',
                channelDescription: 'Alarm Clock Notification')),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime);
  }

  Future<void> _cancelNotification() async {
    await flutterLocalNotificationsPlugin.cancel(--id);
  }

  Future<void> _cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> _repeatNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
            'repeating channel id', 'repeating channel name',
            channelDescription: 'repeating description');
    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
    await flutterLocalNotificationsPlugin.periodicallyShow(
      id++,
      'repeating title',
      'repeating body',
      RepeatInterval.everyMinute,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _scheduleDailyTenAMNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'daily scheduled notification title',
        'daily scheduled notification body',
        _nextInstanceOfTenAM(),
        const NotificationDetails(
          android: AndroidNotificationDetails('daily notification channel id',
              'daily notification channel name',
              channelDescription: 'daily notification description'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time);
  }

  Future<void> _scheduleMonthlyMondayTenAMNotification() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
        0,
        'monthly scheduled notification title',
        'monthly scheduled notification body',
        _nextInstanceOfMondayTenAM(),
        const NotificationDetails(
          android: AndroidNotificationDetails('monthly notification channel id',
              'monthly notification channel name',
              channelDescription: 'monthly notificationdescription'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime);
  }

  Future<void> _showNotificationWithIconAction() async {
    const LinuxNotificationDetails linuxNotificationDetails =
        LinuxNotificationDetails(
      actions: <LinuxNotificationAction>[
        LinuxNotificationAction(
          key: 'media-eject',
          label: 'Eject',
        ),
      ],
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      linux: linuxNotificationDetails,
    );
    await flutterLocalNotificationsPlugin.show(
        id++, 'plain title', 'plain body', notificationDetails,
        payload: 'item z');
  }

  Future<void> _showNotificationCustomSound() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'your other channel id',
      'your other channel name',
      channelDescription: 'your other channel description',
      sound: RawResourceAndroidNotificationSound('slow_spring_board'),
    );
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      sound: 'slow_spring_board.aiff',
    );
    final LinuxNotificationDetails linuxPlatformChannelSpecifics =
        LinuxNotificationDetails(
      sound: AssetsLinuxSound('sound/slow_spring_board.mp3'),
    );
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
      linux: linuxPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id++,
      'custom sound notification title',
      'custom sound notification body',
      notificationDetails,
    );
  }

  Future<void> _showNotificationWithAudioAttributeAlarm() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your alarm channel id',
      'your alarm channel name',
      channelDescription: 'your alarm channel description',
      importance: Importance.max,
      priority: Priority.high,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      'notification sound controlled by alarm volume',
      'alarm notification sound body',
      platformChannelSpecifics,
    );
  }
}

Future<LinuxServerCapabilities> getLinuxCapabilities() =>
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            LinuxFlutterLocalNotificationsPlugin>()!
        .getCapabilities();

class SecondPage extends StatefulWidget {
  const SecondPage(
    this.payload, {
    Key? key,
  }) : super(key: key);

  static const String routeName = '/secondPage';

  final String? payload;

  @override
  State<StatefulWidget> createState() => SecondPageState();
}

class SecondPageState extends State<SecondPage> {
  String? _payload;

  @override
  void initState() {
    super.initState();
    _payload = widget.payload;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Second Screen'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('payload ${_payload ?? ''}'),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Go back!'),
              ),
            ],
          ),
        ),
      );
}
