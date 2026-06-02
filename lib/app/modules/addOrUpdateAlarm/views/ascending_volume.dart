import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/add_or_update_alarm_controller.dart';
import '../../settings/controllers/theme_controller.dart';
import '../../../utils/constants.dart';
import '../../../utils/utils.dart';

class AscendingVolumeTile extends StatelessWidget {
  const AscendingVolumeTile({
    super.key,
    required this.controller,
    required this.themeController,
  });

  final AddOrUpdateAlarmController controller;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isEnabled = controller.gradient.value > 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Text(
              'Ascending volume'.tr,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: themeController.primaryTextColor.value,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            subtitle: Text(
              'Start quiet and gradually get louder'.tr,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: themeController.primaryDisabledTextColor.value,
                  ),
            ),
            trailing: Switch(
              value: isEnabled,
              activeColor: kprimaryColor,
              onChanged: (value) {
                Utils.hapticFeedback();
                if (value) {
                  controller.gradient.value = 30;
                  controller.selectedGradientDouble.value = 30.0;
                } else {
                  controller.gradient.value = 0;
                }
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child:
                isEnabled ? _buildSettings(context) : const SizedBox.shrink(),
          ),
        ],
      );
    });
  }

  Widget _buildSettings(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, 'Ramp duration'.tr),
          Obx(() {
            final sliderValue = _normalizedGradient();
            return Slider(
              value: sliderValue,
              onChanged: (double value) {
                Utils.hapticFeedback();
                controller.selectedGradientDouble.value = value;
                controller.gradient.value = value.toInt();
              },
              min: 5.0,
              max: 300.0,
              divisions: 59,
              label: '${sliderValue.toInt()}s',
            );
          }),
          const SizedBox(height: 16),
          _buildSectionTitle(context, 'Volume range'.tr),
          Obx(() {
            final range = _normalizedRange();
            return RangeSlider(
              values: range,
              onChanged: (RangeValues values) {
                Utils.hapticFeedback();
                controller.volMin.value = values.start;
                controller.volMax.value = values.end;
              },
              min: 0.0,
              max: 10.0,
              divisions: 10,
              labels: RangeLabels(
                _formatVolumePercent(range.start),
                _formatVolumePercent(range.end),
              ),
            );
          }),
          const SizedBox(height: 8),
          Obx(() {
            return Text(
              'From ${_formatVolumePercent(controller.volMin.value)} '
                      'to ${_formatVolumePercent(controller.volMax.value)}'
                  .tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: themeController.primaryDisabledTextColor.value,
                  ),
            );
          }),
          const SizedBox(height: 12),
          _buildPreview(context),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: themeController.primaryTextColor.value,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Obx(() {
      final previewText =
          'Volume ramps for ${controller.gradient.value} seconds'.tr;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kprimaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kprimaryColor.withOpacity(0.2),
          ),
        ),
        child: Text(
          previewText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: themeController.primaryTextColor.value,
              ),
        ),
      );
    });
  }

  double _normalizedGradient() {
    final selected = controller.selectedGradientDouble.value;
    if (selected >= 5.0 && selected <= 300.0) {
      return selected;
    }
    final gradient = controller.gradient.value.toDouble();
    if (gradient >= 5.0 && gradient <= 300.0) {
      return gradient;
    }
    return 30.0;
  }

  RangeValues _normalizedRange() {
    final start = controller.volMin.value;
    final end = controller.volMax.value;
    if (start <= end) {
      return RangeValues(start, end);
    }
    return RangeValues(end, start);
  }

  String _formatVolumePercent(double value) {
    return '${(value * 10).round()}%';
  }
}
