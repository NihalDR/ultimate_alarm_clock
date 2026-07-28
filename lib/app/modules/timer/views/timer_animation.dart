import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ultimate_alarm_clock/app/data/models/timer_model.dart';
import 'package:ultimate_alarm_clock/app/data/providers/isar_provider.dart';
import 'package:ultimate_alarm_clock/app/modules/timer/controllers/timer_controller.dart';
import 'package:ultimate_alarm_clock/app/utils/constants.dart';

import '../../../utils/utils.dart';
import '../../settings/controllers/theme_controller.dart';

class TimerAnimatedCard extends StatefulWidget {
  final TimerModel timer;
  final int index;

  const TimerAnimatedCard({
    super.key,
    required this.index,
    required this.timer,
  });
  @override
  State<TimerAnimatedCard> createState() => TimerAnimatedCardState();
}

class TimerAnimatedCardState extends State<TimerAnimatedCard>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  TimerController controller = Get.find<TimerController>();
  ThemeController themeController = Get.find<ThemeController>();
  var width = Get.width;
  var height = Get.height;

  Timer? _timerCounter;
  void startTimer() {
    _timerCounter = Timer.periodic(const Duration(seconds: 1), (timer) {
      debugPrint(widget.timer.timerName);
      if (widget.timer.timeElapsed < widget.timer.timerValue) {
        setState(() {
          widget.timer.timeElapsed += 1000;
          IsarDb.updateTimerTick(widget.timer);
        });
      } else {
        stopTimer();
        controller.startRinger(widget.timer.timerId);
      }
    });
  }

  void stopTimer() {
    _timerCounter!.cancel();
  }

  @override
  void initState() {
    super.initState();
    if (Utils.getDifferenceMillisFromNow(
              widget.timer.startedOn,
              widget.timer.timerValue,
            ) <=
            0 &&
        widget.timer.isPaused == 0) {
      widget.timer.isPaused = 1;
      widget.timer.timeElapsed = 0;
      IsarDb.updateTimerPauseStatus(widget.timer);
    } else if (Utils.getDifferenceMillisFromNow(
              widget.timer.startedOn,
              widget.timer.timerValue,
            ) <
            widget.timer.timerValue &&
        widget.timer.isPaused == 0) {
      widget.timer.timeElapsed = widget.timer.timerValue -
        Utils.getDifferenceMillisFromNow(
          widget.timer.startedOn,
          widget.timer.timerValue,
        );
      IsarDb.updateTimerPauseStatus(widget.timer);
    }
    if (widget.timer.isPaused == 0) {
      startTimer();
    }
  }

  @override
  void dispose() {
    _timerCounter?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isCompleted = widget.timer.timeElapsed >= widget.timer.timerValue;
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
      ),
      child: SizedBox(
        height: context.height / 3.0,
        width: context.width,
        child: Obx(
          () => AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF1F2028) : themeController.secondaryBackgroundColor.value,
              borderRadius: BorderRadius.circular(18),
              border: isCompleted 
                  ? Border.all(color: const Color(0xFFB4FF2A), width: 2)
                  : null,
              boxShadow: isCompleted
                  ? [
                      BoxShadow(
                        color: const Color(0xFFB4FF2A).withOpacity(0.25),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 0),
                      ),
                      BoxShadow(
                        color: const Color(0xFFB4FF2A).withOpacity(0.15),
                        blurRadius: 48,
                        spreadRadius: 4,
                        offset: const Offset(0, 0),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  if (!isCompleted)
                    AnimatedContainer(
                      decoration: BoxDecoration(
                        color: kprimaryDisabledTextColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      duration: const Duration(milliseconds: 1000),
                      height: context.height / 3.3,
                      width: context.width *
                          ((widget.timer.timeElapsed) /
                              (widget.timer.timerValue)),
                    ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    if (isCompleted)
                                      Container(
                                        margin: const EdgeInsets.only(right: 10),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFB4FF2A).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFFB4FF2A),
                                          size: 22,
                                        ),
                                      ),
                                    Flexible(
                                      child: Text(
                                        widget.timer.timerName,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall!.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: isCompleted 
                                                  ? Colors.white 
                                                  : kprimaryColor,
                                              fontSize: 18,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        if (_timerCounter != null &&
                                            widget.timer.isPaused == 0) {
                                          stopTimer();
                                        }
                                        widget.timer.timeElapsed = 0;
                                        IsarDb.updateTimerTick(widget.timer);
                                        if (_timerCounter != null &&
                                            widget.timer.isPaused == 0) {
                                          widget.timer.startedOn =
                                              DateTime.now().toString();
                                          IsarDb.updateTimerTick(widget.timer)
                                              .then((value) => startTimer());
                                        }
                                      });
                                    },
                                    icon: Icon(
                                      Icons.refresh_rounded,
                                      size: 20,
                                      color: isCompleted 
                                          ? const Color(0xFFB4FF2A).withOpacity(0.8)
                                          : Colors.white,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      controller.stopRinger(
                                        widget.timer.timerId,
                                      );
                                      controller.deleteTimer(
                                        widget.timer.timerId,
                                      );
                                    },
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                      color: isCompleted 
                                          ? Colors.white.withOpacity(0.7)
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Obx(
                                  () => AnimatedContainer(
                                    duration: const Duration(seconds: 1),
                                    child: Text(
                                      isCompleted 
                                          ? '00:00:00'
                                          : Utils.formatMilliseconds(
                                              widget.timer.timerValue -
                                                  widget.timer.timeElapsed,
                                            ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayLarge!
                                          .copyWith(
                                            color: isCompleted 
                                                ? Colors.white 
                                                : themeController
                                                    .primaryTextColor.value,
                                            fontSize: 48,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -1.5,
                                          ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (widget.timer.isPaused == 0) {
                                            stopTimer();
                                          } else {
                                            startTimer();
                                          }
                                          widget.timer.isPaused =
                                              widget.timer.isPaused == 0
                                                  ? 1
                                                  : 0;
                                          IsarDb.updateTimerPauseStatus(
                                            widget.timer,
                                          );
                                        });
                                        if (widget.timer.timeElapsed >=
                                            widget.timer.timerValue) {
                                          controller.stopRinger(
                                            widget.timer.timerId,
                                          );
                                          setState(() {
                                            widget.timer.timeElapsed = 0;
                                            IsarDb.updateTimerTick(
                                              widget.timer,
                                            ).then(
                                              (value) =>
                                                  IsarDb.updateTimerPauseStatus(
                                                widget.timer,
                                              ),
                                            );
                                            widget.timer.isPaused = 1;
                                          });
                                        }
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOutCubic,
                                        decoration: BoxDecoration(
                                          color: isCompleted 
                                              ? const Color(0xFFB4FF2A)
                                              : kprimaryColor,
                                          borderRadius: BorderRadius.circular(80),
                                          boxShadow: isCompleted
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFFB4FF2A).withOpacity(0.4),
                                                    blurRadius: 20,
                                                    spreadRadius: 2,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        width: 88,
                                        height: 88,
                                        child: Icon(
                                          isCompleted
                                              ? Icons.replay_rounded
                                              : widget.timer.isPaused == 0
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                          size: 32,
                                          color: isCompleted 
                                              ? const Color(0xFF1F2028)
                                              : Colors.black,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
