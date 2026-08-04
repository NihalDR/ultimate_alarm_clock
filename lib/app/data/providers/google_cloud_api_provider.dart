import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
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
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>[
      CalendarApi.calendarScope,
    ],
  );

  static final FirebaseAuth _firebaseAuthInstance =
      FirebaseAuth.instance;

  static Future<dynamic> getInstance() async {
    try {
      final HomeController homeController =
          Get.find<HomeController>();

      Get.put(SettingsController());

      final SettingsController settingsController =
          Get.find<SettingsController>();

      if (_firebaseAuthInstance.currentUser == null) {
        final GoogleSignInAccount? googleSignInAccount =
            await _googleSignIn.signIn();

        // User cancelled the sign-in
        if (googleSignInAccount == null) {
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleSignInAccount.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await _firebaseAuthInstance
            .signInWithCredential(credential);

        // Process successful sign-in
        final String fullName =
            googleSignInAccount.displayName.toString();

        final List<String> parts = fullName.split(' ');

        String lastName = ' ';

        if (parts.length == 3) {
          if (parts.last.length == 1) {
            lastName =
                parts[1].toLowerCase().capitalizeFirst.toString();
          } else {
            lastName = parts.last
                .toLowerCase()
                .capitalizeFirst
                .toString();
          }
        } else {
          lastName = parts.last
              .toLowerCase()
              .capitalizeFirst
              .toString();
        }

        final String firstName =
            parts.first.toLowerCase().capitalizeFirst.toString();

        final userModel = UserModel(
          id: _firebaseAuthInstance.currentUser!.uid,
          fullName: fullName,
          firstName: firstName,
          lastName: lastName,
          email: googleSignInAccount.email,
        );

        developer.log(
          'Creating user model with Firebase UID: ${userModel.id}',
        );

        developer.log(
          'User email: ${userModel.email}',
        );

        await FirestoreDb.addUser(userModel);
        await SecureStorageProvider().storeUserModel(userModel);

        settingsController.isUserLoggedIn.value = true;
        homeController.isUserSignedIn.value = true;
        homeController.userModel.value = userModel;
        settingsController.userModel.value = userModel;

        return googleSignInAccount;
      } else {
        developer.log(
          _firebaseAuthInstance.currentUser?.email ?? '',
        );

        return _firebaseAuthInstance.currentUser;
      }
    } catch (e) {
      developer.log(
        'Google Sign-In Error: $e',
      );

      return null;
    }
  }

  static bool isUserLoggedin() {
    return _firebaseAuthInstance.currentUser != null;
  }

  static Future<List<CalendarListEntry>?> getCalenders() async {
    if (_googleSignIn.currentUser == null) {
      await _firebaseAuthInstance.signOut();
      await getInstance();
    }

    final authHeaders =
        await _googleSignIn.currentUser!.authHeaders;

    final httpClient = GoogleHttpClient(authHeaders);

    final dataList =
        await CalendarApi(httpClient).calendarList.list();

    return dataList.items;
  }

  static Future<List<Event>?> getEvents(
    String calenderId,
  ) async {
    await getInstance();

    final authHeaders =
        await _googleSignIn.currentUser!.authHeaders;

    final httpClient = GoogleHttpClient(authHeaders);

    final dataList =
        await CalendarApi(httpClient).events.list(
      calenderId,
    );

    return dataList.items;
  }

  static Future<void> logoutGoogle() async {
    final HomeController homeController =
        Get.find<HomeController>();

    Get.put(SettingsController());

    final SettingsController settingsController =
        Get.find<SettingsController>();

    await _googleSignIn.signOut();
    await _firebaseAuthInstance.signOut();

    await SecureStorageProvider().deleteUserModel();

    settingsController.isUserLoggedIn.value = false;
    homeController.isUserSignedIn.value = false;
    homeController.userModel.value = null;
    homeController.calendars.value = [];
    homeController.calendarFetchStatus.value = 'Loading';
  }
}