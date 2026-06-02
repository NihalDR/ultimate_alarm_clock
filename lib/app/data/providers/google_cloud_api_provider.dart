import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:ultimate_alarm_clock/app/data/providers/secure_storage_provider.dart';
import 'package:ultimate_alarm_clock/app/modules/home/controllers/home_controller.dart';
import 'package:ultimate_alarm_clock/app/modules/settings/controllers/settings_controller.dart';

import '../../utils/google_http_client.dart';
import '../models/user_model.dart';
import 'firestore_provider.dart';

class GoogleCloudProvider {
  static const String _webClientId =
      '570321397153-9a9karigj3uhd7k18aerbe3fg845f333.'
      'apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _webClientId,
    scopes: <String>[
      CalendarApi.calendarScope,
    ],
  );
  static final _firebaseAuthInstance = FirebaseAuth.instance;

  static getInstance() async {
    try {
      HomeController homeController = Get.find<HomeController>();
      Get.put(SettingsController());
      SettingsController settingsController = Get.find<SettingsController>();

      GoogleSignInAccount? googleSignInAccount =
          _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();

      googleSignInAccount ??= await _googleSignIn.signIn();

      // User cancelled the sign-in
      if (googleSignInAccount == null) {
        return null;
      }

      if (_firebaseAuthInstance.currentUser == null) {
        final googleAuth = await googleSignInAccount.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await _firebaseAuthInstance.signInWithCredential(credential);
        // Ensure the auth token is fresh before Firestore calls.
        await _firebaseAuthInstance.currentUser?.getIdToken(true);

        if (_firebaseAuthInstance.currentUser == null) {
          throw Exception('FirebaseAuth currentUser is null after sign-in.');
        }

        // Process successful sign-in
        String fullName = googleSignInAccount.displayName.toString();
        List<String> parts = fullName.split(' ');
        String lastName = ' ';
        if (parts.length == 3) {
          if (parts[parts.length - 1].length == 1) {
            lastName = parts[1].toLowerCase().capitalizeFirst.toString();
          } else {
            lastName = parts[parts.length - 1]
                .toLowerCase()
                .capitalizeFirst
                .toString();
          }
        } else {
          lastName =
              parts[parts.length - 1].toLowerCase().capitalizeFirst.toString();
        }
        String firstName = parts[0].toLowerCase().capitalizeFirst.toString();

        var userModel = UserModel(
          id: _firebaseAuthInstance.currentUser!.uid,
          fullName: fullName,
          firstName: firstName,
          lastName: lastName,
          email: googleSignInAccount.email,
        );

        debugPrint('Creating user model with Firebase UID: ${userModel.id}');
        debugPrint('User email: ${userModel.email}');

        try {
          await FirestoreDb.addUser(userModel);
        } catch (e) {
          // Don't block sign-in if Firestore write fails; log and continue.
          debugPrint('Firestore addUser failed after sign-in: $e');
        }
        await SecureStorageProvider().storeUserModel(userModel);

        settingsController.isUserLoggedIn.value = true;
        homeController.isUserSignedIn.value = true;
        homeController.userModel.value = userModel;
        settingsController.userModel.value = userModel;
        return googleSignInAccount;
      } else {
        debugPrint(_firebaseAuthInstance.currentUser!.email ?? '');
        return googleSignInAccount;
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  static isUserLoggedin() {
    return _firebaseAuthInstance.currentUser != null;
  }

  static Future<List<CalendarListEntry>?> getCalenders() async {
    final account = await getInstance();
    if (account == null || _googleSignIn.currentUser == null) {
      return null;
    }
    final authHeaders = await _googleSignIn.currentUser!.authHeaders;
    final httpClient = GoogleHttpClient(authHeaders);
    var dataList = await CalendarApi(httpClient).calendarList.list();

    if (dataList.items != null) {
      return dataList.items;
    } else {
      return null;
    }
  }

  static Future<List<Event>?> getEvents(String calenderId) async {
    final account = await getInstance();
    if (account == null || _googleSignIn.currentUser == null) {
      return null;
    }
    final authHeaders = await _googleSignIn.currentUser!.authHeaders;
    final httpClient = GoogleHttpClient(authHeaders);
    var dataList = await CalendarApi(httpClient).events.list(calenderId);
    if (dataList.items != null) {
      return dataList.items;
    } else {
      return null;
    }
  }

  static Future<void> logoutGoogle() async {
    HomeController homeController = Get.find<HomeController>();
    Get.put(SettingsController());
    SettingsController settingsController = Get.find<SettingsController>();

    await homeController.clearAllAlarmTracking();
    await homeController.clearSharedAlarmCache();
    await _googleSignIn.signOut();
    _firebaseAuthInstance.signOut();
    await SecureStorageProvider().deleteUserModel();
    settingsController.isUserLoggedIn.value = false;
    homeController.isUserSignedIn.value = false;
    homeController.userModel.value = null;
    homeController.calendars.clear();
    homeController.calendarFetchStatus.value = 'Loading';
  }
}
