import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/models/alarm_model.dart';
import '../../settings/controllers/settings_controller.dart';
import '../../settings/controllers/theme_controller.dart';
import '../../../utils/constants.dart';
import '../../../utils/utils.dart';
import 'package:ultimate_alarm_clock/app/modules/addOrUpdateAlarm/controllers/add_or_update_alarm_controller.dart';
import 'alarm_date_tile.dart';
import 'alarm_offset_tile.dart';
import 'ascending_volume.dart';
import 'choose_ringtone_tile.dart';
import 'custom_time_picker.dart';
import 'delete_tile.dart';
import 'guardian_angel.dart';
import 'label_tile.dart';
import 'location_activity_tile.dart';
import 'maths_challenge_tile.dart';
import 'note.dart';
import 'pedometer_challenge_tile.dart';
import 'qr_bar_code_tile.dart';
import 'quote_tile.dart';
import 'repeat_once_tile.dart';
import 'repeat_tile.dart';
import 'screen_activity_tile.dart';
import 'setting_selector.dart';
import 'shake_to_dismiss_tile.dart';
import 'share_alarm_tile.dart';
import 'shared_alarm_tile.dart';
import 'shared_users_tile.dart';
import 'smart_control_combination_tile.dart';
import 'snooze_settings_tile.dart';
import 'sunrise_alarm_tile.dart';
import 'task_list_tile.dart';
import 'timezone_tile.dart';
import 'weather_tile.dart';

class AddOrUpdateAlarmView extends GetView<AddOrUpdateAlarmController> {
  AddOrUpdateAlarmView({super.key});

  final ThemeController themeController = Get.find<ThemeController>();
  final SettingsController settingsController = Get.find<SettingsController>();

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    // var width = Get.width;
    // var height = Get.height;
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) {
          return;
        }
        controller.checkUnsavedChangesAndNavigate(context);
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(height * 0.08),
          child: Obx(
            () => AppBar(
              backgroundColor: themeController.primaryBackgroundColor.value,
              elevation: 0.0,
              centerTitle: true,
              iconTheme: Theme.of(context).iconTheme,
              title: (controller.mutexLock.value == true)
                  ? const Text('')
                  : controller.homeController.isProfile.value
                      ? const Text('Edit Profile')
                      : Obx(
                          () => Text(
                            'Rings in @timeToAlarm'.trParams(
                              {
                                'timeToAlarm':
                                    controller.timeToAlarm.value.toString(),
                              },
                            ),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: (controller.mutexLock.value == true)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Obx(
                                () => Text(
                                  'Uh-oh!'.tr,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayMedium!
                                      .copyWith(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                ),
                              ),
                            ),
                            SvgPicture.asset(
                              'assets/images/locked.svg',
                              height: height * 0.24,
                              width: width * 0.5,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Obx(
                                () => Text(
                                  // 'This alarm is currently being edited!',
                                  'alarmEditing'.tr,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall!
                                      .copyWith(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                ),
                              ),
                            ),
                            TextButton(
                              style: const ButtonStyle(
                                backgroundColor:
                                    WidgetStatePropertyAll(kprimaryColor),
                              ),
                              child: Obx(
                                () => Text(
                                  'Go back'.tr,
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall!
                                      .copyWith(
                                        color: themeController
                                            .secondaryTextColor.value,
                                      ),
                                ),
                              ),
                              onPressed: () {
                                Utils.hapticFeedback();
                                Get.back();
                              },
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          !controller.homeController.isProfile.value
                              ? Padding(
                                  padding: EdgeInsets.only(
                                    top: height * 0.02,
                                    left: width * 0.04,
                                    right: width * 0.04,
                                  ),
                                  child: Obx(
                                    () => Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: themeController
                                            .secondaryBackgroundColor.value,
                                        borderRadius:
                                            BorderRadius.circular(500),
                                      ),
                                      height: height * 0.25,
                                      child: Obx(
                                        () {
                                          return InkWell(
                                            onTap: () {
                                              Utils.hapticFeedback();
                                              controller.changeDatePicker();
                                            },
                                            child: controller.isTimePicker.value
                                                ? _buildTimePicker(
                                                    context,
                                                    width,
                                                  )
                                                : _buildManualTimeInput(
                                                    context,
                                                  ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                )
                              : Obx(
                                  () => Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Profile Name',
                                        fillColor: controller.themeController
                                            .secondaryBackgroundColor.value,
                                        filled: true,
                                      ),
                                      controller: controller
                                          .profileTextEditingController,
                                    ),
                                  ),
                                ),
                          SettingSelector(),
                          Obx(
                            () => controller.alarmSettingType.value == 0
                                ? Column(
                                    children: [
                                      AlarmDateTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      RepeatTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      TimezoneTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      Obx(
                                        () {
                                          final hasRepeatDays = controller
                                              .repeatDays
                                              .any((element) => element);

                                          return hasRepeatDays
                                              ? RepeatOnceTile(
                                                  controller: controller,
                                                  themeController:
                                                      themeController,
                                                )
                                              : const SizedBox();
                                        },
                                      ),
                                      Obx(
                                        () {
                                          final hasRepeatDays = controller
                                              .repeatDays
                                              .any((element) => element);

                                          return hasRepeatDays
                                              ? Divider(
                                                  color: themeController
                                                      .primaryDisabledTextColor
                                                      .value,
                                                )
                                              : const SizedBox();
                                        },
                                      ),
                                      SnoozeSettingsTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      Obx(
                                        () => controller.repeatDays.every(
                                          (element) => element == false,
                                        )
                                            ? DeleteAfterGoesOff(
                                                controller: controller,
                                                themeController:
                                                    themeController,
                                              )
                                            : const SizedBox(),
                                      ),
                                      LabelTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      NoteTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      TaskListTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      ChooseRingtoneTile(
                                        controller: controller,
                                        themeController: themeController,
                                        height: height,
                                        width: width,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      AscendingVolumeTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      SunriseAlarmTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      QuoteTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                    ],
                                  )
                                : const SizedBox(),
                          ),
                          Obx(
                            () => controller.alarmSettingType.value == 1
                                ? Column(
                                    children: [
                                      SmartControlCombinationTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      ScreenActivityTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      WeatherTile(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      LocationTile(
                                        controller: controller,
                                        height: height,
                                        width: width,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      GuardianAngel(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                    ],
                                  )
                                : const SizedBox(),
                          ),
                          Obx(
                            () => controller.alarmSettingType.value == 2
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ShakeToDismiss(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      QrBarCode(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      MathsChallenge(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      Divider(
                                        color: themeController
                                            .primaryDisabledTextColor.value,
                                      ),
                                      PedometerChallenge(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                    ],
                                  )
                                : const SizedBox(),
                          ),
                          Obx(
                            () => controller.alarmSettingType.value == 3
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SharedAlarm(
                                        controller: controller,
                                        themeController: themeController,
                                      ),
                                      ShareAlarm(
                                        controller: controller,
                                        width: width,
                                        themeController: themeController,
                                      ),
                                      Obx(
                                        () => (controller
                                                .isSharedAlarmEnabled.value)
                                            ? Column(
                                                children: [
                                                  Divider(
                                                    color: themeController
                                                        // ignore: lines_longer_than_80_chars
                                                        .primaryDisabledTextColor
                                                        .value,
                                                  ),
                                                  AlarmOffset(
                                                    controller: controller,
                                                    themeController:
                                                        themeController,
                                                  ),
                                                  Divider(
                                                    color: themeController
                                                        // ignore: lines_longer_than_80_chars
                                                        .primaryDisabledTextColor
                                                        .value,
                                                  ),
                                                  SharedUsers(
                                                    controller: controller,
                                                    themeController:
                                                        themeController,
                                                  ),
                                                ],
                                              )
                                            : Divider(
                                                color: themeController
                                                    .primaryDisabledTextColor
                                                    .value,
                                              ),
                                      ),
                                    ],
                                  )
                                : SizedBox(
                                    height: height * 0.15,
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
            (controller.mutexLock.value == true)
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: SizedBox(
                      height: height * 0.06,
                      width: width * 0.8,
                      child: TextButton(
                        style: const ButtonStyle(
                          backgroundColor:
                              WidgetStatePropertyAll(kprimaryColor),
                        ),
                        child: Text(
                          (controller.alarmRecord.value.alarmID == '')
                              ? 'Save'.tr
                              : 'Update'.tr,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall!
                              .copyWith(
                                color: themeController.secondaryTextColor.value,
                              ),
                        ),
                        onPressed: () async {
                          Utils.hapticFeedback();
                          await controller.checkOverlayPermissionAndNavigate();

                          if ((await Permission.systemAlertWindow.isGranted) &&
                              (await Permission
                                  .ignoreBatteryOptimizations.isGranted)) {
                            if (!controller.homeController.isProfile.value) {
                              if (controller.userModel.value != null) {
                                controller.userOffsetDetails.value = {
                                  'userId': controller.userId.value,
                                  'offsettedTime': Utils.timeOfDayToString(
                                    TimeOfDay.fromDateTime(
                                      Utils.calculateOffsetAlarmTime(
                                        controller.selectedTime.value,
                                        controller.isOffsetBefore.value,
                                        controller.offsetDuration.value,
                                      ),
                                    ),
                                  ),
                                  'offsetDuration':
                                      controller.offsetDuration.value,
                                  'isOffsetBefore':
                                      controller.isOffsetBefore.value,
                                };
                              } else {
                                controller.userOffsetDetails.value = {};
                              }
                              AlarmModel alarmRecord = AlarmModel(
                                deleteAfterGoesOff:
                                    controller.deleteAfterGoesOff.value,
                                snoozeDuration: controller.snoozeDuration.value,
                                maxSnoozeCount: controller.maxSnoozeCount.value,
                                volMax: controller.volMax.value,
                                volMin: controller.volMin.value,
                                gradient: controller.gradient.value,
                                offsetDetails: controller.offsetDetails,
                                label: controller.label.value,
                                note: controller.note.value,
                                tasks: controller.alarmTasks.toList(),
                                showMotivationalQuote:
                                    controller.showMotivationalQuote.value,
                                isOneTime: controller.isOneTime.value,
                                lastEditedUserId:
                                    controller.lastEditedUserId.value,
                                mutexLock: controller.mutexLock.value,
                                alarmID: controller.alarmID,
                                ownerId: controller.ownerId.value,
                                ownerName: controller.ownerName.value,
                                activityInterval:
                                    controller.activityInterval.value * 60000,
                                days: controller.repeatDays.toList(),
                                alarmTime: Utils.timeOfDayToString(
                                  TimeOfDay.fromDateTime(
                                    controller.selectedTime.value,
                                  ),
                                ),
                                mainAlarmTime: Utils.timeOfDayToString(
                                  TimeOfDay.fromDateTime(
                                    controller.selectedTime.value,
                                  ),
                                ),
                                intervalToAlarm: Utils.getMillisecondsToAlarm(
                                  DateTime.now(),
                                  controller.selectedTime.value,
                                ),
                                isActivityEnabled:
                                    controller.isActivityenabled.value,
                                minutesSinceMidnight: Utils.timeOfDayToInt(
                                  TimeOfDay.fromDateTime(
                                    controller.selectedTime.value,
                                  ),
                                ),
                                isLocationEnabled:
                                    controller.isLocationEnabled.value,
                                locationConditionType: controller
                                    .locationConditionType.value.index,
                                weatherTypes: Utils.getIntFromWeatherTypes(
                                  controller.selectedWeather.toList(),
                                ),
                                isWeatherEnabled:
                                    controller.isWeatherEnabled.value,
                                weatherConditionType:
                                    controller.weatherConditionType.value.index,
                                activityConditionType: controller
                                    .activityConditionType.value.index,
                                location: Utils.geoPointToString(
                                  Utils.latLngToGeoPoint(
                                    controller.selectedPoint.value,
                                  ),
                                ),
                                isSharedAlarmEnabled:
                                    controller.isSharedAlarmEnabled.value,
                                isQrEnabled: controller.isQrEnabled.value,
                                qrValue: controller.qrValue.value,
                                isMathsEnabled: controller.isMathsEnabled.value,
                                numMathsQuestions:
                                    controller.numMathsQuestions.value,
                                mathsDifficulty:
                                    controller.mathsDifficulty.value.index,
                                isShakeEnabled: controller.isShakeEnabled.value,
                                shakeTimes: controller.shakeTimes.value,
                                isPedometerEnabled:
                                    controller.isPedometerEnabled.value,
                                numberOfSteps: controller.numberOfSteps.value,
                                ringtoneName:
                                    controller.customRingtoneName.value,
                                activityMonitor:
                                    controller.isActivityMonitorenabled.value,
                                alarmDate: controller.selectedDate.value
                                    .toString()
                                    .substring(0, 11),
                                profile: controller
                                    .homeController.selectedProfile.value,
                                isGuardian: controller.isGuardian.value,
                                guardianTimer: controller.guardianTimer.value,
                                guardian: controller.guardian.value,
                                isCall: controller.isCall.value,
                                ringOn: controller.isFutureDate.value,
                                isSunriseEnabled:
                                    controller.isSunriseEnabled.value,
                                sunriseDuration:
                                    controller.sunriseDuration.value,
                                sunriseIntensity:
                                    controller.sunriseIntensity.value,
                                sunriseColorScheme:
                                    controller.sunriseColorScheme.value,
                              );

                              // Adding offset details to the database if
                              // its a shared alarm
                              if (controller.isSharedAlarmEnabled.value) {
                                final userOffset =
                                    controller.offsetDetails.firstWhereOrNull(
                                  (entry) =>
                                      entry['userId'] ==
                                      controller.userId.value,
                                );

                                if (userOffset != null) {
                                  controller.offsetDetails.removeWhere(
                                    (ele) =>
                                        ele['userId'] ==
                                        controller.userId.value,
                                  );
                                }

                                controller.offsetDetails.add(
                                  Map<String, dynamic>.from(
                                    controller.userOffsetDetails,
                                  ),
                                );

                                alarmRecord.offsetDetails =
                                    controller.offsetDetails;

                                alarmRecord.mainAlarmTime =
                                    Utils.timeOfDayToString(
                                  TimeOfDay.fromDateTime(
                                    controller.selectedTime.value,
                                  ),
                                );
                              }
                              try {
                                if (controller.alarmRecord.value.alarmID ==
                                    '') {
                                  await controller.createAlarm(alarmRecord);
                                } else {
                                  AlarmModel updatedAlarmModel =
                                      controller.updatedAlarmModel();
                                  await controller
                                      .updateAlarm(updatedAlarmModel);
                                }
                              } catch (e) {
                                developer.log(e.toString());
                              }
                            } else {
                              controller.createProfile();
                            }
                          }
                        },
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context, double width) {
    return Obx(() {
      return CustomTimePicker(
        hours: controller.hours.value,
        minutes: controller.minutes.value,
        meridiemIndex: controller.meridiemIndex.value,
        is24Hour: controller.settingsController.is24HrsEnabled.value,
        onHoursChanged: (int value) {
          _updateTimeFromPicker(hours: value);
        },
        onMinutesChanged: (int value) {
          _updateTimeFromPicker(minutes: value);
        },
        onMeridiemChanged: (int value) {
          _updateTimeFromPicker(meridiemIndex: value);
        },
        primaryColor: kprimaryColor,
        textColor: themeController.primaryTextColor.value,
        disabledTextColor: themeController.primaryDisabledTextColor.value,
        scalingFactor: (width * 0.003).clamp(0.8, 1.1),
      );
    });
  }

  Widget _buildManualTimeInput(BuildContext context) {
    return Obx(() {
      final is24Hour = controller.settingsController.is24HrsEnabled.value;
      final hourMin = is24Hour ? 0 : 1;
      final hourMax = is24Hour ? 23 : 12;

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeInputField(
                controller: controller.inputHrsController,
                hintText: is24Hour ? '00' : '12',
                minValue: hourMin,
                maxValue: hourMax,
                onChanged: (_) => controller.toggleIfAtBoundary(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  ':',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: themeController.primaryTextColor.value,
                      ),
                ),
              ),
              _buildTimeInputField(
                controller: controller.inputMinutesController,
                hintText: '00',
                minValue: 0,
                maxValue: 59,
              ),
              if (!is24Hour) ...[
                const SizedBox(width: 10),
                _buildMeridiemToggle(context),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Utils.hapticFeedback();
              controller.confirmTimeInput();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kprimaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Confirm'.tr),
          ),
        ],
      );
    });
  }

  Widget _buildTimeInputField({
    required TextEditingController controller,
    required String hintText,
    required int minValue,
    required int maxValue,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      width: 64,
      child: TextField(
        controller: controller,
        maxLength: 2,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LimitRange(minValue, maxValue),
        ],
        decoration: InputDecoration(
          counterText: '',
          hintText: hintText,
          filled: true,
          fillColor: themeController.secondaryBackgroundColor.value,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildMeridiemToggle(BuildContext context) {
    final isAM = controller.isAM.value;
    return Row(
      children: [
        _buildMeridiemButton(
          context,
          label: 'AM',
          isSelected: isAM,
          onTap: () => controller.changePeriod('AM'),
        ),
        const SizedBox(width: 6),
        _buildMeridiemButton(
          context,
          label: 'PM',
          isSelected: !isAM,
          onTap: () => controller.changePeriod('PM'),
        ),
      ],
    );
  }

  Widget _buildMeridiemButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Utils.hapticFeedback();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? kprimaryColor
              : themeController.secondaryBackgroundColor.value,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label.tr,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? Colors.white
                    : themeController.primaryTextColor.value,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }

  void _updateTimeFromPicker({
    int? hours,
    int? minutes,
    int? meridiemIndex,
  }) {
    if (hours != null) {
      controller.hours.value = hours;
    }
    if (minutes != null) {
      controller.minutes.value = minutes;
    }
    if (meridiemIndex != null) {
      controller.meridiemIndex.value = meridiemIndex;
    }

    final is24Hour = controller.settingsController.is24HrsEnabled.value;
    int hour = controller.hours.value;
    if (!is24Hour) {
      hour = controller.convert24(hour, controller.meridiemIndex.value);
    }
    final minute = controller.minutes.value;
    final current = controller.selectedTime.value;
    controller.selectedTime.value = DateTime(
      current.year,
      current.month,
      current.day,
      hour,
      minute,
    );
  }
}
