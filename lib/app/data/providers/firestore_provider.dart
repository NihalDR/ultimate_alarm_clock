// ignore_for_file: lines_longer_than_80_chars, require_trailing_commas

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ultimate_alarm_clock/app/data/models/alarm_model.dart';
import 'package:ultimate_alarm_clock/app/data/models/user_model.dart';
import 'package:ultimate_alarm_clock/app/data/providers/isar_provider.dart';
import 'package:ultimate_alarm_clock/app/utils/shared_alarm_logger.dart';
import 'package:ultimate_alarm_clock/app/utils/utils.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ultimate_alarm_clock/app/data/providers/secure_storage_provider.dart';

import '../../modules/home/controllers/home_controller.dart';
import 'get_storage_provider.dart';

class FirestoreDb {
  static final FirebaseFirestore _firebaseFirestore =
      FirebaseFirestore.instance;

  static final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  static final _firebaseAuthInstance = FirebaseAuth.instance;

  static final storage = Get.find<GetStorageProvider>();

  Future<Database?> getSQLiteDatabase() async {
    Database? db;

    final dir = await getDatabasesPath();
    final dbPath = '$dir/alarms.db';
    debugPrint(dir);
    db = await openDatabase(
      dbPath,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return db;
  }

  void _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add weatherConditionType column
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN weatherConditionType INTEGER NOT NULL DEFAULT 2');
    }
    if (oldVersion < 3) {
      // Add activityConditionType column
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN activityConditionType INTEGER NOT NULL DEFAULT 2');
    }
    if (oldVersion < 4) {
      // Add sunrise alarm columns
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN isSunriseEnabled INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN sunriseDuration INTEGER NOT NULL DEFAULT 30');
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN sunriseIntensity REAL NOT NULL DEFAULT 1.0');
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN sunriseColorScheme INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      // Add timezone columns
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN timezoneId TEXT NOT NULL DEFAULT ""');
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN isTimezoneEnabled INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN targetTimezoneOffset INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 6) {
      // Add smart control combination type column
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN smartControlCombinationType INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 7) {
      // Add task list column
      await db.execute('ALTER TABLE alarms ADD COLUMN tasks TEXT');
    }
    if (oldVersion < 8) {
      // Add calendar event columns
      await db.execute('ALTER TABLE alarms ADD COLUMN calendarEventId TEXT');
      await db.execute('ALTER TABLE alarms ADD COLUMN calendarEventStart TEXT');
      await db
          .execute('ALTER TABLE alarms ADD COLUMN calendarEventUpdated TEXT');
      await db.execute('ALTER TABLE alarms ADD COLUMN calendarId TEXT');
      await db.execute(
          'ALTER TABLE alarms ADD COLUMN isCalendarEvent INTEGER NOT NULL DEFAULT 0');
    }
  }

  void _onCreate(Database db, int version) async {
    // Create tables for alarms and ringtones (modify column types as needed)
    await db.execute('''
      CREATE TABLE alarms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestoreId TEXT,
        alarmTime TEXT NOT NULL,
        alarmID TEXT NOT NULL UNIQUE,
        calendarEventId TEXT,
        calendarEventStart TEXT,
        calendarEventUpdated TEXT,
        calendarId TEXT,
        isCalendarEvent INTEGER NOT NULL DEFAULT 0,
        isEnabled INTEGER NOT NULL DEFAULT 1,
        isLocationEnabled INTEGER NOT NULL DEFAULT 0,
        locationConditionType INTEGER NOT NULL DEFAULT 2,
        isSharedAlarmEnabled INTEGER NOT NULL DEFAULT 0,
        isWeatherEnabled INTEGER NOT NULL DEFAULT 0,
        weatherConditionType INTEGER NOT NULL DEFAULT 2,
        activityConditionType INTEGER NOT NULL DEFAULT 2,
        location TEXT,
        activityInterval INTEGER,
        minutesSinceMidnight INTEGER NOT NULL,
        days TEXT NOT NULL,
        weatherTypes TEXT NOT NULL,
        isMathsEnabled INTEGER NOT NULL DEFAULT 0,
        mathsDifficulty INTEGER,
        numMathsQuestions INTEGER,
        isShakeEnabled INTEGER NOT NULL DEFAULT 0,
        shakeTimes INTEGER,
        isQrEnabled INTEGER NOT NULL DEFAULT 0,
        qrValue TEXT,
        isPedometerEnabled INTEGER NOT NULL DEFAULT 0,
        numberOfSteps INTEGER,
        intervalToAlarm INTEGER,
        isActivityEnabled INTEGER NOT NULL DEFAULT 0,
        sharedUserIds TEXT,
        ownerId TEXT NOT NULL,
        ownerName TEXT NOT NULL,
        lastEditedUserId TEXT,
        mutexLock INTEGER NOT NULL DEFAULT 0,
        mainAlarmTime TEXT,
        label TEXT,
        isOneTime INTEGER NOT NULL DEFAULT 0,
        snoozeDuration INTEGER,
        gradient INTEGER,
        ringtoneName TEXT,
        note TEXT,
        tasks TEXT,
        deleteAfterGoesOff INTEGER NOT NULL DEFAULT 0,
        showMotivationalQuote INTEGER NOT NULL DEFAULT 0,
        volMin REAL,
        volMax REAL,
        activityMonitor INTEGER,
        alarmDate TEXT NOT NULL DEFAULT "",
        profile TEXT NOT NULL,
        isGuardian INTEGER,
        guardianTimer INTEGER,
        guardian TEXT,
        isCall INTEGER,
        ringOn INTEGER,
        isSunriseEnabled INTEGER NOT NULL DEFAULT 0,
        sunriseDuration INTEGER NOT NULL DEFAULT 30,
        sunriseIntensity REAL NOT NULL DEFAULT 1.0,
        sunriseColorScheme INTEGER NOT NULL DEFAULT 0,
        timezoneId TEXT NOT NULL DEFAULT "",
        isTimezoneEnabled INTEGER NOT NULL DEFAULT 0,
        targetTimezoneOffset INTEGER NOT NULL DEFAULT 0,
        smartControlCombinationType INTEGER NOT NULL DEFAULT 0

      )
    ''');
    await db.execute('''
      CREATE TABLE ringtones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ringtoneName TEXT NOT NULL,
        ringtonePath TEXT NOT NULL,
        currentCounterOfUsage INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static CollectionReference _alarmsCollection(UserModel? user) {
    // Always use sharedAlarms collection since we're using shared alarm functionality
    return _firebaseFirestore.collection('sharedAlarms');
  }

  static Future<void> addUser(UserModel userModel) async {
    try {
      debugPrint('🔥 Attempting to add user to Firestore:');
      debugPrint('   - User ID: ${userModel.id}');
      debugPrint(
          '   - Firebase Auth User: ${_firebaseAuthInstance.currentUser?.uid}');
      debugPrint('   - User Email: ${userModel.email}');

      final DocumentReference docRef = _usersCollection.doc(userModel.id);
      final user = await docRef.get();

      if (!user.exists) {
        // Ensure receivedItems is initialized as an empty array
        Map<String, dynamic> userData = userModel.toJson();
        userData['receivedItems'] = userData['receivedItems'] ?? [];

        debugPrint('🔥 Creating new user document...');
        await docRef.set(userData);
        debugPrint(
            '✅ Created new user document with receivedItems: ${userModel.id}');
      } else {
        // Check if existing user has receivedItems field, add it if missing
        final data = user.data() as Map<String, dynamic>?;
        if (data != null && !data.containsKey('receivedItems')) {
          debugPrint('🔥 Adding receivedItems field to existing user...');
          await docRef.update({'receivedItems': []});
          debugPrint(
              '✅ Added receivedItems field to existing user: ${userModel.id}');
        } else {
          debugPrint(
              '✅ User document already exists with receivedItems: ${userModel.id}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error adding user to Firestore: $e');
      rethrow;
    }
  }

  static addAlarm(UserModel? user, AlarmModel alarmRecord) async {
    if (user == null) {
      return alarmRecord;
    }

    if (alarmRecord.isSharedAlarmEnabled) {
      // Create shared alarm in Firestore
      await _firebaseFirestore
          .collection('sharedAlarms')
          .add(AlarmModel.toMap(alarmRecord))
          .then((value) => alarmRecord.firestoreId = value.id);
      debugPrint(
          '✅ Created shared alarm in Firestore: ${alarmRecord.firestoreId}');

      // Detailed shared alarm creation log (NORMAL - always visible)
      String detailedMessage =
          IsarDb.buildDetailedAlarmCreationMessage(alarmRecord, 'SHARED');
      await IsarDb().insertLog(
        detailedMessage,
        status: Status.success,
        type: LogType.normal,
        ownerId: alarmRecord.ownerId,
        alarmId: alarmRecord.alarmID,
      );
    } else {
      // Create local alarm in SQLite
      final sql = await FirestoreDb().getSQLiteDatabase();
      try {
        // Try to insert with all fields including new columns
        await sql!
            .insert('alarms', alarmRecord.toSQFliteMap())
            .then((value) => debugPrint('insert success'));
      } catch (e) {
        if (e.toString().contains('locationConditionType') ||
            e.toString().contains('weatherConditionType') ||
            e.toString().contains('activityConditionType') ||
            e.toString().contains('isSunriseEnabled') ||
            e.toString().contains('sunriseDuration') ||
            e.toString().contains('sunriseIntensity') ||
            e.toString().contains('sunriseColorScheme') ||
            e.toString().contains('smartControlCombinationType') ||
            e.toString().contains('timezoneId') ||
            e.toString().contains('isTimezoneEnabled') ||
            e.toString().contains('targetTimezoneOffset')) {
          // If new columns don't exist, insert without them for backward compatibility
          Map<String, dynamic> fallbackMap =
              Map.from(alarmRecord.toSQFliteMap());
          fallbackMap.remove('locationConditionType');
          fallbackMap.remove('weatherConditionType');
          fallbackMap.remove('activityConditionType');
          fallbackMap.remove('isSunriseEnabled');
          fallbackMap.remove('sunriseDuration');
          fallbackMap.remove('sunriseIntensity');
          fallbackMap.remove('sunriseColorScheme');
          fallbackMap.remove('smartControlCombinationType');
          fallbackMap.remove('timezoneId');
          fallbackMap.remove('isTimezoneEnabled');
          fallbackMap.remove('targetTimezoneOffset');
          await sql!.insert('alarms', fallbackMap).then(
                (value) =>
                    debugPrint('insert success (backward compatibility)'),
              );
        } else {
          rethrow; // Re-throw other errors
        }
      }
      debugPrint('✅ Created normal alarm in SQLite');
    }

    return alarmRecord;
  }

  static Future<UserModel?> fetchUserDetails(String userId) async {
    final DocumentSnapshot userSnapshot =
        await _usersCollection.doc(userId).get();

    if (userSnapshot.exists) {
      final UserModel user =
          UserModel.fromJson(userSnapshot.data() as Map<String, dynamic>);
      return user;
    }

    return null;
  }

  static Future<bool> doesAlarmExist(UserModel? user, String alarmID) async {
    QuerySnapshot snapshot = await _alarmsCollection(user)
        .where('alarmID', isEqualTo: alarmID)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  static Future<AlarmModel> getTriggeredAlarm(
    UserModel? user,
    String time,
  ) async {
    HomeController homeController = Get.find<HomeController>();
    if (user == null) return homeController.genFakeAlarmModel();
    QuerySnapshot snapshot = await _alarmsCollection(user)
        .where('isEnabled', isEqualTo: true)
        .where('alarmTime', isEqualTo: time)
        .get();

    List list = snapshot.docs.map((DocumentSnapshot document) {
      return AlarmModel.fromDocumentSnapshot(
        documentSnapshot: document,
        user: user,
      );
    }).toList();

    return list[0];
  }

  static Future<AlarmModel> getLatestAlarm(
    UserModel? user,
    AlarmModel alarmRecord,
    bool wantNextAlarm,
  ) async {
    if (user == null) {
      alarmRecord.minutesSinceMidnight = -1;
      return alarmRecord;
    }

    int nowInMinutes = 0;
    if (wantNextAlarm == true) {
      nowInMinutes = Utils.timeOfDayToInt(
        TimeOfDay(
          hour: TimeOfDay.now().hour,
          minute: TimeOfDay.now().minute + 1,
        ),
      );
    } else {
      nowInMinutes = Utils.timeOfDayToInt(
        TimeOfDay(
          hour: TimeOfDay.now().hour,
          minute: TimeOfDay.now().minute,
        ),
      );
    }

    late List<AlarmModel> alarms = [];

    QuerySnapshot snapshotSharedAlarms = await _firebaseFirestore
        .collection('sharedAlarms')
        .where('isEnabled', isEqualTo: true)
        .where(
          Filter.or(
            Filter('sharedUserIds', arrayContains: user.id),
            Filter('ownerId', isEqualTo: user.id),
          ),
        )
        .get();

    final sharedAlarms =
        snapshotSharedAlarms.docs.map((DocumentSnapshot document) {
      return AlarmModel.fromDocumentSnapshot(
        documentSnapshot: document,
        user: user,
      );
    }).toList();

    alarms.addAll(sharedAlarms);

    if (alarms.isEmpty) {
      alarmRecord.minutesSinceMidnight = -1;
      return alarmRecord;
    } else {
      // Get the closest alarm to the current time
      AlarmModel closestAlarm = alarms.reduce((a, b) {
        int aTimeUntilNextAlarm = a.minutesSinceMidnight - nowInMinutes;
        int bTimeUntilNextAlarm = b.minutesSinceMidnight - nowInMinutes;

        // Check if alarm repeats on any day
        bool aRepeats = a.days.any((day) => day);
        bool bRepeats = b.days.any((day) => day);

        // If alarm is one-time and has already passed, set time until
        // next alarm to next day
        if (!aRepeats && aTimeUntilNextAlarm < 0) {
          aTimeUntilNextAlarm += Duration.minutesPerDay;
        }
        if (!bRepeats && bTimeUntilNextAlarm < 0) {
          bTimeUntilNextAlarm += Duration.minutesPerDay;
        }

        // If alarm repeats on any day, find the next upcoming day
        if (aRepeats) {
          int currentDay = DateTime.now().weekday - 1;
          for (int i = 0; i < a.days.length; i++) {
            int dayIndex = (currentDay + i) % a.days.length;
            if (a.days[dayIndex]) {
              aTimeUntilNextAlarm += i * Duration.minutesPerDay;
              break;
            }
          }
        }

        if (bRepeats) {
          int currentDay = DateTime.now().weekday - 1;
          for (int i = 0; i < b.days.length; i++) {
            int dayIndex = (currentDay + i) % b.days.length;
            if (b.days[dayIndex]) {
              bTimeUntilNextAlarm += i * Duration.minutesPerDay;
              break;
            }
          }
        }

        return aTimeUntilNextAlarm < bTimeUntilNextAlarm ? a : b;
      });
      return closestAlarm;
    }
  }

  static updateAlarm(String? userId, AlarmModel alarmRecord) async {
    final sql = await FirestoreDb().getSQLiteDatabase();

    try {
      // Try to update with all fields including new columns
      await sql!.update(
        'alarms',
        alarmRecord.toSQFliteMap(),
        where: 'alarmID = ?',
        whereArgs: [alarmRecord.alarmID],
      );
    } catch (e) {
      if (e.toString().contains('locationConditionType') ||
          e.toString().contains('weatherConditionType') ||
          e.toString().contains('activityConditionType') ||
          e.toString().contains('smartControlCombinationType') ||
          e.toString().contains('timezoneId') ||
          e.toString().contains('isTimezoneEnabled') ||
          e.toString().contains('targetTimezoneOffset') ||
          e.toString().contains('isSunriseEnabled') ||
          e.toString().contains('sunriseDuration') ||
          e.toString().contains('sunriseIntensity') ||
          e.toString().contains('sunriseColorScheme') ||
          e.toString().contains('calendarEventId') ||
          e.toString().contains('calendarEventStart') ||
          e.toString().contains('calendarEventUpdated') ||
          e.toString().contains('calendarId') ||
          e.toString().contains('isCalendarEvent')) {
        Map<String, dynamic> fallbackMap = Map.from(alarmRecord.toSQFliteMap());
        fallbackMap.remove('locationConditionType');
        fallbackMap.remove('weatherConditionType');
        fallbackMap.remove('activityConditionType');
        fallbackMap.remove('smartControlCombinationType');
        fallbackMap.remove('timezoneId');
        fallbackMap.remove('isTimezoneEnabled');
        fallbackMap.remove('targetTimezoneOffset');
        fallbackMap.remove('isSunriseEnabled');
        fallbackMap.remove('sunriseDuration');
        fallbackMap.remove('sunriseIntensity');
        fallbackMap.remove('sunriseColorScheme');
        fallbackMap.remove('calendarEventId');
        fallbackMap.remove('calendarEventStart');
        fallbackMap.remove('calendarEventUpdated');
        fallbackMap.remove('calendarId');
        fallbackMap.remove('isCalendarEvent');
        await sql!.update(
          'alarms',
          fallbackMap,
          where: 'alarmID = ?',
          whereArgs: [alarmRecord.alarmID],
        );
        debugPrint(
            'Updated alarm without new columns (backward compatibility)');
      } else {
        rethrow;
      }
    }

    if (alarmRecord.isSharedAlarmEnabled &&
        alarmRecord.firestoreId != null &&
        alarmRecord.firestoreId!.isNotEmpty) {
      final alarmRef = _firebaseFirestore
          .collection('sharedAlarms')
          .doc(alarmRecord.firestoreId);

      try {
        final existingDoc = await alarmRef.get();
        if (existingDoc.exists) {
          final existingData = existingDoc.data() as Map<String, dynamic>;
          
          // Conflict detection: Check if alarm was modified by another user
          final existingTimestamp = existingData['lastEditedTimestamp'];
          final localTimestamp = alarmRecord.lastEditedTimestamp;
          
if (existingTimestamp != null && localTimestamp != null) {
            final existingTime = _timestampToMillis(existingTimestamp);
            final localTime = _timestampToMillis(localTimestamp);
            
            if (existingTime > localTime) {
              debugPrint('⚠️ Conflict detected: Alarm modified by another user');
              debugPrint('   Server time: $existingTime, Local time: $localTime');
              // Log conflict for monitoring
              SharedAlarmLogger.log(
                'ALARM_CONFLICT_DETECTED',
                details: {
                  'firestoreId': alarmRecord.firestoreId,
                  'serverTimestamp': existingTime,
                  'localTimestamp': localTime,
                },
              );
            }
          }

          final existingSharedUsers =
              List<String>.from(existingData['sharedUserIds'] ?? []);
          final mergedSharedUsers = <String>{
            ...existingSharedUsers,
            ...?alarmRecord.sharedUserIds,
          }.toList();
          alarmRecord.sharedUserIds = mergedSharedUsers;

          final existingOffsetDetailsRaw = existingData['offsetDetails'];
          alarmRecord.offsetDetails = _mergeOffsetDetails(
            alarmRecord.offsetDetails,
            existingOffsetDetailsRaw,
          );
        }
      } catch (e) {
        debugPrint('⚠️ Error merging shared alarm fields: $e');
      }

      // Update with server timestamp for conflict detection
      final updateData = AlarmModel.toMap(alarmRecord);
      updateData['lastEditedTimestamp'] = FieldValue.serverTimestamp();
      updateData['lastEditedUserId'] = _firebaseAuthInstance.currentUser?.uid ?? '';

      await alarmRef.update(updateData);
    }
  }

  static List<Map>? _mergeOffsetDetails(
    List<Map>? incoming,
    dynamic existingRaw,
  ) {
    final mergedByUser = <String, Map<String, dynamic>>{};

    void addEntry(Map<String, dynamic> entry) {
      final userId = entry['userId']?.toString();
      if (userId == null || userId.isEmpty) return;
      mergedByUser[userId] = Map<String, dynamic>.from(entry);
    }

    if (existingRaw is Map) {
      final existingMap = Map<String, dynamic>.from(existingRaw);
      for (final entry in existingMap.entries) {
        final entryData = Map<String, dynamic>.from(entry.value ?? {});
        entryData['userId'] = entry.key;
        addEntry(entryData);
      }
    } else if (existingRaw is List) {
      for (final item in existingRaw) {
        if (item is Map) {
          addEntry(Map<String, dynamic>.from(item));
        }
      }
    }

    if (incoming != null) {
      for (final item in incoming) {
        addEntry(Map<String, dynamic>.from(item));
      }
    }

    if (mergedByUser.isEmpty) return incoming;
    return mergedByUser.values.toList();
  }

  static Future<String> userExists(String email) async {
    final querySnapshot = await _firebaseFirestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data()['fullName'];
    }

    return 'error';
  }

  static shareProfile(List emails) async {
    final profileSet = await IsarDb.getProfileAlarms();
    final currentProfileName = await storage.readProfile();

    final currentUserEmail = _firebaseAuthInstance.currentUser!.email;
    profileSet['owner'] = currentUserEmail;
    Map sharedItem = {
      'type': 'profile',
      'profileName': currentProfileName,
      'owner': currentUserEmail
    };
    await _firebaseFirestore
        .collection('users')
        .doc(currentUserEmail)
        .collection('sharedProfile')
        .doc(currentProfileName)
        .set(profileSet)
        .then((v) {
      Get.snackbar('Notification', 'Item Shared!');
    });
    for (final email in emails) {
      await _firebaseFirestore.collection('users').doc(email).update({
        'receivedItems': FieldValue.arrayUnion([sharedItem])
      });
    }
  }

  static Future<List<String>> getUserIdsByEmails(List emails) async {
    List<String> userIds = [];

    const batchSize = 10;
    for (int i = 0; i < emails.length; i += batchSize) {
      final batch = emails.sublist(
          i, i + batchSize > emails.length ? emails.length : i + batchSize);
      final querySnapshot = await _firebaseFirestore
          .collection('users')
          .where('email', whereIn: batch)
          .get();

      for (var doc in querySnapshot.docs) {
        userIds.add(doc.id);
      }
    }

    return userIds;
  }

  static Future<void> shareAlarm(List emails, AlarmModel alarm) async {
    debugPrint('🚀 shareAlarm called with ${emails.length} emails');

    if (emails.isEmpty) {
      debugPrint('❌ No emails provided for sharing');
      return;
    }

    final currentUserEmail = _firebaseAuthInstance.currentUser!.email;
    final currentUserId = _firebaseAuthInstance.currentUser!.uid;

    debugPrint('👤 Current user: $currentUserEmail (ID: $currentUserId)');

    // Get current user's name for the notification
    String ownerName = currentUserEmail ?? 'Someone';
    try {
      final currentUserDoc =
          await _firebaseFirestore.collection('users').doc(currentUserId).get();
      if (currentUserDoc.exists) {
        final userData = currentUserDoc.data() as Map<String, dynamic>;
        ownerName = userData['fullName'] ?? currentUserEmail ?? 'Someone';
        debugPrint('✅ Found owner name: $ownerName');
      }
    } catch (e) {
      debugPrint('❌ Could not fetch owner name: $e');
    }

    alarm.profile = 'Default';
    await _ensureSharedAlarmDocument(alarm);
    final alarmData = AlarmModel.toMap(alarm);
    Map sharedItem = {
      'type': 'alarm',
      'payloadVersion': 2,
      'id': alarm.firestoreId ?? alarm.alarmID,
      'firestoreId': alarm.firestoreId,
      'AlarmName': alarm.alarmID,
      'alarmId': alarm.firestoreId ?? alarm.alarmID,
      'owner': ownerName,
      'alarmTime': alarm.alarmTime,
      'alarmLabel': alarm.label,
      'alarmRepeat': Utils.getRepeatDays(alarm.days),
      'alarmData': alarmData,
    };

    // Persist shared alarm data for backward compatibility
    await _firebaseFirestore
        .collection('users')
        .doc(currentUserEmail)
        .collection('sharedAlarms')
        .doc(alarm.alarmID)
        .set(alarmData);

    debugPrint('🔄 Sharing alarm with ${emails.length} users');
    debugPrint('   - Alarm ID: ${alarm.alarmID}');
    debugPrint('   - Alarm Time: ${alarm.alarmTime}');
    debugPrint('   - Owner: $ownerName');
    debugPrint('   - Recipients: $emails');
    debugPrint('   - Shared item: $sharedItem');

    try {
      int successCount = 0;
      for (int i = 0; i < emails.length; i++) {
        final email = emails[i];
        debugPrint('📧 Processing recipient ${i + 1}/${emails.length}: $email');

        try {
          bool success = await addItemToUserByEmail(email, sharedItem);
          if (success) {
            successCount++;
            debugPrint('✅ Successfully shared alarm with $email');
          } else {
            debugPrint('❌ Failed to share alarm with $email - user not found');
          }
        } catch (e) {
          debugPrint('❌ Error sharing alarm with $email: $e');
        }
      }

      if (successCount > 0) {
        debugPrint(
            '✅ Alarm shared successfully with $successCount/${emails.length} recipients');
      } else {
        debugPrint('❌ Failed to share alarm with any recipients');
      }
    } catch (e) {
      debugPrint('❌ Error in shareAlarm: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  static Future<bool> addItemToUserByEmail(
      String email, dynamic sharedItem) async {
    try {
      debugPrint('🔍 Looking up user by email: $email');
      final querySnapshot = await _firebaseFirestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final docId = querySnapshot.docs.first.id;
        final userData = querySnapshot.docs.first.data();
        debugPrint('✅ Found user: ${userData['fullName']} (ID: $docId)');
        debugPrint('📦 Current receivedItems: ${userData['receivedItems']}');
        debugPrint('📦 Adding shared item to receivedItems: $sharedItem');

        // Verify the document update
        await _firebaseFirestore.collection('users').doc(docId).update({
          'receivedItems': FieldValue.arrayUnion([sharedItem])
        });

        // Verify the update was successful
        final updatedDoc =
            await _firebaseFirestore.collection('users').doc(docId).get();
        final updatedData = updatedDoc.data() as Map<String, dynamic>;
        debugPrint('✅ Updated receivedItems: ${updatedData['receivedItems']}');
        debugPrint('✅ Successfully added shared item to user $email');
        return true;
      } else {
        debugPrint('❌ User not found with email: $email');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error adding item to user $email: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  static Future receiveProfile(String email, String profileName) async {
    final profile = await _firebaseFirestore
        .collection('users')
        .doc(email)
        .collection('sharedProfile')
        .doc(profileName)
        .get();
    return profile.data();
  }

  static Future receiveAlarm(String ownerId, String alarmId) async {
    if (alarmId.trim().isEmpty) {
      return null;
    }

    final alarmByDocId =
        await _firebaseFirestore.collection('sharedAlarms').doc(alarmId).get();
    if (alarmByDocId.exists) {
      final data = alarmByDocId.data();
      if (data != null) {
        return {
          ...data,
          'firestoreId': alarmByDocId.id,
        };
      }
    }

    final alarmByAlarmId = await _firebaseFirestore
        .collection('sharedAlarms')
        .where('alarmID', isEqualTo: alarmId)
        .limit(1)
        .get();
    if (alarmByAlarmId.docs.isNotEmpty) {
      final document = alarmByAlarmId.docs.first;
      return {
        ...document.data(),
        'firestoreId': document.id,
      };
    }

    return null;
  }

  static Future<void> deleteOneTimeAlarm(
    String? ownerId,
    String? firestoreId,
  ) async {
    try {
      // Delete alarm remotely (from Firestore)
      await FirebaseFirestore.instance
          .collection('sharedAlarms')
          .doc(firestoreId)
          .delete();

      final sql = await FirestoreDb().getSQLiteDatabase();
      await sql!
          .delete('alarms', where: 'firestoreId = ?', whereArgs: [firestoreId]);

      debugPrint('Alarm deleted successfully from Firestore.');
    } catch (e) {
      debugPrint('Error deleting alarm from Firestore: $e');
    }
  }

  static Future<void> markSharedAlarmDismissedByUser(
    String firestoreId,
    String userId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('sharedAlarms')
          .doc(firestoreId)
          .update({
        'dismissedByUsers': FieldValue.arrayUnion([userId]),
        'lastDismissedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Marked shared alarm as dismissed by user: $userId');

      final alarmDoc = await FirebaseFirestore.instance
          .collection('sharedAlarms')
          .doc(firestoreId)
          .get();

      if (alarmDoc.exists) {
        final data = alarmDoc.data() as Map<String, dynamic>;
        final sharedUserIds = List<String>.from(data['sharedUserIds'] ?? []);
        final ownerId = data['ownerId'] as String?;
        final dismissedByUsers =
            List<String>.from(data['dismissedByUsers'] ?? []);

        final offsetDetailsRaw = data['offsetDetails'];
        final Set<String> acceptedUsers = <String>{};

        if (offsetDetailsRaw is Map) {
          final offsetDetails = Map<String, dynamic>.from(offsetDetailsRaw);
          acceptedUsers.addAll(offsetDetails.keys.cast<String>());
        } else if (offsetDetailsRaw is List) {
          final offsetDetailsList = List<dynamic>.from(offsetDetailsRaw);
          for (final item in offsetDetailsList) {
            if (item is Map && item.containsKey('userId')) {
              acceptedUsers.add(item['userId'].toString());
            }
          }
        }

        final allUsers = <String>{};
        if (ownerId != null) {
          allUsers.add(ownerId);
        }

        allUsers.addAll(acceptedUsers);

        debugPrint('🔍 Dismissal check for alarm $firestoreId:');
        debugPrint('   - sharedUserIds (invited): $sharedUserIds');
        debugPrint(
            '   - acceptedUsers (from offsetDetails): ${acceptedUsers.toList()}');
        debugPrint('   - ownerId: $ownerId');
        debugPrint('   - dismissedByUsers: $dismissedByUsers');
        debugPrint('   - allUsers (who actually have the alarm): $allUsers');
        debugPrint('   - dismissedByUsers.length: ${dismissedByUsers.length}');
        debugPrint('   - allUsers.length: ${allUsers.length}');

        if (dismissedByUsers.length >= allUsers.length) {
          await FirebaseFirestore.instance
              .collection('sharedAlarms')
              .doc(firestoreId)
              .delete();
          debugPrint(
              '✅ All users who have the alarm dismissed it - deleted shared alarm completely: $firestoreId');
        } else {
          debugPrint(
              '⏳ Not all users who have the alarm have dismissed yet - keeping alarm: $firestoreId');
        }
      }
    } catch (e) {
      debugPrint('Error marking shared alarm as dismissed by user: $e');
    }
  }

  static Future<AlarmModel?> getAlarm(UserModel? user, String id) async {
    if (user == null) return null;

    final document = await _alarmsCollection(user).doc(id).get();
    if (!document.exists) {
      return null;
    }

    return AlarmModel.fromDocumentSnapshot(
      documentSnapshot: document,
      user: user,
    );
  }

  // static Stream<QuerySnapshot<Object?>> getAlarms(UserModel? user) {
  //   return _alarmsCollection(user)
  //       .orderBy('minutesSinceMidnight', descending: false)
  //       .snapshots();
  // }

static Stream<QuerySnapshot<Object?>> getSharedAlarms(UserModel? user) {
    final userId = user?.id;
    if (user != null && userId != null && userId.isNotEmpty) {
      Stream<QuerySnapshot<Object?>> sharedAlarmsStream = _firebaseFirestore
          .collection('sharedAlarms')
          .where(
            Filter.or(
              Filter('sharedUserIds', arrayContains: userId),
              Filter('ownerId', isEqualTo: userId),
            ),
          )
          .snapshots();

      return sharedAlarmsStream;
    } else {
      // Return a stream that emits from an empty collection to provide a proper QuerySnapshot
      // This prevents the StreamBuilder from hanging on loading
      return _firebaseFirestore
          .collection('_empty_shared_alarms_placeholder')
          .limit(0)
          .snapshots();
}
  }

  static Stream<QuerySnapshot<Object?>> getAlarms(UserModel? user) {
    final userId = user?.id;
    if (user != null && userId != null && userId.isNotEmpty) {
      Stream<QuerySnapshot<Object?>> userAlarmsStream = _alarmsCollection(user)
          .where(
            Filter.or(
              Filter('sharedUserIds', arrayContains: userId),
              Filter('ownerId', isEqualTo: userId),
            ),
          )
          .snapshots(includeMetadataChanges: true);

      return userAlarmsStream;
    } else {
      return _alarmsCollection(user)
          .orderBy('minutesSinceMidnight', descending: false)
          .snapshots();
    }
  }

  static deleteAlarm(UserModel? user, String id) async {
    if (user == null) return;

    try {
      await _firebaseFirestore.collection('sharedAlarms').doc(id).delete();

      final sql = await FirestoreDb().getSQLiteDatabase();
      await sql!.delete('alarms', where: 'firestoreId = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Error deleting alarm: $e');
    }
  }

  /// Removes the current user from a shared alarm's sharedUserIds array.
  /// This allows other users to keep the alarm while only removing it for the current user.
  /// If the current user is the owner, the entire alarm is deleted.
  static Future<void> removeUserFromSharedAlarm(UserModel? user, String firestoreId) async {
    if (user == null) return;

    try {
      final alarmRef = _firebaseFirestore.collection('sharedAlarms').doc(firestoreId);
      final alarmDoc = await alarmRef.get();

      if (!alarmDoc.exists) {
        debugPrint('❌ Shared alarm not found: $firestoreId');
        return;
      }

      final data = alarmDoc.data() as Map<String, dynamic>;
      final ownerId = data['ownerId'] as String?;
      final sharedUserIds = List<String>.from(data['sharedUserIds'] ?? []);

      // If current user is the owner, delete the entire alarm
      if (ownerId == user.id) {
        debugPrint('🗑️ Owner deleting shared alarm: $firestoreId');
        await alarmRef.delete();

        final sql = await FirestoreDb().getSQLiteDatabase();
        await sql!.delete('alarms', where: 'firestoreId = ?', whereArgs: [firestoreId]);
        return;
      }

      // Otherwise, remove only the current user from sharedUserIds
      if (sharedUserIds.contains(user.id)) {
        debugPrint('👤 Removing user ${user.id} from shared alarm: $firestoreId');
        await alarmRef.update({
          'sharedUserIds': FieldValue.arrayRemove([user.id]),
        });

        // Also remove user's offset details if present
        final offsetDetailsRaw = data['offsetDetails'];
        if (offsetDetailsRaw is Map) {
          final offsetDetails = Map<String, dynamic>.from(offsetDetailsRaw);
          offsetDetails.remove(user.id);
          await alarmRef.update({'offsetDetails': offsetDetails});
        }

        // If no more shared users, delete the alarm
        final updatedSharedUsers = List<String>.from(sharedUserIds)..remove(user.id);
        if (updatedSharedUsers.isEmpty) {
          debugPrint('🗑️ No more shared users, deleting alarm: $firestoreId');
          await alarmRef.delete();

          final sql = await FirestoreDb().getSQLiteDatabase();
          await sql!.delete('alarms', where: 'firestoreId = ?', whereArgs: [firestoreId]);
        }
      } else {
        debugPrint('⚠️ User ${user.id} not in sharedUserIds for alarm: $firestoreId');
      }
    } catch (e) {
      debugPrint('❌ Error removing user from shared alarm: $e');
      rethrow;
    }
  }

  /// Adds a user back to a shared alarm (for undo functionality).
  /// Uses the sharedAlarms collection directly.
  static Future<bool> addUserBackToSharedAlarm(UserModel? user, String firestoreId) async {
    if (user == null) return false;

    try {
      final alarmRef = _firebaseFirestore.collection('sharedAlarms').doc(firestoreId);
      final alarmDoc = await alarmRef.get();

      if (!alarmDoc.exists) {
        debugPrint('❌ Shared alarm not found for undo: $firestoreId');
        return false;
      }

      final data = alarmDoc.data() as Map<String, dynamic>;
      final ownerId = data['ownerId'] as String?;
      final sharedUserIds = List<String>.from(data['sharedUserIds'] ?? []);

      // If current user is the owner, they can't "re-add" themselves
      if (ownerId == user.id) {
        debugPrint('⚠️ Owner cannot re-add themselves: $firestoreId');
        return false;
      }

      if (!sharedUserIds.contains(user.id)) {
        debugPrint('↩️ Adding user ${user.id} back to shared alarm: $firestoreId');
        final offsetDetailsRaw = data['offsetDetails'];
        Map<String, dynamic> offsetDetails = {};
        if (offsetDetailsRaw is Map) {
          offsetDetails = Map<String, dynamic>.from(offsetDetailsRaw);
        }
        
        // Add user with default offset (no offset)
        offsetDetails[user.id] = {
          'isOffsetBefore': true,
          'offsetDuration': 0,
          'offsettedTime': data['alarmTime'],
        };

        await alarmRef.update({
          'sharedUserIds': FieldValue.arrayUnion([user.id]),
          'offsetDetails': offsetDetails,
        });
        return true;
      } else {
        debugPrint('⚠️ User ${user.id} already in sharedUserIds for alarm: $firestoreId');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error adding user back to shared alarm: $e');
      return false;
    }
  }

  static addUserToAlarmSharedUsers(UserModel? userModel, String alarmID) async {
    String userModelId = userModel!.id;

    final alarmQuerySnapshot = await _firebaseFirestore
        .collectionGroup('alarms')
        .where('alarmID', isEqualTo: alarmID)
        .get();

    if (alarmQuerySnapshot.size == 0) {
      return false;
    }
    final alarmDoc = alarmQuerySnapshot.docs[0];

    if (alarmDoc.data()['ownerId'] == userModelId) {
      return null;
    }

    final sharedUserIds =
        List<String>.from(alarmDoc.data()['sharedUserIds'] ?? []);
    final offsetDetails =
        Map<String, dynamic>.from(alarmDoc.data()['offsetDetails'] ?? {});

    offsetDetails[userModelId] = {
      'isOffsetBefore': true,
      'offsetDuration': 0,
      'offsettedTime': alarmDoc.data()['alarmTime'],
    };

    if (!sharedUserIds.contains(userModelId)) {
      sharedUserIds.add(userModelId);
      await alarmDoc.reference.update(
        {'sharedUserIds': sharedUserIds, 'offsetDetails': offsetDetails},
      );
    }
    return true;
  }

  static Future<List<String>> removeUserFromAlarmSharedUsers(
    UserModel? userModel,
    String alarmID,
  ) async {
    String userModelId = userModel!.id;

    final alarmQuerySnapshot = await _firebaseFirestore
        .collection('alarms')
        .where('alarmID', isEqualTo: alarmID)
        .get();

    if (alarmQuerySnapshot.size == 0) {
      return []; // Return an empty list if the alarm is not found
    }

    final alarmDoc = alarmQuerySnapshot.docs[0];
    final sharedUserIds =
        List<String>.from(alarmDoc.data()['sharedUserIds'] ?? []);

    if (sharedUserIds.contains(userModelId)) {
      sharedUserIds.remove(userModelId); // Remove the userId from the list
      await alarmDoc.reference.update({'sharedUserIds': sharedUserIds});
    }

    return sharedUserIds; // Return the updated sharedUserIds list
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>>
      getNotifications() async* {
    // Check if user is authenticated
    if (_firebaseAuthInstance.currentUser == null) {
      // Return empty stream that never emits anything for unauthenticated users
      return;
    }

    Stream<DocumentSnapshot<Map<String, dynamic>>> userNotifications =
        _firebaseFirestore
            .collection('users')
            .doc(_firebaseAuthInstance.currentUser!.uid)
            .snapshots();

    yield* userNotifications;
  }

  static removeItem(Map item) async {
    debugPrint(item.toString());

    await _firebaseFirestore
        .collection('users')
        .doc(_firebaseAuthInstance.currentUser!.uid)
        .update({
      'receivedItems': FieldValue.arrayRemove([item])
    });
  }

  static updateToken(String token) async {
    try {
      if (_firebaseAuthInstance.currentUser != null) {
        await _firebaseFirestore
            .collection('users')
            .doc(_firebaseAuthInstance.currentUser!.uid)
            .update({'fcmToken': token});
      } else {
        debugPrint('No authenticated user found when updating FCM token');
      }
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  /// Checks whether the current user has already accepted a given shared alarm.
  static Future<bool> hasAlreadyAcceptedSharedAlarm(String? firestoreId) async {
    if (firestoreId == null || firestoreId.isEmpty) return false;
    final currentUserId = await _resolveSharedAlarmUserId();
    if (currentUserId == null) return false;

    try {
      final doc = await _firebaseFirestore
          .collection('sharedAlarms')
          .doc(firestoreId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>;
      final sharedUserIds = List<String>.from(data['sharedUserIds'] ?? []);
      return sharedUserIds.contains(currentUserId);
    } catch (e) {
      debugPrint('⚠️ Error checking acceptance status: $e');
      return false;
    }
  }

  static Future<String?> _resolveSharedAlarmUserId() async {
    try {
      final userModel = await SecureStorageProvider().retrieveUserModel();
      if (userModel != null && userModel.id.isNotEmpty) {
        return userModel.id;
      }
    } catch (e) {
      debugPrint('⚠️ Error resolving shared alarm user id: $e');
    }
    return _firebaseAuthInstance.currentUser?.uid;
  }

  static Future<String> _ensureSharedAlarmDocument(AlarmModel alarm) async {
    alarm.isSharedAlarmEnabled = true;
    final alarmData = AlarmModel.toMap(alarm);
    // Add server timestamp for conflict detection
    alarmData['lastEditedTimestamp'] = FieldValue.serverTimestamp();
    alarmData['lastEditedUserId'] = _firebaseAuthInstance.currentUser?.uid ?? '';

    if (alarm.firestoreId != null && alarm.firestoreId!.isNotEmpty) {
      await _firebaseFirestore
          .collection('sharedAlarms')
          .doc(alarm.firestoreId)
          .set(alarmData, SetOptions(merge: true));
      return alarm.firestoreId!;
    }

    final docRef =
        await _firebaseFirestore.collection('sharedAlarms').add(alarmData);
    alarm.firestoreId = docRef.id;
    await docRef.update({
      'firestoreId': docRef.id,
      'isSharedAlarmEnabled': true,
    });
    return docRef.id;
  }

  static acceptSharedAlarm(String alarmOwnerId, AlarmModel alarm,
      {String offsetDirection = 'before', int offsetMinutes = 0}) async {
    final currentUserId = await _resolveSharedAlarmUserId();
    if (currentUserId == null || currentUserId.isEmpty) {
      debugPrint('⚠️ No current user id available for shared alarm accept');
      return;
    }

    final ensuredFirestoreId = await _ensureSharedAlarmDocument(alarm);
    alarm.firestoreId = ensuredFirestoreId;

    // ── Duplicate-accept guard ───────────────────────────────────────────
    final alreadyAccepted =
        await hasAlreadyAcceptedSharedAlarm(ensuredFirestoreId);
    if (alreadyAccepted) {
      SharedAlarmLogger.duplicateDetected(alarmId: ensuredFirestoreId);
      debugPrint(
          '⚠️ User $currentUserId already accepted alarm ${alarm.firestoreId}, skipping');
      return;
    }

    final alarmDoc = await _firebaseFirestore
        .collection('sharedAlarms')
        .doc(ensuredFirestoreId)
        .get();

    if (alarmDoc.exists) {
      final data = alarmDoc.data() as Map<String, dynamic>;

      final offsetDetailsRaw = data['offsetDetails'];
      Map<String, dynamic> offsetDetails = {};

      if (offsetDetailsRaw is Map) {
        offsetDetails = Map<String, dynamic>.from(offsetDetailsRaw);
      } else if (offsetDetailsRaw is List) {
        final offsetDetailsList = List<dynamic>.from(offsetDetailsRaw);
        for (final item in offsetDetailsList) {
          if (item is Map && item.containsKey('userId')) {
            final userId = item['userId'].toString();
            offsetDetails[userId] = {
              'isOffsetBefore': item['isOffsetBefore'] ?? true,
              'offsetDuration': item['offsetDuration'] ?? 0,
              'offsettedTime': item['offsettedTime'] ?? alarm.alarmTime,
            };
          }
        }
        debugPrint('🔧 Converted offsetDetails from Array to Map format');
      }

      // Use the offset parameters passed from the UI
      final isOffsetBefore = offsetDirection == 'before';
      final effectiveOffsetDuration = isOffsetBefore ? -offsetMinutes : offsetMinutes;
      final mainTime = Utils.stringToTimeOfDay(alarm.alarmTime);
      DateTime mainDateTime = Utils.timeOfDayToDateTime(mainTime);
      final offsetDateTime = mainDateTime.add(Duration(minutes: effectiveOffsetDuration));
      final offsettedTime = Utils.formatDateTimeToHHMMSS(offsetDateTime);

      offsetDetails[currentUserId] = {
        'isOffsetBefore': isOffsetBefore,
        'offsetDuration': offsetMinutes,
        'offsettedTime': offsettedTime,
      };

      await _firebaseFirestore
          .collection('sharedAlarms')
          .doc(alarm.firestoreId)
          .update({
        'offsetDetails': offsetDetails,
        'sharedUserIds': FieldValue.arrayUnion([currentUserId]),
      });

      SharedAlarmLogger.alarmAccepted(
        alarmId: alarm.alarmID,
        alarmTime: alarm.alarmTime,
        firestoreId: alarm.firestoreId,
      );

      debugPrint(
          '✅ User $currentUserId accepted shared alarm with offset: ${offsetDirection} ${offsetMinutes}min');
    }
  }

  /// Declines a shared alarm and removes the notification item.
  static Future<void> declineSharedAlarm(
    String alarmOwnerId,
    AlarmModel alarm,
  ) async {
    try {
      SharedAlarmLogger.alarmDeclined(
        alarmId: alarm.alarmID,
        alarmTime: alarm.alarmTime,
      );

      debugPrint('❌ User declined shared alarm: ${alarm.firestoreId}');
    } catch (e) {
      debugPrint('❌ Error declining shared alarm: $e');
    }
  }

  static Future<AlarmModel> saveSharedAlarm(
      UserModel? user, AlarmModel alarmRecord) async {
    if (user == null) {
      return alarmRecord;
    }

    alarmRecord.isSharedAlarmEnabled = true;

    await _firebaseFirestore
        .collection('sharedAlarms')
        .add(AlarmModel.toMap(alarmRecord))
        .then((value) => alarmRecord.firestoreId = value.id);

    return alarmRecord;
  }

  static Future<void> triggerRescheduleUpdate(AlarmModel alarmData) async {
    try {
      await _firebaseFirestore
          .collection('sharedAlarms')
          .doc(alarmData.firestoreId)
          .update({
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastEditedUserId': _firebaseAuthInstance.currentUser?.uid,
        'alarmTime': alarmData.alarmTime,
        'minutesSinceMidnight': alarmData.minutesSinceMidnight,
        'isEnabled': alarmData.isEnabled,
      });

      debugPrint(
          '✅ Triggered Firestore update for shared alarm reschedule: ${alarmData.firestoreId}');
    } catch (e) {
      debugPrint('❌ Error triggering Firestore reschedule update: $e');
    }
  }

  static int _timestampToMillis(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate().millisecondsSinceEpoch;
    }
    if (timestamp is int) {
      return timestamp;
    }
    return 0;
  }
}
