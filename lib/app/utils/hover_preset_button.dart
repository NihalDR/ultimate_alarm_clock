// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../modules/settings/controllers/theme_controller.dart';
import '../modules/timer/controllers/timer_controller.dart';
import 'constants.dart';

Widget hoverPresetButton(
  BuildContext context,
  String label,
  Duration duration,
) {
  final TimerController timerController = Get.find<TimerController>();
  final ThemeController themeController = Get.find<ThemeController>();

  final double width = MediaQuery.of(context).size.width;
  final double height = MediaQuery.of(context).size.height;

  return ElevatedButton(
    onPressed: () {
      timerController.remainingTime.value = duration;
      timerController.createTimer();
      Get.back();
    },
    style: ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.02,
        vertical: height * 0.01,
      ),
      backgroundColor: themeController.primaryColor.value,
      shadowColor: Colors.transparent,
      minimumSize: Size(
        width * 0.02,
        height * 0.01,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(height * 0.02),
      ),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: height * 0.02,
        color: kprimaryBackgroundColor,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
