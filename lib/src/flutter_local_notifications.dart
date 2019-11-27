import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:platform/platform.dart';
import 'initialization_settings.dart';
import 'notification_app_launch_details.dart';
import 'notification_details.dart';
import 'pending_notification_request.dart';

/// Signature of callback passed to [initialize]. Callback triggered when user taps on a notification
typedef SelectNotificationCallback = Future<dynamic> Function(String payload);

// Signature of the callback that is triggered when a notification is shown whilst the app is in the foreground. Applicable to iOS versions < 10 only
typedef DidReceiveLocalNotificationCallback = Future<dynamic> Function(
    int id, String title, String body, String payload);

/// The available intervals for periodically showing notifications
enum RepeatInterval { EveryMinute, Hourly, Daily, Weekly }

/// The days of the week
class Day {
  static const Sunday = Day(1);
  static const Monday = Day(2);
  static const Tuesday = Day(3);
  static const Wednesday = Day(4);
  static const Thursday = Day(5);
  static const Friday = Day(6);
  static const Saturday = Day(7);

  static get values =>
      [Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday];

  final int value;

  const Day(this.value);
}

/// Used for specifying a time in 24 hour format
class Time {
  /// The hour component of the time. Accepted range is 0 to 23 inclusive
  final int hour;

  /// The minutes component of the time. Accepted range is 0 to 59 inclusive
  final int minute;

  /// The seconds component of the time. Accepted range is 0 to 59 inclusive
  final int second;

  Time([this.hour = 0, this.minute = 0, this.second = 0]) {
    assert(this.hour >= 0 && this.hour < 24);
    assert(this.minute >= 0 && this.minute < 60);
    assert(this.second >= 0 && this.second < 60);
  }

  Map<String, int> toMap() {
    return <String, int>{
      'hour': hour,
      'minute': minute,
      'second': second,
    };
  }
}

/// A category for notification actions.
///
/// For `snooze` actions: the payload should be the number of seconds to
/// snooze the notification for.
///
/// For `geofence` actions: to reschedule the same geofence, the payload
/// must be exactly `remindAtLocation`.
///
/// For `payload` actions: to simply pass a payload back to the app,
/// the payload must not be numeric only or match `remindAtLocation`.
class NotificationCategory {
  final String identifier;
  final String title;
  final String firstActionTitle;
  final String secondActionTitle;
  final String thirdActionTitle;
  final String firstActionPayload;
  final String secondActionPayload;
  final String thirdActionPayload;

  const NotificationCategory._(
    this.identifier,
    this.title,
    this.firstActionTitle,
    this.secondActionTitle,
    this.thirdActionTitle,
    this.firstActionPayload,
    this.secondActionPayload,
    this.thirdActionPayload,
  );

  Map<String, dynamic> toMap() {
    return {
      'category': identifier,
      'categoryTitle': title,
      'firstActionTitle': firstActionTitle,
      'secondActionTitle': secondActionTitle,
      'thirdActionTitle': thirdActionTitle,
      'firstActionPayload': firstActionPayload,
      'secondActionPayload': secondActionPayload,
      'thirdActionPayload': thirdActionPayload
    };
  }

  factory NotificationCategory._noAction() {
    return NotificationCategory._(
        'no_actions', 'Default', '', '', '', '', '', '');
  }

  factory NotificationCategory.custom({
    @required String identifier,
    @required String title,
    String firstActionTitle = '',
    String secondActionTitle = '',
    String thirdActionTitle = '',
    String firstActionPayload = '',
    String secondActionPayload = '',
    String thirdActionPayload = '',
  }) {
    assert(firstActionTitle != null);
    assert(secondActionTitle != null);
    assert(thirdActionTitle != null);
    return NotificationCategory._(
      identifier,
      title,
      firstActionTitle,
      secondActionTitle,
      thirdActionTitle,
      firstActionPayload,
      secondActionPayload,
      thirdActionPayload,
    );
  }
}

class LocationNotificationInfo {
  final int id;
  final String title;
  final String body;
  final String payload;
  final double latitude;
  final double longitude;
  final double radius;
  final bool notifyOnEntry;
  final bool notifyOnExit;
  final String firstActionPayload;
  final String secondActionPayload;
  final String thirdActionPayload;

  LocationNotificationInfo({
    @required this.id,
    @required this.title,
    @required this.body,
    this.payload,
    @required this.latitude,
    @required this.longitude,
    this.radius = 100.0,
    this.notifyOnEntry = true,
    this.notifyOnExit = false,
    this.firstActionPayload,
    this.secondActionPayload,
    this.thirdActionPayload,
  })  : assert(id != null),
        assert(title != null),
        assert(body != null),
        assert(latitude != null),
        assert(longitude != null);
}

class FlutterLocalNotificationsPlugin {
  factory FlutterLocalNotificationsPlugin() => _instance;

  @visibleForTesting
  FlutterLocalNotificationsPlugin.private(
      MethodChannel channel, Platform platform)
      : _channel = channel,
        _platform = platform,
        _categories = [];

  static final FlutterLocalNotificationsPlugin _instance =
      FlutterLocalNotificationsPlugin.private(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          const LocalPlatform());

  final MethodChannel _channel;
  final Platform _platform;
  final List<NotificationCategory> _categories;

  SelectNotificationCallback selectNotificationCallback;

  DidReceiveLocalNotificationCallback didReceiveLocalNotificationCallback;

  /// Initializes the plugin. Call this method on application before using the plugin further
  Future<bool> initialize(
    InitializationSettings initializationSettings, {
    SelectNotificationCallback onSelectNotification,
    List<NotificationCategory> categories,
  }) async {
    selectNotificationCallback = onSelectNotification;
    didReceiveLocalNotificationCallback =
        initializationSettings?.ios?.onDidReceiveLocalNotification;
    var serializedPlatformSpecifics =
        _retrievePlatformSpecificInitializationSettings(initializationSettings);
    _channel.setMethodCallHandler(_handleMethod);
    _categories.add(NotificationCategory._noAction());
    _categories.addAll(categories);
    serializedPlatformSpecifics['categories'] =
        _categories.map((c) => c.toMap()).toList();
    /*final CallbackHandle callback =
        PluginUtilities.getCallbackHandle(_callbackDispatcher);
    serializedPlatformSpecifics['callbackDispatcher'] = callback.toRawHandle();
    if (onShowNotification != null) {
      serializedPlatformSpecifics['onNotificationCallbackDispatcher'] =
          PluginUtilities.getCallbackHandle(onShowNotification).toRawHandle();
    }*/
    var result =
        await _channel.invokeMethod('initialize', serializedPlatformSpecifics);
    return result;
  }

  Future<NotificationAppLaunchDetails> getNotificationAppLaunchDetails() async {
    var result = await _channel.invokeMethod('getNotificationAppLaunchDetails');
    return NotificationAppLaunchDetails(result['notificationLaunchedApp'],
        result.containsKey('payload') ? result['payload'] : null);
  }

  /// Show a notification with an optional payload that will be passed back to the app when a notification is tapped
  Future<void> show(int id, String title, String body,
      NotificationDetails notificationDetails,
      {String payload,
      String categoryIdentifier,
      String firstActionPayload,
      String secondActionPayload,
      String thirdActionPayload}) async {
    _validateId(id);
    var category = _categories.firstWhere(
        (c) => c.identifier == categoryIdentifier,
        orElse: () => _categories.first);
    var serializedPlatformSpecifics =
        _retrievePlatformSpecificNotificationDetails(notificationDetails);
    await _channel.invokeMethod('show', <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'platformSpecifics': serializedPlatformSpecifics,
      'payload': payload ?? '',
      'category': category.identifier,
      'firstActionTitle': category.firstActionTitle,
      'secondActionTitle': category.secondActionTitle,
      'thirdActionTitle': category.thirdActionTitle,
      'firstActionPayload': firstActionPayload ?? category.firstActionPayload,
      'secondActionPayload':
          secondActionPayload ?? category.secondActionPayload,
      'thirdActionPayload': thirdActionPayload ?? category.thirdActionPayload,
    });
  }

  /// Cancel/remove the notification with the specified id. This applies to notifications that have been scheduled and those that have already been presented.
  Future<void> cancel(int id) async {
    _validateId(id);
    await _channel.invokeMethod('cancel', id);
  }

  /// Cancels/removes all notifications. This applies to notifications that have been scheduled and those that have already been presented.
  Future<void> cancelAll() async {
    await _channel.invokeMethod('cancelAll');
  }

  /// Schedules a notification to be shown at the specified time with an optional payload that is passed through when a notification is tapped
  /// The [androidAllowWhileIdle] parameter is Android-specific and determines if the notification should still be shown at the specified time
  /// even when in a low-power idle mode.
  Future<void> schedule(int id, String title, String body,
      DateTime scheduledDate, NotificationDetails notificationDetails,
      {String payload,
      bool androidAllowWhileIdle = false,
      String categoryIdentifier,
      String firstActionPayload,
      String secondActionPayload,
      String thirdActionPayload}) async {
    _validateId(id);
    var category = _categories.firstWhere(
        (c) => c.identifier == categoryIdentifier,
        orElse: () => _categories.first);
    var serializedPlatformSpecifics =
        _retrievePlatformSpecificNotificationDetails(notificationDetails);
    if (_platform.isAndroid) {
      serializedPlatformSpecifics['allowWhileIdle'] = androidAllowWhileIdle;
    }
    await _channel.invokeMethod('schedule', <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'millisecondsSinceEpoch': scheduledDate.millisecondsSinceEpoch,
      'platformSpecifics': serializedPlatformSpecifics,
      'payload': payload ?? '',
      'category': category.identifier,
      'firstActionTitle': category.firstActionTitle,
      'secondActionTitle': category.secondActionTitle,
      'thirdActionTitle': category.thirdActionTitle,
      'firstActionPayload': firstActionPayload ?? category.firstActionPayload,
      'secondActionPayload':
          secondActionPayload ?? category.secondActionPayload,
      'thirdActionPayload': thirdActionPayload ?? category.thirdActionPayload,
    });
  }

  /// Periodically show a notification using the specified interval.
  /// For example, specifying a hourly interval means the first time the notification will be an hour after the method has been called and then every hour after that.
  Future<void> periodicallyShow(int id, String title, String body,
      RepeatInterval repeatInterval, NotificationDetails notificationDetails,
      {String payload,
      String categoryIdentifier,
      String firstActionPayload,
      String secondActionPayload,
      String thirdActionPayload}) async {
    _validateId(id);
    var category = _categories.firstWhere(
        (c) => c.identifier == categoryIdentifier,
        orElse: () => _categories.first);
    var serializedPlatformSpecifics =
        _retrievePlatformSpecificNotificationDetails(notificationDetails);
    await _channel.invokeMethod('periodicallyShow', <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'calledAt': DateTime.now().millisecondsSinceEpoch,
      'repeatInterval': repeatInterval.index,
      'platformSpecifics': serializedPlatformSpecifics,
      'payload': payload ?? '',
      'category': category.identifier,
      'firstActionTitle': category.firstActionTitle,
      'secondActionTitle': category.secondActionTitle,
      'thirdActionTitle': category.thirdActionTitle,
      'firstActionPayload': firstActionPayload ?? category.firstActionPayload,
      'secondActionPayload':
          secondActionPayload ?? category.secondActionPayload,
      'thirdActionPayload': thirdActionPayload ?? category.thirdActionPayload,
    });
  }

  /// Shows a notification on a daily interval at the specified time
  Future<void> showDailyAtTime(int id, String title, String body,
      Time notificationTime, NotificationDetails notificationDetails,
      {String payload,
      String categoryIdentifier,
      String firstActionPayload,
      String secondActionPayload,
      String thirdActionPayload}) async {
    _validateId(id);
    var category = _categories.firstWhere(
        (c) => c.identifier == categoryIdentifier,
        orElse: () => _categories.first);
    var serializedPlatformSpecifics =
        _retrievePlatformSpecificNotificationDetails(notificationDetails);
    await _channel.invokeMethod('showDailyAtTime', <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'calledAt': DateTime.now().millisecondsSinceEpoch,
      'repeatInterval': RepeatInterval.Daily.index,
      'repeatTime': notificationTime.toMap(),
      'platformSpecifics': serializedPlatformSpecifics,
      'payload': payload ?? '',
      'category': category.identifier,
      'firstActionTitle': category.firstActionTitle,
      'secondActionTitle': category.secondActionTitle,
      'thirdActionTitle': category.thirdActionTitle,
      'firstActionPayload': firstActionPayload ?? category.firstActionPayload,
      'secondActionPayload':
          secondActionPayload ?? category.secondActionPayload,
      'thirdActionPayload': thirdActionPayload ?? category.thirdActionPayload,
    });
  }

  /// Shows a notification on a daily interval at the specified time
  Future<void> showWeeklyAtDayAndTime(int id, String title, String body,
      Day day, Time notificationTime, NotificationDetails notificationDetails,
      {String payload,
      String categoryIdentifier,
      String firstActionPayload,
      String secondActionPayload,
      String thirdActionPayload}) async {
    _validateId(id);
    var category = _categories.firstWhere(
        (c) => c.identifier == categoryIdentifier,
        orElse: () => _categories.first);
    var serializedPlatformSpecifics =
        _retrievePlatformSpecificNotificationDetails(notificationDetails);
    await _channel.invokeMethod('showWeeklyAtDayAndTime', <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'calledAt': DateTime.now().millisecondsSinceEpoch,
      'repeatInterval': RepeatInterval.Weekly.index,
      'repeatTime': notificationTime.toMap(),
      'day': day.value,
      'platformSpecifics': serializedPlatformSpecifics,
      'payload': payload ?? '',
      'category': category.identifier,
      'firstActionTitle': category.firstActionTitle,
      'secondActionTitle': category.secondActionTitle,
      'thirdActionTitle': category.thirdActionTitle,
      'firstActionPayload': firstActionPayload ?? category.firstActionPayload,
      'secondActionPayload':
          secondActionPayload ?? category.secondActionPayload,
      'thirdActionPayload': thirdActionPayload ?? category.thirdActionPayload,
    });
  }

  Future<void> showAtLocations(List<LocationNotificationInfo> notifications,
      {String categoryIdentifier,
      NotificationDetails notificationDetails}) async {
    if (_platform.isIOS) {
      for (var notification in notifications) {
        await _showAtLocation(
          notification,
          categoryIdentifier: categoryIdentifier,
          notificationDetails: notificationDetails,
        );
      }
    } else {
      var category = _categories.firstWhere(
          (c) => c.identifier == categoryIdentifier,
          orElse: () => _categories.first);
      var serializedPlatformSpecifics =
          _retrievePlatformSpecificNotificationDetails(notificationDetails);
      await _channel.invokeMethod(
        'showAtLocation',
        notifications
            .map((info) {
              return <String, dynamic>{
                'id': info.id,
                'title': info.title,
                'body': info.body,
                'platformSpecifics': serializedPlatformSpecifics,
                'payload': info.payload ?? '',
                'category': category.identifier,
                'firstActionTitle': category.firstActionTitle,
                'secondActionTitle': category.secondActionTitle,
                'thirdActionTitle': category.thirdActionTitle,
                'firstActionPayload':
                    info.firstActionPayload ?? category.firstActionPayload,
                'secondActionPayload':
                    info.secondActionPayload ?? category.secondActionPayload,
                'thirdActionPayload':
                    info.thirdActionPayload ?? category.thirdActionPayload,
                'latitude': info.latitude,
                'longitude': info.longitude,
                'radius': info.radius,
                'notifyOnEntry': info.notifyOnEntry,
                'notifyOnExit': info.notifyOnExit,
              };
            })
            .toList()
            .cast<Map<String, dynamic>>(),
      );
    }
  }

  Future<void> _showAtLocation(LocationNotificationInfo info,
      {NotificationDetails notificationDetails,
      String categoryIdentifier}) async {
    _validateId(info.id);
    var category = _categories.firstWhere(
        (c) => c.identifier == categoryIdentifier,
        orElse: () => _categories.first);
    var serializedPlatformSpecifics =
        _retrievePlatformSpecificNotificationDetails(notificationDetails);
    await _channel.invokeMethod('showAtLocation', <String, dynamic>{
      'id': info.id,
      'title': info.title,
      'body': info.body,
      'platformSpecifics': serializedPlatformSpecifics,
      'payload': info.payload ?? '',
      'category': category.identifier,
      'firstActionTitle': category.firstActionTitle,
      'secondActionTitle': category.secondActionTitle,
      'thirdActionTitle': category.thirdActionTitle,
      'firstActionPayload':
          info.firstActionPayload ?? category.firstActionPayload,
      'secondActionPayload':
          info.secondActionPayload ?? category.secondActionPayload,
      'thirdActionPayload':
          info.thirdActionPayload ?? category.thirdActionPayload,
      'latitude': info.latitude,
      'longitude': info.longitude,
      'radius': info.radius,
      'notifyOnEntry': info.notifyOnEntry,
      'notifyOnExit': info.notifyOnExit,
    });
  }

  /// Returns a list of notifications pending to be delivered/shown
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    final List<Map<dynamic, dynamic>> pendingNotifications =
        await _channel.invokeListMethod('pendingNotificationRequests');
    return pendingNotifications
        .map((pendingNotification) => PendingNotificationRequest(
            pendingNotification['id'],
            pendingNotification['title'],
            pendingNotification['body'],
            pendingNotification['payload']))
        .toList();
  }

  Map<String, dynamic> _retrievePlatformSpecificNotificationDetails(
      NotificationDetails notificationDetails) {
    Map<String, dynamic> serializedPlatformSpecifics;
    if (_platform.isAndroid) {
      serializedPlatformSpecifics = notificationDetails?.android?.toMap();
    } else if (_platform.isIOS) {
      serializedPlatformSpecifics = notificationDetails?.iOS?.toMap();
    }
    return serializedPlatformSpecifics;
  }

  Map<String, dynamic> _retrievePlatformSpecificInitializationSettings(
      InitializationSettings initializationSettings) {
    Map<String, dynamic> serializedPlatformSpecifics;
    if (_platform.isAndroid) {
      serializedPlatformSpecifics = initializationSettings?.android?.toMap();
    } else if (_platform.isIOS) {
      serializedPlatformSpecifics = initializationSettings?.ios?.toMap();
    }
    return serializedPlatformSpecifics;
  }

  Future<void> _handleMethod(MethodCall call) {
    switch (call.method) {
      case 'selectNotification':
        return selectNotificationCallback(call.arguments);

      case 'didReceiveLocalNotification':
        return didReceiveLocalNotificationCallback(
            call.arguments['id'],
            call.arguments['title'],
            call.arguments['body'],
            call.arguments['payload']);
      default:
        return Future.error('method not defined');
    }
  }

  void _validateId(int id) {
    if (id > 0x7FFFFFFF || id < -0x80000000) {
      throw ArgumentError(
          'id must fit within the size of a 32-bit integer i.e. in the range [-2^31, 2^31 - 1]');
    }
  }
}
