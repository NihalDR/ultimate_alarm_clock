import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ultimate_alarm_clock/app/modules/addOrUpdateAlarm/controllers/add_or_update_alarm_controller.dart';
import 'package:ultimate_alarm_clock/app/modules/settings/controllers/theme_controller.dart';
import 'package:ultimate_alarm_clock/app/utils/constants.dart';
import 'package:ultimate_alarm_clock/app/utils/utils.dart';

class TaskListTile extends StatelessWidget {
  const TaskListTile({
    super.key,
    required this.controller,
    required this.themeController,
  });

  final AddOrUpdateAlarmController controller;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ListTile(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Tasks'.tr,
            style: TextStyle(
              color: themeController.primaryTextColor.value,
            ),
          ),
        ),
        onTap: () {
          Utils.hapticFeedback();
          _openTaskEditor(context);
        },
        trailing: InkWell(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Obx(
                () => Text(
                  controller.alarmTasks.isEmpty
                      ? 'Off'.tr
                      : '${controller.alarmTasks.length} ${'items'.tr}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: controller.alarmTasks.isEmpty
                            ? themeController.primaryDisabledTextColor.value
                            : themeController.primaryTextColor.value,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: controller.alarmTasks.isEmpty
                    ? themeController.primaryDisabledTextColor.value
                    : themeController.primaryTextColor.value,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTaskEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => _TaskListEditorPage(
          controller: controller,
          themeController: themeController,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

class _TaskListEditorPage extends StatefulWidget {
  const _TaskListEditorPage({
    required this.controller,
    required this.themeController,
  });

  final AddOrUpdateAlarmController controller;
  final ThemeController themeController;

  @override
  State<_TaskListEditorPage> createState() => _TaskListEditorPageState();
}

class _TaskListEditorPageState extends State<_TaskListEditorPage> {
  late TextEditingController _inputController;
  late FocusNode _focusNode;
  late List<String> _tasks;
  late List<String> _originalTasks;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _originalTasks = List<String>.from(widget.controller.alarmTasks);
    _tasks = List<String>.from(_originalTasks);
    _inputController = TextEditingController();
    _focusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _focusNode.canRequestFocus) {
          _focusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _updateHasChanges() {
    final hasChanges = !_listEquals(_tasks, _originalTasks);
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  void _addTask() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _tasks.add(text);
      _inputController.clear();
    });
    _updateHasChanges();
  }

  void _removeTask(int index) {
    setState(() {
      _tasks.removeAt(index);
    });
    _updateHasChanges();
  }

  void _saveAndClose() {
    widget.controller.alarmTasks.value = List<String>.from(_tasks);
    widget.controller.alarmTasks.refresh();
    Navigator.of(context).pop();
  }

  void _discardAndClose() {
    Navigator.of(context).pop();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) {
      return true;
    }

    final bool? shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: widget.themeController.secondaryBackgroundColor.value,
          title: Text(
            'Discard changes?'.tr,
            style: TextStyle(
              color: widget.themeController.primaryTextColor.value,
            ),
          ),
          content: Text(
            'You have unsaved changes. Are you sure you want to discard them?'.tr,
            style: TextStyle(
              color: widget.themeController.primaryDisabledTextColor.value,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Keep editing'.tr,
                style: TextStyle(
                  color: widget.themeController.primaryTextColor.value,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Discard',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Obx(
        () => Scaffold(
          backgroundColor: widget.themeController.primaryBackgroundColor.value,
          appBar: AppBar(
            backgroundColor: widget.themeController.primaryBackgroundColor.value,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.close,
                color: widget.themeController.primaryTextColor.value,
              ),
              onPressed: () async {
                Utils.hapticFeedback();
                if (await _onWillPop()) {
                  _discardAndClose();
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: _saveAndClose,
                child: Text(
                  'Save'.tr,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: kprimaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
            title: Text(
              'Tasks'.tr,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addTask(),
                        style: TextStyle(
                          color: widget.themeController.primaryTextColor.value,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add task'.tr,
                          hintStyle: TextStyle(
                            color: widget.themeController
                                .primaryDisabledTextColor.value,
                          ),
                          filled: true,
                          fillColor:
                              widget.themeController.secondaryBackgroundColor.value,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: _addTask,
                      icon: const Icon(Icons.add_circle),
                      color: kprimaryColor,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _tasks.isEmpty
                    ? Center(
                        child: Text(
                          'No tasks added yet'.tr,
                          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                color: widget.themeController
                                    .primaryDisabledTextColor.value,
                              ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) => Divider(
                          color: widget
                              .themeController.primaryDisabledTextColor.value,
                        ),
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(
                              _tasks[index],
                              style: TextStyle(
                                color: widget.themeController
                                    .primaryTextColor.value,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              onPressed: () => _removeTask(index),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
