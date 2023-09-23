import 'dart:async';
// ignore: unnecessary_import
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image/image.dart' as image;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<int> doShowLinuxNotificationWithBodyMarkup(int id) async {
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with body markup',
    '<b>bold text</b>\n'
        '<i>italic text</i>\n'
        '<u>underline text</u>\n'
        'https://example.com\n'
        '<a href="https://example.com">example.com</a>',
    null,
  );
  return id;
}

Future<int> doShowLinuxNotificationWithCategory(int id) async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    category: LinuxNotificationCategory.emailArrived,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with category',
    null,
    notificationDetails,
  );
  return id;
}

Future<int> doShowLinuxNotificationWithByteDataIcon(int id) async {
  final ByteData assetIcon = await rootBundle.load(
    'icons/app_icon_density.png',
  );
  final image.Image? iconData = image.decodePng(
    assetIcon.buffer.asUint8List().toList(),
  );
  final Uint8List iconBytes = iconData!.getBytes();
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    icon: ByteDataLinuxIcon(
      LinuxRawIconData(
        data: iconBytes,
        width: iconData.width,
        height: iconData.height,
        channels: 4, // The icon has an alpha channel
        hasAlpha: true,
      ),
    ),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with byte data icon',
    null,
    notificationDetails,
  );
  return id;
}

Future<int> doShowLinuxNotificationWithPathIcon(String path, int id) async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(icon: FilePathLinuxIcon(path));
  final NotificationDetails platformChannelSpecifics = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    'notification with file path icon',
    null,
    platformChannelSpecifics,
  );
  return id;
}

Future<int> doShowLinuxNotificationWithThemeIcon(int id) async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    icon: ThemeLinuxIcon('media-eject'),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with theme icon',
    null,
    notificationDetails,
  );
  return id;
}

Future<int> doShowLinuxNotificationWithThemeSound(int id) async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    sound: ThemeLinuxSound('message-new-email'),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with theme sound',
    null,
    notificationDetails,
  );
  return id;
}

Future<int> doShowLinuxNotificationWithCriticalUrgency(int id) async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    urgency: LinuxNotificationUrgency.critical,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with critical urgency',
    null,
    notificationDetails,
  );
  return id;
}

Future<int> doShowLinuxNotificationWithTimeout(int id) async {
  final LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    timeout: LinuxNotificationTimeout.fromDuration(
      const Duration(seconds: 1),
    ),
  );
  final NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification with timeout',
    null,
    notificationDetails,
  );
  return id;
}

Future<int> doShowLinuxNotificationSuppressSound(int id) async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    suppressSound: true,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'suppress notification sound',
    null,
    notificationDetails,
  );
  return id;
}

Future<int> doShowLinuxNotificationTransient(int id) async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    transient: true,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'transient notification',
    null,
    notificationDetails,
  );
  return id;
}

Future<int> doShowLinuxNotificationResident(int id) async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(
    resident: true,
  );
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'resident notification',
    null,
    notificationDetails,
  );
  return id;
}

Future<int> doShowLinuxNotificationDifferentLocation(int id) async {
  const LinuxNotificationDetails linuxPlatformChannelSpecifics =
      LinuxNotificationDetails(location: LinuxNotificationLocation(10, 10));
  const NotificationDetails notificationDetails = NotificationDetails(
    linux: linuxPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    id++,
    'notification on different screen location',
    null,
    notificationDetails,
  );
  return id;
}
