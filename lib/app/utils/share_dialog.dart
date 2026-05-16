import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ultimate_alarm_clock/app/data/models/alarm_model.dart';
import 'package:ultimate_alarm_clock/app/data/models/saved_emails.dart';
import 'package:ultimate_alarm_clock/app/data/providers/firestore_provider.dart';
import 'package:ultimate_alarm_clock/app/data/providers/isar_provider.dart';
import 'package:ultimate_alarm_clock/app/data/providers/push_notifications.dart';
import 'package:ultimate_alarm_clock/app/modules/addOrUpdateAlarm/controllers/add_or_update_alarm_controller.dart';
import 'package:ultimate_alarm_clock/app/modules/home/controllers/home_controller.dart';
import 'package:ultimate_alarm_clock/app/modules/settings/controllers/theme_controller.dart';
import 'package:ultimate_alarm_clock/app/utils/constants.dart';
import 'package:ultimate_alarm_clock/app/utils/shared_alarm_logger.dart';
import 'package:ultimate_alarm_clock/app/utils/utils.dart';

class ShareDialog extends StatelessWidget {
  const ShareDialog({
                                Get.snackbar('Error', 'Invalid email');
                              }
                            },
                            icon: const Icon(
                              Icons.add_circle_outlined,
                              color: kprimaryColor,
                            ),
                          ),
                          prefixIcon: const Icon(Icons.alternate_email),
                          prefixIconColor: kprimaryDisabledTextColor,
                          hintText: 'Enter e-mail',
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),
            StreamBuilder(
              stream: IsarDb.getEmails(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final userList = snapshot.data;
                  return SizedBox(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: userList!.length,
                      itemBuilder: (context, index) {
                        return emailTile(userList[index]);
                      },
                    ),
                  );
                }

                return const CircularProgressIndicator();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget emailTile(Saved_Emails email) {
    return ListTile(
      onTap: () {
        if (controller.selectedEmails.contains(email.email)) {
          controller.selectedEmails.remove(email.email);
        } else {
          controller.selectedEmails.add(email.email);
        }
      },
      tileColor: kprimaryBackgroundColor,
      title: Padding(
        padding: EdgeInsets.symmetric(
          vertical: homeController.scalingFactor * 16,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: controller.selectedEmails.contains(email.email)
                        ? kprimaryColor
                        : ksecondaryBackgroundColor,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(homeController.scalingFactor * 16),
                    child: controller.selectedEmails.contains(email.email)
                        ? const Icon(Icons.check)
                        : Text(
                            Utils.getInitials(email.username),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: homeController.scalingFactor * 15,
                              color: ksecondaryColor,
                            ),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: Get.width * 0.5,
                        child: Text(
                          email.username,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: homeController.scalingFactor * 20,
                          ),
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: Get.width * 0.5,
                        child: Text(
                          email.email,
                          style: TextStyle(
                            fontSize: homeController.scalingFactor * 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildContactsHeader(),
                    _buildAddContactSection(),
                    _buildContactsList(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientSection() {
    return Obx(() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: themeController.secondaryBackgroundColor.value,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: kprimaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recipients'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: themeController.primaryTextColor.value,
                ),
              ),
              const SizedBox(height: 8),
              controller.selectedEmails.isEmpty
                  ? Text(
                      'No recipients selected'.tr,
                      style: TextStyle(
                        color: themeController.primaryDisabledTextColor.value,
                        fontSize: 14,
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: controller.selectedEmails.map((email) {
                        return Chip(
                          backgroundColor: kprimaryColor.withOpacity(0.2),
                          label: Text(
                            email,
                            style: TextStyle(
                              color: kprimaryColor,
                              fontSize: 12,
                            ),
                          ),
                          deleteIcon: Icon(
                            Icons.close,
                            size: 16,
                            color: kprimaryColor,
                          ),
                          onDeleted: () {
                            controller.selectedEmails.remove(email);
                          },
                        );
                      }).toList(),
                    ),
            ],
          ),
        ));
  }

  Widget _buildContactsHeader() {
    return Row(
      children: [
        Icon(
          Icons.people,
          color: kprimaryColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Select Contacts'.tr,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: themeController.primaryTextColor.value,
          ),
        ),
        const Spacer(),
        Obx(
          () => IconButton(
            icon: Icon(
              controller.isAddUser.value ? Icons.remove : Icons.add,
              color: kprimaryColor,
              size: 20,
            ),
            onPressed: () {
              Utils.hapticFeedback();
              controller.isAddUser.value = !controller.isAddUser.value;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAddContactSection() {
    return Obx(
      () => controller.isAddUser.value
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.emailAddress,
                      controller: controller.emailTextEditingController,
                      decoration: InputDecoration(
                        hintText: 'Enter email address'.tr,
                        prefixIcon: const Icon(
                          Icons.alternate_email,
                          color: kprimaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                themeController.primaryDisabledTextColor.value,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: kprimaryColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final email =
                          controller.emailTextEditingController.text.trim();
                      if (email.isEmpty) return;

                      if (RegExp(
                        r"^[a-zA-Z0-9.a-zA-Z0-9!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+",
                      ).hasMatch(email)) {
                        Utils.hapticFeedback();
                        await IsarDb.addEmail(email);
                        controller.emailTextEditingController.clear();

                        Get.snackbar(
                          'Success'.tr,
                          'Contact added'.tr,
                          backgroundColor: kprimaryColor,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16),
                          duration: const Duration(seconds: 1),
                        );
                      } else {
                        Get.snackbar(
                          'Error'.tr,
                          'Invalid email format'.tr,
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                          margin: const EdgeInsets.all(16),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kprimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(),
    );
  }

  Widget _buildContactsList(BuildContext context) {
    return StreamBuilder(
      stream: IsarDb.getEmails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(
                color: kprimaryColor,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading contacts'.tr,
                style: TextStyle(
                  color: themeController.primaryTextColor.value,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          final userList = snapshot.data;

          if (userList == null || userList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: themeController.primaryDisabledTextColor.value,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No contacts found'.tr,
                      style: TextStyle(
                        color: themeController.primaryTextColor.value,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add contacts to share your alarm'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: themeController.primaryDisabledTextColor.value,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: userList.length,
            itemBuilder: (context, index) {
              return _buildContactTile(userList[index]);
            },
          );
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildContactTile(Saved_Emails email) {
    return Obx(() {
      final isSelected = controller.selectedEmails.contains(email.email);

      return ListTile(
        onTap: () {
          Utils.hapticFeedback();
          if (isSelected) {
            controller.selectedEmails.remove(email.email);
          } else {
            controller.selectedEmails.add(email.email);
          }
        },
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? kprimaryColor
              : themeController.secondaryBackgroundColor.value,
          child: isSelected
              ? const Icon(
                  Icons.check,
                  color: Colors.white,
                )
              : Text(
                  Utils.getInitials(email.username),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kprimaryColor,
                  ),
                ),
        ),
        title: Text(
          email.username,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: themeController.primaryTextColor.value,
          ),
        ),
        subtitle: Text(
          email.email,
          style: TextStyle(
            fontSize: 12,
            color: themeController.primaryDisabledTextColor.value,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline,
            color: Colors.red.withOpacity(0.7),
            size: 20,
          ),
          onPressed: () async {
            Utils.hapticFeedback();

            final confirmed = await Get.dialog<bool>(
                  AlertDialog(
                    backgroundColor:
                        themeController.secondaryBackgroundColor.value,
                    title: Text('Remove contact?'.tr),
                    content: Text(
                      'Are you sure you want to remove ${email.username} from your contacts?'
                          .tr,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(result: false),
                        child: Text(
                          'Cancel'.tr,
                          style: TextStyle(
                            color: themeController.primaryTextColor.value,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Get.back(result: true),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.1),
                        ),
                        child: Text(
                          'Remove'.tr,
                          style: const TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (confirmed) {
              if (controller.selectedEmails.contains(email.email)) {
                controller.selectedEmails.remove(email.email);
              }

              await _deleteEmail(email);
            }
          },
        ),
      );
    });
  }
}
