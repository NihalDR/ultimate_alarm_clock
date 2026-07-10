import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultimate_alarm_clock/app/data/models/user_model.dart';
import 'package:ultimate_alarm_clock/app/data/providers/firestore_provider.dart';
import 'package:ultimate_alarm_clock/app/data/providers/secure_storage_provider.dart';
import 'package:ultimate_alarm_clock/app/utils/shared_alarm_logger.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const String _kPendingSharedAlarmsKey = 'pending_shared_alarms';
const String _kPendingFcmTokenKey = 'pending_fcm_token';

// ─── Notification channel IDs ────────────────────────────────────────────────
const String _kSharedAlarmChannelId = 'shared_alarm_channel';
const String _kSharedAlarmChannelName = 'Shared Alarms';
const String _kSharedAlarmChannelDesc =
    'Notifications for incoming shared alarm requests';

// ─── Notification action IDs ─────────────────────────────────────────────────
const String kActionAccept = 'ACCEPT_SHARED_ALARM';
const String kActionDecline = 'DECLINE_SHARED_ALARM';

// Global instance for background use
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ─── Background message handler ─────────────────────────────────────────────
// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final data = message.data;
  final type = data['type'] ?? '';
  final alarmId = data['sharedItemId'] ?? data['alarmId'] ?? '';
  final alarmTime = data['alarmTime'] ?? data['newAlarmTime'] ?? '';

  SharedAlarmLogger.notificationReceived(
    alarmId: alarmId,
    alarmTime: alarmTime,
    appState: 'background',
    payloadVersion: int.tryParse(data['payloadVersion'] ?? ''),
  );

  if (type == 'sharedAlarm' || type == 'sharedItem') {
    // Persist the incoming alarm so it's available when the app opens.
    await _persistPendingSharedAlarm(data);
  }
}

/// Stores a pending shared alarm in SharedPreferences so it survives
/// background/killed states and can be shown when the user opens the app.
Future<void> _persistPendingSharedAlarm(Map<String, dynamic> data) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingSharedAlarmsKey);
    final List<Map<String, dynamic>> pending = raw != null
        ? List<Map<String, dynamic>>.from(
            (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
          )
        : [];

    final alarmId = data['sharedItemId'] ?? data['alarmId'] ?? '';

    // De-duplicate by alarmId
    if (pending.any(
      (p) =>
          (p['sharedItemId'] ?? p['alarmId']) == alarmId && alarmId.isNotEmpty,
    )) {
      SharedAlarmLogger.duplicateDetected(alarmId: alarmId);
      return;
    }

    pending.add(Map<String, dynamic>.from(data));
    await prefs.setString(_kPendingSharedAlarmsKey, jsonEncode(pending));

    SharedAlarmLogger.pendingAlarmStored(
      alarmId: alarmId,
      totalPending: pending.length,
    );
  } catch (e) {
    SharedAlarmLogger.log('PERSIST_FAILED', error: e.toString());
  }
}

// ─── PushNotifications class ─────────────────────────────────────────────────

class PushNotifications {
  Future<void> initFirebaseMessaging() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Request permissions with better error handling
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint(
        '🔔 Notification permission status: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('❌ User denied notification permissions');
        return;
      }

      // Get token with retry mechanism
      String? token = await _getTokenWithRetry();
      if (token != null) {
        debugPrint('✅ FCM Token obtained: ${token.substring(0, 20)}...');
        await updateToken(token);
      } else {
        debugPrint('❌ Failed to get FCM token after retries');
      }

      // Listen for token updates with error handling
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) async {
          debugPrint('🔄 FCM Token refreshed: ${token.substring(0, 20)}...');
          await updateToken(token);
        },
        onError: (error) {
          debugPrint('❌ Error during token refresh: $error');
        },
      );

      // ── Foreground notifications ───────────────────────────────────────
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final data = message.data;
        final type = data['type'] ?? '';

        SharedAlarmLogger.notificationReceived(
          alarmId: data['sharedItemId'] ?? data['alarmId'] ?? '',
          alarmTime: data['alarmTime'] ?? data['newAlarmTime'] ?? '',
          appState: 'foreground',
          payloadVersion: int.tryParse(data['payloadVersion'] ?? ''),
        );

        if (type == 'sharedAlarm' || type == 'sharedItem') {
          await _showSharedAlarmNotification(message);
        } else if (data['silent'] == 'false') {
          await _showNotification(message);
        }
      });

      // ── Background handler registration ────────────────────────────────
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // ── User taps notification (app was in background) ─────────────────
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        SharedAlarmLogger.notificationTapped(
          alarmId:
              message.data['sharedItemId'] ?? message.data['alarmId'] ?? '',
          source: 'system_notification',
        );
        _handleMessageNavigation(message);
      });

      // ── Cold-start: app launched by tapping a notification ─────────────
      RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        final data = initialMessage.data;
        SharedAlarmLogger.coldStartHandled(
          alarmId: data['sharedItemId'] ?? data['alarmId'] ?? '',
          alarmTime: data['alarmTime'] ?? data['newAlarmTime'] ?? '',
        );
        // Persist the alarm so the Notifications page can show it
        if (data['type'] == 'sharedAlarm' || data['type'] == 'sharedItem') {
          await _persistPendingSharedAlarm(data);
        }
        // Defer navigation until the widget tree is ready
        Future.delayed(const Duration(seconds: 2), () {
          _handleMessageNavigation(initialMessage);
        });
      }

      await _initLocalNotifications();

      debugPrint('✅ Firebase messaging initialization completed');
    } catch (e) {
      debugPrint('❌ Error initializing Firebase messaging: $e');
      // Don't rethrow - allow app to continue even if messaging init fails
    }
  }

  // ── Token management ───────────────────────────────────────────────────

  Future<String?> _getTokenWithRetry({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          return token;
        }
      } catch (e) {
        debugPrint('❌ Attempt ${i + 1} failed to get FCM token: $e');
      }

      if (i < maxRetries - 1) {
        await Future.delayed(
          Duration(seconds: 2 * (i + 1)),
        ); // Exponential backoff
      }
    }
    return null;
  }

  Future updateToken(String token) async {
    try {
      // Check if user is logged in before updating token
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        debugPrint('🔄 Updating FCM token for user: ${currentUser.uid}');
        await FirestoreDb.updateToken(token);
        debugPrint('✅ FCM token updated successfully');
      } else {
        debugPrint('❌ User not logged in. Token update skipped.');
        // Store token locally for when user logs in
        await _storeTokenLocally(token);
      }
    } catch (e) {
      debugPrint('❌ Error updating token: $e');
      // Retry token update after delay
      Future.delayed(const Duration(seconds: 30), () {
        updateToken(token);
      });
    }
  }

  Future<void> _storeTokenLocally(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingFcmTokenKey, token);
      debugPrint('📱 FCM token stored locally for later update');
    } catch (e) {
      debugPrint('❌ Error storing token locally: $e');
    }
  }

  Future<void> updateStoredTokenIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(_kPendingFcmTokenKey);

      if (storedToken != null && FirebaseAuth.instance.currentUser != null) {
        debugPrint('🔄 Updating previously stored FCM token');
        await updateToken(storedToken);
        await prefs.remove(_kPendingFcmTokenKey);
      }
    } catch (e) {
      debugPrint('❌ Error updating stored token: $e');
    }
  }

  // ── Local notification setup ───────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  /// Called when user taps or interacts with a local notification.
  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    SharedAlarmLogger.log(
      'LOCAL_NOTIFICATION_RESPONSE',
      details: {
        'actionId': actionId,
        'hasPayload': payload != null,
      },
    );

    if (payload == null) return;

    // Navigate to the notifications page so the user can accept/decline
    try {
      Get.toNamed('/notifications');
      SharedAlarmLogger.notificationTapped(
        alarmId: '',
        source: 'local_notification_tap',
      );
    } catch (e) {
      // GetX may not be initialized if this fires very early
      SharedAlarmLogger.log('NAVIGATION_FAILED', error: e.toString());
    }
  }

  // ── Notification display ───────────────────────────────────────────────

  /// Shows a rich notification specifically for shared alarm requests.
  Future<void> _showSharedAlarmNotification(RemoteMessage message) async {
    final data = message.data;
    final alarmTime = data['alarmTime'] ?? data['newAlarmTime'] ?? '';
    final ownerName = data['ownerName'] ?? '';
    final title = message.notification?.title ?? '🔔 Shared Alarm!';
    final body = message.notification?.body ??
        '$ownerName shared an alarm for $alarmTime';

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _kSharedAlarmChannelId,
      _kSharedAlarmChannelName,
      channelDescription: _kSharedAlarmChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      message.notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(data),
    );
  }

  /// Shows a basic notification for non-alarm messages.
  Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'default_channel',
      'Default',
      channelDescription: 'Default channel for notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      message.notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      message.notification?.title ?? 'No Title',
      message.notification?.body ?? 'No body',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  // ── Navigation on notification tap ─────────────────────────────────────

  void _handleMessageNavigation(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';

    debugPrint('👆 User tapped notification: type=$type, data=$data');

    if (type == 'sharedAlarm' ||
        type == 'sharedItem' ||
        type == 'rescheduleAlarm') {
      // Navigate to the Notifications page so the user can accept/decline.
      try {
        Get.toNamed('/notifications');
      } catch (e) {
        debugPrint('❌ Navigation failed (GetX may not be ready): $e');
        // Will be picked up by the pending alarms check on next app open
      }
    }
  }

  // ── Pending shared alarms management ───────────────────────────────────

  /// Retrieves and clears any pending shared alarms that were received while
  /// the app was in background/killed state.
  static Future<List<Map<String, dynamic>>> consumePendingSharedAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingSharedAlarmsKey);
      if (raw == null) return [];

      final List<Map<String, dynamic>> pending =
          List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
      );

      // Clear after consumption
      await prefs.remove(_kPendingSharedAlarmsKey);

      SharedAlarmLogger.log(
        'PENDING_ALARMS_CONSUMED',
        details: {
          'count': pending.length,
        },
      );

      return pending;
    } catch (e) {
      SharedAlarmLogger.log('CONSUME_PENDING_FAILED', error: e.toString());
      return [];
    }
  }

  /// Checks if there are any pending shared alarms without consuming them.
  static Future<int> getPendingSharedAlarmCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingSharedAlarmsKey);
      if (raw == null) return 0;
      return (jsonDecode(raw) as List).length;
    } catch (e) {
      return 0;
    }
  }

  // ── Cloud Function calls ───────────────────────────────────────────────

  Future<void> triggerRescheduleAlarmNotification(
    String firestoreAlarmId,
  ) async {
    try {
      debugPrint(
        '🔔 Attempting to trigger reschedule notification for alarm: '
        '$firestoreAlarmId',
      );

      var userModel = await SecureStorageProvider().retrieveUserModel();
      if (userModel == null) {
        debugPrint(
          '❌ No user model found, cannot send reschedule notification',
        );
        return;
      }

      debugPrint('📤 Calling rescheduleAlarm cloud function with data:');
      debugPrint('   - firestoreAlarmId: $firestoreAlarmId');
      debugPrint('   - changedByUserId: ${userModel.id}');

      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('rescheduleAlarm');

      final response = await callable.call({
        'firestoreAlarmId': firestoreAlarmId,
        'changedByUserId': userModel.id,
      });

      debugPrint('✅ Successfully triggered reschedule notification');
      debugPrint('   Response: ${response.data}');
    } catch (e) {
      debugPrint('❌ Error calling reschedule function: $e');
      debugPrint(
        '   This means the Firebase Cloud Function is not working properly.',
      );
      debugPrint('   The local alarm updates should still work correctly.');
    }
  }

  Future<void> triggerSharedItemNotification(
    List<String> receivingUserIds, {
    Map<String, dynamic>? sharedItem,
  }) async {
    await _sendNotificationWithRetry(
      receivingUserIds,
      sharedItem: sharedItem,
    );
  }

  Future<void> _sendNotificationWithRetry(
    List<String> receivingUserIds, {
    Map<String, dynamic>? sharedItem,
    int maxRetries = 3,
  }) async {
    // Get user model outside try block so it's accessible in catch
    final userModel = await SecureStorageProvider().retrieveUserModel();
    if (userModel == null) {
      debugPrint(
        '❌ No user model found, cannot send shared item notification',
      );
      return;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
          '🔔 Attempt $attempt: Sending shared item notification to '
          '${receivingUserIds.length} users',
        );
        debugPrint('📦 Shared item data: $sharedItem');

        debugPrint('👤 Sender: ${userModel.fullName} (${userModel.email})');
        debugPrint('👥 Recipients: $receivingUserIds');

        final HttpsCallable callable =
            FirebaseFunctions.instance.httpsCallable('sendNotification');

        final response = await callable.call({
          'receivingUserIds': receivingUserIds,
          'message': '${userModel.fullName} has shared an alarm with you!',
          'sharedItem': sharedItem,
        });

        final responseData = response.data;

        debugPrint('📊 Notification response: $responseData');

        if (responseData['success'] == true) {
          debugPrint('✅ Shared item notification sent successfully!');
          debugPrint(
            '   Success count: ${responseData['successCount']}',
          );
          debugPrint(
            '   Failure count: ${responseData['failureCount']}',
          );

          SharedAlarmLogger.notificationSent(
            alarmId: sharedItem?['id'] ?? '',
            alarmTime: sharedItem?['alarmTime'] ?? '',
            recipientCount: responseData['successCount'] ?? 0,
          );

          if (responseData['failedTokens'] != null &&
              responseData['failedTokens'].isNotEmpty) {
            debugPrint(
              '⚠️  Some tokens failed: ${responseData['failedTokens']}',
            );
          }

          return; // Success, exit retry loop
        } else {
          debugPrint('❌ Notification failed: ${responseData['message']}');
          debugPrint('   Failed tokens: ${responseData['failedTokens']}');
          debugPrint('   Failed sends: ${responseData['failedSends']}');

          if (attempt == maxRetries) {
            debugPrint(
              '❌ Max retry attempts reached. '
              'Notification sending failed.',
            );
            return;
          }
        }
      } catch (e) {
        debugPrint('❌ Attempt $attempt failed: $e');

        if (attempt == maxRetries) {
          debugPrint('❌ Max retry attempts reached. Error: $e');
          debugPrint(
            '   This means the Firebase Cloud Function is '
            'not working properly.',
          );
          debugPrint(
            '   Falling back to local notification storage...',
          );

          // Fallback: Store notification locally in Firestore for each recipient
          await _storeNotificationLocally(receivingUserIds, sharedItem, userModel);
          return;
        }

        // Exponential backoff
        final delay = Duration(seconds: 2 * attempt);
        debugPrint('⏳ Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      }
    }
  }

  Future<bool> sendDirectFCMMessage({
    required List<String> receivingUserIds,
    required String alarmId,
    required String newAlarmTime,
  }) async {
    try {
      debugPrint(
        '📤 Direct FCM messaging attempted for '
        '${receivingUserIds.length} users',
      );
      debugPrint('   - Alarm ID: $alarmId');
      debugPrint('   - New time: $newAlarmTime');

      debugPrint(
        '🔄 Using enhanced Firestore real-time sync instead of '
        'push notifications',
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error in direct FCM approach: $e');
      return false;
    }
  }

  // Debug method to check notification status
  Future<Map<String, dynamic>> checkNotificationStatus() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Check permissions
      final settings = await messaging.getNotificationSettings();

      // Get FCM token
      final token = await messaging.getToken();

      // Check if user is logged in
      final currentUser = FirebaseAuth.instance.currentUser;

      // Check stored token status
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString(_kPendingFcmTokenKey);

      // Check pending shared alarms
      final pendingCount = await PushNotifications.getPendingSharedAlarmCount();

      final status = {
        'permissions': {
          'authorizationStatus': settings.authorizationStatus.toString(),
          'alert': settings.alert.toString(),
          'badge': settings.badge.toString(),
          'sound': settings.sound.toString(),
        },
        'fcmToken': token != null ? '${token.substring(0, 20)}...' : null,
        'hasToken': token != null,
        'isUserLoggedIn': currentUser != null,
        'userId': currentUser?.uid,
        'userEmail': currentUser?.email,
        'hasPendingToken': storedToken != null,
        'pendingSharedAlarms': pendingCount,
        'timestamp': DateTime.now().toIso8601String(),
      };

      debugPrint('📊 Notification Status Check:');
      debugPrint('   Permissions: ${settings.authorizationStatus}');
      debugPrint('   Has FCM Token: ${token != null}');
      debugPrint('   User Logged In: ${currentUser != null}');
      debugPrint('   Pending Token: ${storedToken != null}');
      debugPrint('   Pending Shared Alarms: $pendingCount');

      return status;
    } catch (e) {
      debugPrint('❌ Error checking notification status: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Fallback: Store notification directly in Firestore for each recipient
  /// when Cloud Functions fail. This ensures users still receive the notification
  /// when they open the app.
  static Future<void> _storeNotificationLocally(
    List<String> receivingUserIds,
    Map<String, dynamic>? sharedItem,
    UserModel? sender,
  ) async {
    if (receivingUserIds.isEmpty || sharedItem == null || sender == null) return;

    try {
      debugPrint('📦 Storing shared alarm notification locally for ${receivingUserIds.length} users');

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // Create the notification item
      final notificationItem = {
        'type': 'alarm',
        'payloadVersion': 2,
        'id': sharedItem['id'] ?? sharedItem['firestoreId'] ?? sharedItem['alarmId'] ?? '',
        'firestoreId': sharedItem['firestoreId'],
        'AlarmName': sharedItem['alarmName'] ?? sharedItem['AlarmName'] ?? '',
        'alarmId': sharedItem['firestoreId'] ?? sharedItem['alarmId'] ?? '',
        'owner': sender.fullName ?? sender.email ?? 'Someone',
        'alarmTime': sharedItem['alarmTime'] ?? '',
        'alarmLabel': sharedItem['label'] ?? sharedItem['alarmLabel'] ?? '',
        'alarmRepeat': sharedItem['alarmRepeat'] ?? '',
        'alarmData': sharedItem,
        'sentAt': FieldValue.serverTimestamp(),
      };

      for (final userId in receivingUserIds) {
        try {
          final userRef = firestore.collection('users').doc(userId);
          batch.set(userRef, {
            'receivedItems': FieldValue.arrayUnion([notificationItem]),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('❌ Error adding notification to batch for user $userId: $e');
        }
      }

      await batch.commit();
      debugPrint('✅ Local notification storage completed for ${receivingUserIds.length} users');

      SharedAlarmLogger.log(
        'LOCAL_NOTIFICATION_STORED',
        details: {
          'recipientCount': receivingUserIds.length,
          'alarmId': sharedItem['id'] ?? '',
        },
      );
    } catch (e) {
      debugPrint('❌ Error storing notification locally: $e');
    }
  }
}
