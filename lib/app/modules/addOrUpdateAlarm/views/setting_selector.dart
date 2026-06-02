import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ultimate_alarm_clock/app/data/providers/google_cloud_api_provider.dart';
import '../controllers/add_or_update_alarm_controller.dart';

import '../../../utils/constants.dart';

class SettingSelector extends StatelessWidget {
  SettingSelector({super.key});
  final AddOrUpdateAlarmController controller =
      Get.find<AddOrUpdateAlarmController>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: controller.homeController.scalingFactor.value * 30,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          optionButton(0, Icons.alarm, 'Alarm'),
          optionButton(1, Icons.auto_awesome, 'Smart-Controls'),
          optionButton(2, Icons.checklist_rounded, 'Challenges'),
          optionButton(3, Icons.share, 'Share'),
        ],
      ),
    );
  }

  Widget optionButton(int val, IconData icon, String name) {
    return Obx(
      () => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () async {
                if (name == 'Share') {
                  final isLoggedIn = await GoogleCloudProvider.isUserLoggedin();
                  if (isLoggedIn) {
                    // Get.dialog(ShareDialog(
                    //   homeController: controller.homeController,
                    //   controller: controller,
                    //   themeController: controller.themeController,
                    // ));
                    controller.alarmSettingType.value = val;
                  } else {
                    await GoogleCloudProvider.getInstance();
                  }
                } else {
                  controller.alarmSettingType.value = val;
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: controller.alarmSettingType.value == val
                      ? kprimaryColor
                      : controller
                          .themeController.secondaryBackgroundColor.value,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(
                    icon,
                    color: controller.alarmSettingType.value == val
                        ? kLightPrimaryTextColor
                        : controller
                            .themeController.primaryDisabledTextColor.value,
                  ),
                ),
              ),
            ),
          ),
          Text(
            name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: controller.homeController.scalingFactor.value * 12,
            ),
          ),
        ],
      ),
    );
  }
}
