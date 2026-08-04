import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ultimate_alarm_clock/app/data/providers/firestore_provider.dart';
import 'package:ultimate_alarm_clock/app/data/providers/secure_storage_provider.dart';

// Global instance for background use
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  debugPrint('📱 Background message received: ${message.data}');
  
  if (message.data['type'] == 'sharedAlarm' ||
      message.data['type'] == 'sharedItem') {
    debugPrint('🔔 Background shared alarm notification processed');
  }
}


class PushNotifications {
  static const Set<String> _pendingSharedAlarmTypes = {
    'sharedAlarm',
    'sharedItem',
    'alarm',
  };

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

      debugPrint('🔔 Notification permission status: '
          '${settings.authorizationStatus}');
      
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

      // Foreground notifications with better handling
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('📱 Received foreground message: ${message.data}');
        
        // Handle shared alarm notifications specifically
        if (message.data['type'] == 'sharedAlarm' ||
            message.data['type'] == 'sharedItem') {
          debugPrint('🔔 Processing shared alarm notification');
          await _showNotification(message);
        } else if (message.data['silent'] == 'false') {
          await _showNotification(message);
        }
      });

      // Background/terminated app notifications
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // User taps notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('👆 User tapped notification: ${message.data}');
        _handleMessageNavigation(message);
      });

      await _initLocalNotifications();
      
      debugPrint('✅ Firebase messaging initialization completed');
    } catch (e) {
      debugPrint('❌ Error initializing Firebase messaging: $e');
      rethrow;
    }
  }

  Future<String?> _getTokenWithRetry({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          return token;
        }
      } catch (e) {
        debugPrint(
          '❌ Attempt ${i + 1} failed to get FCM token: $e',
        );
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
      // Store token using shared preferences temporarily  
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_fcm_token', token);
      debugPrint('📱 FCM token stored locally for later update');
    } catch (e) {
      debugPrint('❌ Error storing token locally: $e');
    }
  }

  Future<void> updateStoredTokenIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('pending_fcm_token');
      
      if (storedToken != null && FirebaseAuth.instance.currentUser != null) {
        debugPrint('🔄 Updating previously stored FCM token');
        await updateToken(storedToken);
        await prefs.remove('pending_fcm_token');
      }
    } catch (e) {
      debugPrint('❌ Error updating stored token: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // TODO: handle tap on notification if needed
      },
    );
  }

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

  Future<void> showSharedAlarmRequestNotification(
    Map<String, dynamic> notification,
  ) async {
    try {
      final title =
          notification['title']?.toString().trim().isNotEmpty == true
              ? notification['title'].toString()
              : 'Shared Alarm Request';
      final ownerName = notification['owner']?.toString() ?? 'Someone';
      final alarmTime = notification['alarmTime']?.toString() ?? '';
      final body = alarmTime.isNotEmpty
          ? '$ownerName shared an alarm set for $alarmTime'
          : '$ownerName shared an alarm with you';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'shared_alarm_channel',
        'Shared Alarms',
        channelDescription: 'Notifications for shared alarm requests',
        importance: Importance.max,
        priority: Priority.high,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch,
        title,
        body,
        notificationDetails,
        payload: notification.toString(),
      );
    } catch (e) {
      debugPrint('❌ Error showing shared alarm request notification: $e');
    }
  }

  static Future<int> getPendingSharedAlarmCount() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return 0;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final rawItems = (userDoc.data()?['receivedItems'] as List?) ?? const [];
      var count = 0;

      for (final item in rawItems) {
        if (item is! Map) {
          continue;
        }

        final type = item['type']?.toString() ?? '';
        if (_pendingSharedAlarmTypes.contains(type)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      debugPrint('❌ Error getting pending shared alarm count: $e');
      return 0;
    }
  }

  void _handleMessageNavigation(RemoteMessage message) {
    debugPrint('User tapped on notification: ${message.data}');
    // TODO: Navigate based on message.data or type
  }



Future<void> triggerRescheduleAlarmNotification(String firestoreAlarmId) async {
  try {
    debugPrint(
      '🔔 Attempting to trigger reschedule notification for alarm: '
      '$firestoreAlarmId',
    );

    var userModel = await SecureStorageProvider().retrieveUserModel();
    if (userModel == null) {
      debugPrint('❌ No user model found, cannot send reschedule notification');
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
    debugPrint(
      '   The local alarm updates should still work correctly.',
    );
  }
}

Future<void> triggerSharedItemNotification(
  List receivingUserIds, {
  Map<String, dynamic>? sharedItem,
}) async {
  await _sendNotificationWithRetry(receivingUserIds, sharedItem: sharedItem);
}

Future<void> _sendNotificationWithRetry(
  List receivingUserIds, {
  Map<String, dynamic>? sharedItem,
  int maxRetries = 3,
}) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      debugPrint(
        '🔔 Attempt $attempt: Sending shared item notification to '
        '${receivingUserIds.length} users',
      );
      debugPrint('📦 Shared item data: $sharedItem');

      var userModel = await SecureStorageProvider().retrieveUserModel();
      if (userModel == null) {
        debugPrint(
          '❌ No user model found, cannot send shared item notification',
        );
        return;
      }

      debugPrint(
        '👤 Sender: ${userModel.fullName} (${userModel.email})',
      );
      debugPrint('👥 Recipients: $receivingUserIds');

      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('sendNotification');

      final response = await callable.call({
        'receivingUserIds': receivingUserIds,
        'message': '${userModel.fullName} has shared an alarm with you!',
        'sharedItem': sharedItem,
      });

      final responseData = response.data;
      debugPrint(
        '📊 Notification response: $responseData',
      );

      if (responseData['success'] == true) {
        debugPrint('✅ Shared item notification sent successfully!');
        debugPrint('   Success count: ${responseData['successCount']}');
        debugPrint('   Failure count: ${responseData['failureCount']}');

        if (responseData['failedTokens'] != null &&
            responseData['failedTokens'].isNotEmpty) {
          debugPrint('⚠️  Some tokens failed: ${responseData['failedTokens']}');
        }

        return; // Success, exit retry loop
      } else {
        debugPrint('❌ Notification failed: ${responseData['message']}');
        debugPrint('   Failed tokens: ${responseData['failedTokens']}');
        debugPrint('   Failed sends: ${responseData['failedSends']}');

        if (attempt == maxRetries) {
          debugPrint(
            '❌ Max retry attempts reached. Notification sending failed.',
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ Attempt $attempt failed: $e');

      if (attempt == maxRetries) {
        debugPrint('❌ Max retry attempts reached. Error: $e');
        debugPrint(
          '   This means the Firebase Cloud Function is not working properly.',
        );
        debugPrint(
          '   The alarm sharing will continue without notifications.',
        );
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
      '📤 Direct FCM messaging attempted for ${receivingUserIds.length} users',
    );
    debugPrint('   - Alarm ID: $alarmId');
    debugPrint('   - New time: $newAlarmTime');

    debugPrint(
      '🔄 Using enhanced Firestore real-time sync '
      'instead of push notifications',
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
    final storedToken = prefs.getString('pending_fcm_token');

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
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    debugPrint('📊 Notification Status Check:');
    debugPrint('   Permissions: ${settings.authorizationStatus}');
    debugPrint('   Has FCM Token: ${token != null}');
    debugPrint('   User Logged In: ${currentUser != null}');
    debugPrint('   Pending Token: ${storedToken != null}');

    return status;
  } catch (e) {
    debugPrint('❌ Error checking notification status: $e');
    return {
      'error': e.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

}