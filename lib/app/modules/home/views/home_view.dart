// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:ultimate_alarm_clock/app/data/models/alarm_model.dart';
import 'package:ultimate_alarm_clock/app/data/providers/firestore_provider.dart';
import 'package:ultimate_alarm_clock/app/data/providers/isar_provider.dart';
import 'package:ultimate_alarm_clock/app/modules/home/views/google_calender_dialog.dart';
import 'package:ultimate_alarm_clock/app/modules/home/views/profile_config.dart';
import 'package:ultimate_alarm_clock/app/modules/home/views/toggle_button.dart';
import 'package:ultimate_alarm_clock/app/modules/settings/controllers/settings_controller.dart';
import 'package:ultimate_alarm_clock/app/modules/settings/controllers/theme_controller.dart';
import 'package:ultimate_alarm_clock/app/utils/audio_utils.dart';
import 'package:ultimate_alarm_clock/app/utils/constants.dart';
import 'package:ultimate_alarm_clock/app/utils/end_drawer.dart';
import 'package:ultimate_alarm_clock/app/utils/utils.dart';

import '../controllers/home_controller.dart';
import 'notification_icon.dart';

class HomeView extends GetView<HomeController> {
  HomeView({super.key});
  final ThemeController themeController = Get.find<ThemeController>();
  final SettingsController settingsController = Get.find<SettingsController>();

  @override
  Widget build(BuildContext context) {
    var width = Get.width;
    var height = Get.height;

    // Homeview resetted to expanded state whenever HomeView is rebuilt.
    controller.scalingFactor.value = 1.0;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Obx(
        () => Visibility(
          visible: controller.inMultipleSelectMode.value ? false : true,
          child: SizedBox(
            height: width * 0.13,
            width: width * 0.13,
            child: FloatingActionButton(
              onPressed: () {
                Utils.hapticFeedback();
                controller.isProfile.value = false;
                Get.toNamed(
                  '/add-update-alarm',
                  arguments: controller.genFakeAlarmModel(),
                );
              },
              child: Icon(
                Icons.add,
                size: controller.scalingFactor.value * 30,
              ),
            ),
          ),
        ),
      ),
      endDrawer: buildEndDrawer(context),
      appBar: null,
      body: SafeArea(
        child: Obx(
          () => NestedScrollView(
            controller: controller.scrollController,
            // If the user is not in the multiple select mode
            headerSliverBuilder: controller.inMultipleSelectMode.value == false
                ? (context, innerBoxIsScrolled) => [
                      // Show the normal app bar
                      SliverAppBar(
                        actions: [Container()],
                        automaticallyImplyLeading: false,
                        expandedHeight: height / 7.9,
                        collapsedHeight: height / 7.9,
                        floating: false,
                        pinned: true,
                        snap: false,
                        centerTitle: true,
                        flexibleSpace: LayoutBuilder(
                          builder: (context, constraints) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment
                                    .center, // Center everything vertically
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.only(
                                          left: 25 *
                                              controller.scalingFactor.value,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Next alarm'.tr,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displaySmall!
                                                  .copyWith(
                                                    color: themeController
                                                        .primaryDisabledTextColor
                                                        .value,
                                                    fontSize: 16 *
                                                        controller.scalingFactor
                                                            .value,
                                                  ),
                                            ),
                                            Obx(
                                              () => Text(
                                                controller.alarmTime.value.tr,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .displaySmall!
                                                    .copyWith(
                                                      color: themeController
                                                          .primaryTextColor
                                                          .value
                                                          .withOpacity(
                                                        0.75,
                                                      ),
                                                      fontSize: 14 *
                                                          controller
                                                              .scalingFactor
                                                              .value,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          notificationIcon(controller),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: InkWell(
                                              onTap: () async {
                                                controller.isCalender.value =
                                                    true;
                                                Get.dialog(
                                                  await googleCalenderDialog(
                                                    controller,
                                                    themeController,
                                                    context,
                                                  ),
                                                );
                                              },
                                              child: SvgPicture.asset(
                                                'assets/images/GC.svg',
                                                colorFilter:
                                                    const ColorFilter.mode(
                                                  kprimaryColor,
                                                  BlendMode.srcIn,
                                                ),
                                                height: 30 *
                                                    controller
                                                        .scalingFactor.value,
                                                width: 30 *
                                                    controller
                                                        .scalingFactor.value,
                                              ),
                                            ),
                                          ),
                                          Obx(
                                            () => Visibility(
                                              visible:
                                                  controller.scalingFactor < 0.9
                                                      ? false
                                                      : true,
                                              child: IconButton(
                                                onPressed: () {
                                                  Utils.hapticFeedback();
                                                  Scaffold.of(context)
                                                      .openEndDrawer();
                                                },
                                                icon: const Icon(
                                                  Icons.menu,
                                                ),
                                                color: themeController
                                                    .primaryTextColor.value
                                                    .withOpacity(0.75),
                                                iconSize: 27 *
                                                    controller
                                                        .scalingFactor.value,
                                              ),

                                              //   PopupMenuButton(
                                              //     // onPressed: () {
                                              //     //   Utils.hapticFeedback();
                                              //     //   Get.toNamed('/settings');
                                              //     // },

                                              //     icon: const Icon(Icons.more_vert),
                                              //     color: themeController
                                              //             .isLightMode.value
                                              //         ? kLightSecondaryBackgroundColor
                                              //         : ksecondaryBackgroundColor,
                                              //     iconSize: 27 *
                                              //         controller.scalingFactor.value,
                                              //     itemBuilder: (context) {
                                              //       return [
                                              //         PopupMenuItem<String>(
                                              //           onTap: () {
                                              //             Utils.hapticFeedback();
                                              //             Get.toNamed('/settings');
                                              //           },
                                              //           child: Text(
                                              //             'Settings',
                                              //             style: Theme.of(context)
                                              //                 .textTheme
                                              //                 .bodyMedium!
                                              //                 .copyWith(
                                              //                     color: themeController
                                              //                             .isLightMode
                                              //                             .value
                                              //                         ? kLightPrimaryTextColor
                                              //                         : kprimaryTextColor),
                                              //           ),
                                              //         ),
                                              //         PopupMenuItem<String>(
                                              //           value: 'option1',
                                              //           child: Text(
                                              //             'About',
                                              //             style: Theme.of(context)
                                              //                 .textTheme
                                              //                 .bodyMedium!
                                              //                 .copyWith(
                                              //                     color: themeController
                                              //                             .isLightMode
                                              //                             .value
                                              //                         ? kLightPrimaryTextColor
                                              //                         : kprimaryTextColor),
                                              //           ),
                                              //         ),
                                              //       ];
                                              //     },
                                              //   ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ]
                : (context, innerBoxIsScrolled) => [
                      // Else show the multiple select mode app bar
                      SliverAppBar(
                        automaticallyImplyLeading: false,
                        actions: [Container()],
                        expandedHeight: height / 7.9,
                        collapsedHeight: height / 7.9,
                        floating: false,
                        pinned: true,
                        snap: false,
                        centerTitle: true,
                        flexibleSpace: LayoutBuilder(
                          builder: (context, constraints) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment
                                    .center, // Center everything vertically
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () {
                                              // On pressing the close button, we're closing the multiple select mode, and clearing the select alarm set
                                              controller.inMultipleSelectMode
                                                  .value = false;
                                              controller.isAnyAlarmHolded
                                                  .value = false;
                                              controller.isAllAlarmsSelected
                                                  .value = false;
                                              controller.numberOfAlarmsSelected
                                                  .value = 0;
                                              controller.selectedAlarmSet
                                                  .clear();
                                            },
                                            icon: const Icon(Icons.close),
                                            color: themeController
                                                .primaryTextColor.value
                                                .withOpacity(0.75),
                                            iconSize: 27 *
                                                controller.scalingFactor.value,
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 2 *
                                                  controller
                                                      .scalingFactor.value,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Select alarms to delete'.tr,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .displaySmall!
                                                      .copyWith(
                                                        color: themeController
                                                            .primaryDisabledTextColor
                                                            .value,
                                                        fontSize: 16 *
                                                            controller
                                                                .scalingFactor
                                                                .value,
                                                      ),
                                                ),
                                                SizedBox(
                                                  height: 35,
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width /
                                                      1.2,
                                                  child: Row(
                                                    children: [
                                                      Obx(() {
                                                        // Storing the number of selected alarms
                                                        int numberOfAlarmsSelected =
                                                            controller
                                                                .numberOfAlarmsSelected
                                                                .value;
                                                        return Text(
                                                          numberOfAlarmsSelected ==
                                                                  0
                                                              ? 'No alarm selected'
                                                                  .tr
                                                              : '@noofAlarm alarms selected'
                                                                  .trParams({
                                                                  'noofAlarm':
                                                                      numberOfAlarmsSelected
                                                                          .toString(),
                                                                }),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .displaySmall!
                                                                  .copyWith(
                                                                    color: themeController
                                                                        .primaryTextColor
                                                                        .value
                                                                        .withOpacity(
                                                                      0.75,
                                                                    ),
                                                                    fontSize: 14 *
                                                                        controller
                                                                            .scalingFactor
                                                                            .value,
                                                                  ),
                                                        );
                                                      }),
                                                      const Spacer(),
                                                      Row(
                                                        children: [
                                                          // All alarm select button
                                                          ToggleButton(
                                                            controller:
                                                                controller,
                                                            isSelected: controller
                                                                .isAllAlarmsSelected,
                                                          ),

                                                          // Delete button
                                                          SizedBox(
                                                            width: 30 *
                                                                controller
                                                                    .scalingFactor
                                                                    .value,
                                                          ),
                                                          Obx(
                                                            () => InkWell(
                                                              onTap: () async {
                                                                if (controller
                                                                        .numberOfAlarmsSelected
                                                                        .value >
                                                                    0) {
                                                                  bool confirm =
                                                                      await Get
                                                                          .defaultDialog(
                                                                    title:
                                                                        'Confirmation'
                                                                            .tr,
                                                                    titleStyle: Theme
                                                                            .of(
                                                                      context,
                                                                    )
                                                                        .textTheme
                                                                        .displaySmall,
                                                                    backgroundColor:
                                                                        themeController
                                                                            .secondaryBackgroundColor
                                                                            .value,
                                                                    content:
                                                                        Column(
                                                                      children: [
                                                                        Text(
                                                                          'Delete ${controller.numberOfAlarmsSelected.value} selected alarms?'
                                                                              .tr,
                                                                          style: Theme.of(context)
                                                                              .textTheme
                                                                              .bodyMedium,
                                                                          textAlign:
                                                                              TextAlign.center,
                                                                        ),
                                                                        Padding(
                                                                          padding:
                                                                              const EdgeInsets.only(
                                                                            top:
                                                                                20,
                                                                          ),
                                                                          child:
                                                                              Row(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.spaceEvenly,
                                                                            children: [
                                                                              TextButton(
                                                                                onPressed: () => Get.back(result: false),
                                                                                style: ButtonStyle(
                                                                                  backgroundColor: WidgetStatePropertyAll(
                                                                                    kprimaryTextColor.withOpacity(0.5),
                                                                                  ),
                                                                                ),
                                                                                child: Text(
                                                                                  'Cancel'.tr,
                                                                                  style: Theme.of(context).textTheme.displaySmall!,
                                                                                ),
                                                                              ),
                                                                              TextButton(
                                                                                onPressed: () => Get.back(result: true),
                                                                                style: const ButtonStyle(
                                                                                  backgroundColor: WidgetStatePropertyAll(kprimaryColor),
                                                                                ),
                                                                                child: Text(
                                                                                  'Delete'.tr,
                                                                                  style: Theme.of(context).textTheme.displaySmall!.copyWith(
                                                                                        color: kprimaryBackgroundColor,
                                                                                      ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  );

                                                                  if (confirm ==
                                                                      true) {
                                                                    await controller
                                                                        .deleteAlarms();

                                                                    // Closing the multiple select mode
                                                                    controller
                                                                        .inMultipleSelectMode
                                                                        .value = false;
                                                                    controller
                                                                        .isAnyAlarmHolded
                                                                        .value = false;
                                                                    controller
                                                                        .isAllAlarmsSelected
                                                                        .value = false;
                                                                    controller
                                                                        .numberOfAlarmsSelected
                                                                        .value = 0;
                                                                    controller
                                                                        .selectedAlarmSet
                                                                        .clear();

                                                                    controller
                                                                            .refreshTimer =
                                                                        true;
                                                                    controller
                                                                        .refreshUpcomingAlarms();
                                                                  }
                                                                }
                                                              },
                                                              child: Icon(
                                                                Icons.delete,
                                                                color: controller
                                                                            .numberOfAlarmsSelected
                                                                            .value >
                                                                        0
                                                                    ? Colors.red
                                                                    : themeController
                                                                        .primaryTextColor
                                                                        .value
                                                                        .withOpacity(
                                                                        0.75,
                                                                      ),
                                                                size: 27 *
                                                                    controller
                                                                        .scalingFactor
                                                                        .value,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],

            body: RefreshIndicator(
              onRefresh: () async {
                refresh();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        EdgeInsets.only(bottom: controller.scalingFactor * 20),
                    child: const ProfileSelect(),
                  ),
                  Expanded(
                    child: GlowingOverscrollIndicator(
                      color: themeController.primaryDisabledTextColor.value,
                      axisDirection: AxisDirection.down,
                      child: Obx(() {
                        return FutureBuilder(
                          future: (() {
                            debugPrint(
                              '🏠 HomeView: User signed in: '
                              '${controller.isUserSignedIn.value}',
                            );
                            debugPrint(
                              '🏠 HomeView: User model: '
                              '${controller.userModel.value?.email ?? 'null'}',
                            );
                            return controller
                                .initStream(controller.userModel.value);
                          })(),
                          builder: (context, AsyncSnapshot snapshot) {
                            if (snapshot.hasData) {
                              final Stream streamAlarms = snapshot.data;

                              return StreamBuilder(
                                stream: streamAlarms,
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator.adaptive(
                                        backgroundColor: Colors.transparent,
                                        valueColor: AlwaysStoppedAnimation(
                                          kprimaryColor,
                                        ),
                                      ),
                                    );
                                  } else {
                                    List<AlarmModel> alarms = snapshot.data;
                                    debugPrint(
                                      '🏠 HomeView: Received '
                                      '${alarms.length} alarms',
                                    );
                                    for (int i = 0;
                                        i < alarms.length && i < 3;
                                        i++) {
                                      debugPrint(
                                        '   - Alarm ${i + 1}: '
                                        '${alarms[i].alarmTime} '
                                        '(${alarms[i].isSharedAlarmEnabled ? 'Shared' : 'Local'})',
                                      );
                                    }

                                    alarms = alarms.toList();
                                    controller.refreshTimer = true;
                                    controller.refreshUpcomingAlarms();
                                    if (alarms.isEmpty) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            SvgPicture.asset(
                                              'assets/images/empty.svg',
                                              height: height * 0.3,
                                              width: width * 0.8,
                                            ),
                                            Text(
                                              'Add an alarm to get started!'.tr,
                                              textWidthBasis:
                                                  TextWidthBasis.longestLine,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displaySmall!
                                                  .copyWith(
                                                    color: themeController
                                                        .primaryDisabledTextColor
                                                        .value,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return ListView.separated(
                                      separatorBuilder: (context, _) {
                                        return SizedBox(
                                          height: height * 0.02,
                                        );
                                      },
                                      itemCount: alarms.length + 1,
                                      itemBuilder: (context, index) {
                                        // Spacing after last card
                                        if (index == alarms.length) {
                                          return SizedBox(
                                            height: height * 0.1,
                                          );
                                        }
                                        final AlarmModel alarm = alarms[index];
                                        final repeatDays =
                                            Utils.getRepeatDays(alarm.days);
                                        // Main card
                                        return alarm.profile ==
                                                controller.selectedProfile.value
                                            ? Dismissible(
                                                confirmDismiss:
                                                    (direction) async {
                                                  if (direction ==
                                                      DismissDirection
                                                          .endToStart) {
                                                    // Right swipe - Edit/Duplicate
                                                    await _showEditDuplicateOptions(
                                                        context, alarm,);
                                                    return false; // Don't dismiss
                                                  }
                                                  // Left swipe - Delete
                                                  bool userConfirmed =
                                                      await showDeleteAlarmConfirmationPopupOnSwipe(
                                                    context,
                                                  );
                                                  if (userConfirmed) {
                                                    await controller
                                                        .swipeToDeleteAlarm(
                                                      controller
                                                          .userModel.value,
                                                      alarm,
                                                    );
                                                  }
                                                  return userConfirmed;
                                                },
                                                key: ValueKey(alarms[index]),
                                                background: _buildSwipeBackground(
                                                  context,
                                                  Alignment.centerLeft,
                                                  Icons.delete,
                                                  Colors.red,
                                                  'Delete'.tr,
                                                ),
                                                secondaryBackground:
                                                    _buildSwipeBackground(
                                                  context,
                                                  Alignment.centerRight,
                                                  Icons.edit,
                                                  kprimaryColor,
                                                  'Edit'.tr,
                                                  showDuplicate: true,
                                                ),
                                                child: Obx(
                                                  () => GestureDetector(
                                                    onTap: () {
                                                      Utils.hapticFeedback();

                                                      // If multiple select mode is not on, then only you can update the alarm
                                                      if (!controller
                                                          .inMultipleSelectMode
                                                          .value) {
                                                        controller.isProfile
                                                            .value = false;
                                                        Get.toNamed(
                                                          '/add-update-alarm',
                                                          arguments: alarm,
                                                        );
                                                      }
                                                    },
                                                    onLongPress: () {
                                                      // Entering the multiple select mode
                                                      controller
                                                          .inMultipleSelectMode
                                                          .value = true;
                                                      controller
                                                          .isAnyAlarmHolded
                                                          .value = true;

                                                      // Assigning the alarm list pairs to list of alarms and list of isSelected
                                                      // The long-pressed alarm is selected by default
                                                      controller
                                                              .alarmListPairs =
                                                          Pair(
                                                        alarms,
                                                        List.generate(
                                                          alarms.length,
                                                          (i) =>
                                                              (i == index).obs,
                                                        ),
                                                      );

                                                      // The long-pressed alarm added to the selected set
                                                      controller
                                                          .numberOfAlarmsSelected
                                                          .value = 1;
                                                      controller
                                                          .selectedAlarmSet
                                                          .clear();
                                                      controller
                                                          .selectedAlarmSet
                                                          .add(
                                                        alarm.isSharedAlarmEnabled
                                                            ? Pair(
                                                                alarm
                                                                    .firestoreId,
                                                                true,
                                                              )
                                                            : Pair(
                                                                alarm.isarId,
                                                                false,
                                                              ),
                                                      );

                                                      Utils.hapticFeedback();
                                                    },
                                                    onLongPressEnd: (details) {
                                                      controller
                                                          .isAnyAlarmHolded
                                                          .value = false;
                                                    },
                                                    child: AnimatedContainer(
                                                      duration: const Duration(
                                                        milliseconds: 600,
                                                      ),
                                                      curve: Curves.easeInOut,
                                                      margin: EdgeInsets.all(
                                                        controller
                                                                .isAnyAlarmHolded
                                                                .value
                                                            ? 10
                                                            : 0,
                                                      ),
                                                      child: Center(
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 10.0,
                                                          ),
                                                          child: Card(
                                                            color: themeController
                                                                .secondaryBackgroundColor
                                                                .value,
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                18,
                                                              ),
                                                            ),
                                                            child: Center(
                                                              child: Padding(
                                                                padding:
                                                                    EdgeInsets
                                                                        .only(
                                                                  left: 25.0,
                                                                  right: controller
                                                                          .inMultipleSelectMode
                                                                          .value
                                                                      ? 10.0
                                                                      : 0.0,
                                                                  top: controller
                                                                          .inMultipleSelectMode
                                                                          .value
                                                                      ? Utils.isChallengeEnabled(
                                                                                alarm,
                                                                              ) ||
                                                                              Utils.isAutoDismissalEnabled(
                                                                                alarm,
                                                                              )
                                                                          ? 15.0
                                                                          : 18.0
                                                                      : Utils.isChallengeEnabled(
                                                                                alarm,
                                                                              ) ||
                                                                              Utils.isAutoDismissalEnabled(
                                                                                alarm,
                                                                              )
                                                                          ? 8.0
                                                                          : 0.0,
                                                                  bottom: controller
                                                                          .inMultipleSelectMode
                                                                          .value
                                                                      ? Utils.isChallengeEnabled(
                                                                                alarm,
                                                                              ) ||
                                                                              Utils.isAutoDismissalEnabled(
                                                                                alarm,
                                                                              )
                                                                          ? 15.0
                                                                          : 18.0
                                                                      : Utils.isChallengeEnabled(
                                                                                alarm,
                                                                              ) ||
                                                                              Utils.isAutoDismissalEnabled(
                                                                                alarm,
                                                                              )
                                                                          ? 8.0
                                                                          : 0.0,
                                                                ),
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Expanded(
                                                                      flex: 3,
                                                                      child:
                                                                          Column(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.center,
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          IntrinsicHeight(
                                                                            child:
                                                                                Row(
                                                                              children: [
                                                                                Text(
                                                                                  repeatDays.replaceAll(
                                                                                    'Never'.tr,
                                                                                    'One Time'.tr,
                                                                                  ),
                                                                                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                                                                        fontWeight: FontWeight.w500,
                                                                                        color: alarm.isEnabled == true ? kprimaryColor : themeController.primaryDisabledTextColor.value,
                                                                                      ),
                                                                                ),
                                                                                if (alarm.label.isNotEmpty)
                                                                                  VerticalDivider(
                                                                                    color: alarm.isEnabled == true ? kprimaryColor : themeController.primaryDisabledTextColor.value,
                                                                                    thickness: 1.4,
                                                                                    width: 6,
                                                                                    indent: 3.1,
                                                                                    endIndent: 3.1,
                                                                                  ),
                                                                                Expanded(
                                                                                  child: Text(
                                                                                    alarm.label,
                                                                                    overflow: TextOverflow.ellipsis,
                                                                                    // Set overflow property here
                                                                                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                                                                          fontWeight: FontWeight.w500,
                                                                                          color: alarm.isEnabled == true ? kprimaryColor : themeController.primaryDisabledTextColor.value,
                                                                                        ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                          Row(
                                                                            children: [
                                                                              Text(
                                                                                (settingsController.is24HrsEnabled.value
                                                                                    ? Utils.split24HourFormat(alarm.alarmTime)
                                                                                    : Utils.convertTo12HourFormat(
                                                                                        alarm.alarmTime,
                                                                                      ))[0],
                                                                                style: Theme.of(
                                                                                  context,
                                                                                ).textTheme.displayLarge!.copyWith(
                                                                                      color: alarm.isEnabled == true ? themeController.primaryTextColor.value : themeController.primaryDisabledTextColor.value,
                                                                                    ),
                                                                              ),
                                                                              Padding(
                                                                                padding: const EdgeInsets.symmetric(
                                                                                  horizontal: 3.0,
                                                                                ),
                                                                                child: Text(
                                                                                  (settingsController.is24HrsEnabled.value
                                                                                      ? Utils.split24HourFormat(alarm.alarmTime)
                                                                                      : Utils.convertTo12HourFormat(
                                                                                          alarm.alarmTime,
                                                                                        ))[1],
                                                                                  style: Theme.of(context).textTheme.displayMedium!.copyWith(
                                                                                        color: alarm.isEnabled == true ? themeController.primaryTextColor.value : themeController.primaryDisabledTextColor.value,
                                                                                      ),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                          if (Utils.isChallengeEnabled(
                                                                                alarm,
                                                                              ) ||
                                                                              Utils.isAutoDismissalEnabled(
                                                                                alarm,
                                                                              ) ||
                                                                              alarm.isSharedAlarmEnabled)
                                                                            Wrap(
                                                                              spacing: 6,
                                                                              runSpacing: 4,
                                                                              children: _buildChallengeBadges(
                                                                                alarm,
                                                                                themeController,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    Padding(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .symmetric(
                                                                        horizontal:
                                                                            10.0,
                                                                      ),
                                                                      child: controller
                                                                              .inMultipleSelectMode
                                                                              .value
                                                                          ? Column(
                                                                              // Showing the toggle button
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              children: [
                                                                                Expanded(
                                                                                  flex: 0,
                                                                                  child: ToggleButton(
                                                                                    controller: controller,
                                                                                    alarmIndex: index,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            )
                                                                          : Column(
                                                                              // Showing the switch and pop up menu button
                                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                                              children: [
                                                                                Expanded(
                                                                                  flex: 0,
                                                                                  child: Switch.adaptive(
                                                                                    activeColor: ksecondaryColor,
                                                                                    value: alarm.isEnabled,
                                                                                    onChanged: (bool value) async {
                                                                                      Utils.hapticFeedback();
                                                                                      alarm.isEnabled = value;
                                                                                      if (alarm.isSharedAlarmEnabled == true) {
                                                                                        await FirestoreDb.updateAlarm(alarm.ownerId, alarm);
                                                                                      } else {
                                                                                        await IsarDb.updateAlarm(alarm);
                                                                                      }
                                                                                      controller.refreshTimer = true;
                                                                                      controller.refreshUpcomingAlarms();
                                                                                    },
                                                                                  ),
                                                                                ),
                                                                                Expanded(
                                                                                  flex: 0,
                                                                                  child: PopupMenuButton(
                                                                                    onSelected: (value) async {
                                                                                      Utils.hapticFeedback();
                                                                                      if (value == 0) {
                                                                                        Get.toNamed(
                                                                                          '/alarm-ring',
                                                                                          arguments: {
                                                                                            'alarm': alarm,
                                                                                            'preview': true,
                                                                                          },
                                                                                        );
                                                                                      } else if (value == 1) {
                                                                                        debugPrint(alarm.isSharedAlarmEnabled.toString());

                                                                                        if (alarm.isSharedAlarmEnabled == true) {
                                                                                          // Cancel the native Android alarm BEFORE deleting from database
                                                                                          try {
                                                                                            await controller.alarmChannel.invokeMethod('cancelAlarmById', {
                                                                                              'alarmID': alarm.firestoreId!,
                                                                                              'isSharedAlarm': true,
                                                                                            });
                                                                                            debugPrint('🗑️ Canceled native shared alarm before deletion: ${alarm.firestoreId}');
                                                                                          } catch (e) {
                                                                                            debugPrint('⚠️ Error canceling native shared alarm: $e');
                                                                                          }

                                                                                          await FirestoreDb.deleteAlarm(controller.userModel.value, alarm.firestoreId!);
                                                                                        } else {
                                                                                          // Cancel the native Android alarm BEFORE deleting from database
                                                                                          try {
                                                                                            await controller.alarmChannel.invokeMethod('cancelAlarmById', {
                                                                                              'alarmID': alarm.alarmID,
                                                                                              'isSharedAlarm': false,
                                                                                            });
                                                                                            debugPrint('🗑️ Canceled native local alarm before deletion: ${alarm.alarmID}');
                                                                                          } catch (e) {
                                                                                            debugPrint('⚠️ Error canceling native local alarm: $e');
                                                                                          }

                                                                                          await IsarDb.deleteAlarm(alarm.isarId);
                                                                                        }

                                                                                        if (Get.isSnackbarOpen) {
                                                                                          Get.closeAllSnackbars();
                                                                                        }

                                                                                        Get.snackbar(
                                                                                          'Alarm deleted',
                                                                                          'The alarm has been deleted.',
                                                                                          duration: Duration(seconds: controller.duration.toInt()),
                                                                                          snackPosition: SnackPosition.BOTTOM,
                                                                                          margin: const EdgeInsets.symmetric(
                                                                                            horizontal: 10,
                                                                                            vertical: 15,
                                                                                          ),
                                                                                          mainButton: TextButton(
                                                                                            onPressed: () async {
                                                                                              if (alarm.isSharedAlarmEnabled == true) {
                                                                                                await FirestoreDb.addAlarm(controller.userModel.value, alarm);
                                                                                              } else {
                                                                                                await IsarDb.addAlarm(alarm);
                                                                                              }
                                                                                            },
                                                                                            child: const Text('Undo'),
                                                                                          ),
                                                                                        );

                                                                                        String ringtoneName = alarm.ringtoneName;

                                                                                        await AudioUtils.updateRingtoneCounterOfUsage(
                                                                                          customRingtoneName: ringtoneName,
                                                                                          counterUpdate: CounterUpdate.decrement,
                                                                                        );

                                                                                        controller.refreshTimer = true;
                                                                                        controller.refreshUpcomingAlarms();
                                                                                      }
                                                                                    },
                                                                                    color: themeController.primaryBackgroundColor.value,
                                                                                    icon: Icon(
                                                                                      Icons.more_vert,
                                                                                      color: alarm.isEnabled == true ? themeController.primaryTextColor.value : themeController.primaryDisabledTextColor.value,
                                                                                    ),
                                                                                    itemBuilder: (context) {
                                                                                      return [
                                                                                        PopupMenuItem<int>(
                                                                                          value: 0,
                                                                                          child: Text(
                                                                                            'Preview Alarm'.tr,
                                                                                            style: Theme.of(context).textTheme.bodyMedium,
                                                                                          ),
                                                                                        ),
                                                                                        if (alarm.isSharedAlarmEnabled == false || (alarm.isSharedAlarmEnabled == true && alarm.ownerId == controller.userModel.value!.id))
                                                                                          PopupMenuItem<int>(
                                                                                            value: 1,
                                                                                            child: Text(
                                                                                              'Delete Alarm'.tr,
                                                                                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                                                                                    color: Colors.red,
                                                                                                  ),
                                                                                            ),
                                                                                          ),
                                                                                      ];
                                                                                    },
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : const SizedBox();
                                      },
                                    );
                                  }
                                },
                              );
                            } else {
                              return const CircularProgressIndicator.adaptive(
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation(
                                  kprimaryColor,
                                ),
                              );
                            }
                          },
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> showDeleteAlarmConfirmationPopupOnSwipe(
    BuildContext context,
  ) async {
    // Return true if user confirms deletion, false if canceled

    var result = await Get.defaultDialog(
      titlePadding: const EdgeInsets.symmetric(
        vertical: 20,
      ),
      backgroundColor: themeController.secondaryBackgroundColor.value,
      title: 'Confirmation'.tr,
      titleStyle: Theme.of(context).textTheme.displaySmall,
      content: Column(
        children: [
          Text(
            'want to delete?'.tr,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 20,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Get.back(result: false);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      kprimaryTextColor.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    'Cancel'.tr,
                    style: Theme.of(context).textTheme.displaySmall!,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Get.back(result: true); // User confirmed
                  },
                  style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(kprimaryColor),
                  ),
                  child: Text(
                    'delete'.tr,
                    style: Theme.of(context).textTheme.displaySmall!.copyWith(
                          color: kprimaryBackgroundColor,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return result ??
        false; // Default to false if the user dismisses the dialog without tapping any button
  }

  Future<void> refresh() async {
    await controller.refreshUpcomingAlarms();
    await Future.delayed(const Duration(seconds: 3));
  }

  Widget _buildSwipeBackground(
    BuildContext context,
    Alignment alignment,
    IconData icon,
    Color color,
    String label, {
    bool showDuplicate = false,
  }) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: showDuplicate
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.content_copy, color: Colors.white, size: 28),
                const SizedBox(width: 16),
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: alignment == Alignment.centerLeft
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.end,
              children: alignment == Alignment.centerLeft
                  ? [
                      Icon(icon, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ]
                  : [
                      Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, color: Colors.white, size: 28),
                    ],
            ),
    );
  }

  Future<void> _showEditDuplicateOptions(
    BuildContext context,
    AlarmModel alarm,
  ) async {
    Utils.hapticFeedback();
    await Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: themeController.secondaryBackgroundColor.value,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: themeController.primaryDisabledTextColor.value
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit,
                  color: themeController.primaryTextColor.value, size: 28,),
              title: Text('Edit Alarm'.tr,
                  style: Theme.of(context).textTheme.bodyLarge,),
              onTap: () {
                Get.back();
                controller.isProfile.value = false;
                Get.toNamed('/add-update-alarm', arguments: alarm,);
              },
            ),
            ListTile(
              leading: Icon(Icons.content_copy,
                  color: themeController.primaryTextColor.value, size: 28,),
              title: Text('Duplicate Alarm'.tr,
                  style: Theme.of(context).textTheme.bodyLarge,),
              onTap: () {
                Get.back();
                _duplicateAlarm(alarm,);
              },
            ),
            ListTile(
              leading: Icon(Icons.preview,
                  color: themeController.primaryTextColor.value, size: 28,),
              title: Text('Preview Alarm'.tr,
                  style: Theme.of(context).textTheme.bodyLarge,),
              onTap: () {
                Get.back();
                Get.toNamed('/alarm-ring', arguments: {
                  'alarm': alarm,
                  'preview': true,
                },);
              },
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _duplicateAlarm(AlarmModel alarm) {
    final newAlarm = AlarmModel(
      alarmTime: alarm.alarmTime,
      alarmID: const Uuid().v4(),
      calendarEventId: alarm.calendarEventId,
      calendarEventStart: alarm.calendarEventStart,
      calendarEventUpdated: alarm.calendarEventUpdated,
      calendarId: alarm.calendarId,
      isCalendarEvent: alarm.isCalendarEvent,
      isEnabled: true,
      isLocationEnabled: alarm.isLocationEnabled,
      locationConditionType: alarm.locationConditionType,
      isSharedAlarmEnabled: false, // Duplicated alarms are local by default
      isWeatherEnabled: alarm.isWeatherEnabled,
      weatherConditionType: alarm.weatherConditionType,
      activityConditionType: alarm.activityConditionType,
      location: alarm.location,
      activityInterval: alarm.activityInterval,
      minutesSinceMidnight: alarm.minutesSinceMidnight,
      days: List<bool>.from(alarm.days),
      weatherTypes: List<int>.from(alarm.weatherTypes),
      shakeTimes: alarm.shakeTimes,
      numberOfSteps: alarm.numberOfSteps,
      numMathsQuestions: alarm.numMathsQuestions,
      mathsDifficulty: alarm.mathsDifficulty,
      isMathsEnabled: alarm.isMathsEnabled,
      isShakeEnabled: alarm.isShakeEnabled,
      isQrEnabled: alarm.isQrEnabled,
      qrValue: alarm.qrValue,
      isPedometerEnabled: alarm.isPedometerEnabled,
      isActivityEnabled: alarm.isActivityEnabled,
      intervalToAlarm: alarm.intervalToAlarm,
      sharedUserIds: [],
      ownerId: alarm.ownerId,
      ownerName: alarm.ownerName,
      lastEditedUserId: alarm.lastEditedUserId,
      mutexLock: false,
      mainAlarmTime: alarm.mainAlarmTime,
      label: '${alarm.label} (Copy)'.tr,
      isOneTime: alarm.isOneTime,
      snoozeDuration: alarm.snoozeDuration,
      maxSnoozeCount: alarm.maxSnoozeCount,
      gradient: alarm.gradient,
      ringtoneName: alarm.ringtoneName,
      note: alarm.note,
      tasks: List<String>.from(alarm.tasks),
      deleteAfterGoesOff: alarm.deleteAfterGoesOff,
      showMotivationalQuote: alarm.showMotivationalQuote,
      volMax: alarm.volMax,
      volMin: alarm.volMin,
      activityMonitor: alarm.activityMonitor,
      alarmDate: alarm.alarmDate,
      profile: alarm.profile,
      isGuardian: alarm.isGuardian,
      guardianTimer: alarm.guardianTimer,
      guardian: alarm.guardian,
      isCall: alarm.isCall,
      ringOn: alarm.ringOn,
      isSunriseEnabled: alarm.isSunriseEnabled,
      sunriseDuration: alarm.sunriseDuration,
      sunriseIntensity: alarm.sunriseIntensity,
      sunriseColorScheme: alarm.sunriseColorScheme,
      timezoneId: alarm.timezoneId,
      isTimezoneEnabled: alarm.isTimezoneEnabled,
      targetTimezoneOffset: alarm.targetTimezoneOffset,
      smartControlCombinationType: alarm.smartControlCombinationType,
    );
    controller.isProfile.value = false;
    Get.toNamed('/add-update-alarm', arguments: newAlarm);
  }

List<Widget> _buildChallengeBadges(
    AlarmModel alarm,
    ThemeController themeController,
  ) {
    const Color enabledColor = kprimaryColor;
    final Color disabledColor = themeController.primaryDisabledTextColor.value;

    final List<Widget> badges = [];

    if (alarm.isSharedAlarmEnabled) {
      badges.add(_ChallengeBadge(
        icon: Icons.share_arrival_time,
        color: alarm.isEnabled ? enabledColor : disabledColor,
        tooltip: 'Shared Alarm',
      ),);
    }
    if (alarm.isLocationEnabled) {
      badges.add(_ChallengeBadge(
        icon: Icons.location_pin,
        color: alarm.isEnabled ? Colors.blue : disabledColor,
        tooltip: 'Location',
      ),);
    }
    if (alarm.isActivityEnabled) {
      badges.add(_ChallengeBadge(
        icon: Icons.screen_lock_portrait,
        color: alarm.isEnabled ? Colors.orange : disabledColor,
        tooltip: 'Activity',
      ),);
    }
    if (alarm.isWeatherEnabled) {
      badges.add(_ChallengeBadge(
        icon: Icons.cloudy_snowing,
        color: alarm.isEnabled ? Colors.lightBlue : disabledColor,
        tooltip: 'Weather',
      ),);
    }
    if (alarm.isQrEnabled) {
      badges.add(_ChallengeBadge(
        icon: Icons.qr_code_scanner,
        color: alarm.isEnabled ? Colors.purple : disabledColor,
        tooltip: 'QR Code',
      ),);
    }
    if (alarm.isShakeEnabled) {
      badges.add(_ChallengeBadge(
        icon: Icons.vibration,
        color: alarm.isEnabled ? Colors.redAccent : disabledColor,
        tooltip: 'Shake',
      ),);
    }
    if (alarm.isMathsEnabled) {
      badges.add(_ChallengeBadge(
        icon: Icons.calculate,
        color: alarm.isEnabled ? Colors.green : disabledColor,
        tooltip: 'Math',
      ),);
    }
    if (alarm.isPedometerEnabled) {
      badges.add(_ChallengeBadge(
        icon: Icons.directions_walk,
        color: alarm.isEnabled ? Colors.teal : disabledColor,
        tooltip: 'Steps',
      ),);
    }
    if (alarm.isSunriseEnabled) {
      badges.add(_ChallengeBadge(
        icon: Icons.wb_sunny,
        color: alarm.isEnabled ? Colors.amber : disabledColor,
        tooltip: 'Sunrise',
      ),);
    }
    if (alarm.isGuardian) {
      badges.add(_ChallengeBadge(
        icon: Icons.favorite,
        color: alarm.isEnabled ? Colors.pink : disabledColor,
        tooltip: 'Guardian',
      ),);
    }

    return badges;
  }
}

class _ChallengeBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;

  const _ChallengeBadge({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4), width: 1.2),
        ),
        child: Icon(
          icon,
          size: 16,
          color: color,
        ),
      ),
    );
  }
}
