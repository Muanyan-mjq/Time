import 'dart:async';

import 'package:daily/components/bottom_button.dart';
import 'package:daily/components/cover_picker.dart';
import 'package:daily/components/custom_dialog.dart';
import 'package:daily/constants.dart';
import 'package:daily/data/cover_palette.dart';
import 'package:daily/data/covers.dart';
import 'package:daily/data/daily_repository.dart';
import 'package:daily/data/form_templates.dart';
import 'package:daily/data/notifications.dart';
import 'package:daily/model/cover.dart';
import 'package:daily/model/daily.dart';
import 'package:daily/model/repeat_rule.dart';
import 'package:daily/styles/colors.dart';
import 'package:daily/styles/text_style.dart';
import 'package:daily/utils/date_util.dart';
import 'package:daily/utils/haptics.dart';
import 'package:daily/utils/transitions.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';

/// 表单关掉时给上一页的交代。
sealed class FormResult {
  const FormResult();
}

final class FormSaved extends FormResult {
  final Daily daily;

  const FormSaved(this.daily);
}

final class FormDeleted extends FormResult {
  const FormDeleted();
}

/// 新增和编辑共用一个页面 —— 老代码两份 400 行的文件几乎是复制的。
class DailyFormPage extends StatefulWidget {
  /// null = 新增。
  final Daily? daily;

  const DailyFormPage({super.key, this.daily});

  bool get isEdit => daily != null;

  @override
  State<DailyFormPage> createState() => _DailyFormPageState();
}

class _DailyFormPageState extends State<DailyFormPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _headTextController;
  late final TextEditingController _contentController;
  late final StagedCover _cover;
  late DateTime _targetDay;
  late RepeatRule _repeatRule;
  late bool _remindEnabled;
  late int _remindDaysBefore;
  late int _remindHour;
  late int _remindMinute;

  /// 权限状态是全局的，可能被系统在别处改掉，所以两块一起听。
  late final Listenable _perms = Listenable.merge([
    NotificationService.instance.notificationDenied,
    NotificationService.instance.exactAlarmDenied,
  ]);

  bool _saving = false;

  /// 落库成功了。没成功就说明用户是取消/返回，需要把暂存的照片删回去。
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    final d = widget.daily;
    _titleController = TextEditingController(text: d?.title ?? '');
    _headTextController = TextEditingController(text: d?.headText ?? '');
    _contentController = TextEditingController(text: d?.remark ?? '');
    _cover = StagedCover(d?.coverKey);
    _targetDay = d?.date ?? DateTime.now();
    _repeatRule = d?.repeatRule ?? RepeatRule.none;
    _remindEnabled = d?.remindEnabled ?? false;
    _remindDaysBefore = d?.remindDaysBefore ?? 0;
    _remindHour = d?.remindHour ?? kDefaultRemindHour;
    _remindMinute = d?.remindMinute ?? 0;
  }

  @override
  void dispose() {
    if (!_committed) _cover.rollback();
    _titleController.dispose();
    _headTextController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: AppColors.of(context).background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CoverPicker(
                    height: height * 0.25,
                    cover: resolveCover(
                      coverKey: _cover.currentKey,
                      imageUrl: widget.daily?.imageUrl,
                      locate: Covers.instance.locate,
                    ),
                    onPickPhoto: _pickPhoto,
                    onPickGradient: _pickGradient,
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 4,
                    left: 6,
                    child: _iconButton(
                      icon: Icons.arrow_back,
                      // 不带结果 = 什么都没改
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  if (widget.isEdit)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top + 4,
                      right: 15,
                      child: _textButton('删除', _deleteDialog),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (!widget.isEdit) _buildTemplates(),
              _buildSelectItem(
                label: '日期',
                value: fmtStorage(_targetDay),
                onTap: _selectDate,
              ),
              _buildSelectItem(
                label: '重复',
                value: _repeatRule.label,
                onTap: _selectRepeat,
              ),
              _buildRemindSection(),
              _buildInputItem(
                label: '标题',
                placeHolder: '为纪念日写个标题吧~',
                controller: _titleController,
              ),
              _buildInputItem(
                label: '描述',
                placeHolder: '我还没想好要写什么...',
                controller: _headTextController,
              ),
              _buildContentField(),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: BottomButton(
                  text: '保存',
                  height: 60,
                  handleOk: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 一键模板。**只在新增时出现**：编辑一条已经写好的记录时，模板会把
  /// 用户自己填的标题和描述盖掉，那不是方便，是手滑。
  Widget _buildTemplates() {
    final styles = AppTextStyles.of(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kFormTemplates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => StaggerIn(
          index: i,
          offset: 8,
          child: _templateChip(kFormTemplates[i], styles),
        ),
      ),
    );
  }

  Widget _templateChip(FormTemplate template, AppTextStyles styles) {
    final colors = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _applyTemplate(template),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.divider),
        ),
        child: Text(template.label, style: styles.aboutStyle),
      ),
    );
  }

  /// 套模板 = 把几个字段一次填好，**不保存**。日期一个字都不动 ——
  /// 模板不可能知道用户要记的是哪一天。
  void _applyTemplate(FormTemplate template) {
    unawaited(toggleFeedback());
    _titleController.text = template.title;
    _headTextController.text = template.headText;
    _cover.selectGradient(template.gradient);
    setState(() {
      _repeatRule = template.repeatRule;
      // 纪念日 App 的意义就在于到点提醒，模板顺手把提醒也开了；
      // 开关就在下面一行，不想要随时拨回去
      _remindEnabled = true;
      _remindDaysBefore = template.remindDaysBefore;
      _remindHour = kDefaultRemindHour;
      _remindMinute = 0;
    });
    showToast('已套用「${template.label}」，别忘选日期');
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        width: 44,
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _textButton(String text, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Center(child: Text(text, style: AppTextStyles.headTextStyle)),
      ),
    );
  }

  /// _buildSelcetItem
  Widget _buildSelectItem({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final styles = AppTextStyles.of(context);
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onTap,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 60,
                child: Row(
                  children: [
                    Text(label, style: styles.inputLabelStyle),
                    const SizedBox(width: 32),
                    Text(value, style: styles.inputLabelStyle),
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.of(context).onBackgroundMuted),
          ],
        ),
      ),
    );
  }

  /// 提醒。开关关掉时下面两行不占地方 —— 一行「不提醒」比三行灰掉的控件清楚。
  ///
  /// 权限提示挂在权限的 notifier 上：系统里把权限收回去了，这里下一次重建
  /// 就会如实显示，不用退出重进表单。
  Widget _buildRemindSection() {
    return Column(
      children: [
        _buildSwitchItem(
          label: '提醒',
          value: _remindEnabled,
          onChanged: _toggleRemind,
        ),
        if (_remindEnabled) ...[
          _buildSelectItem(
            label: '提前',
            value: _remindDaysBefore == 0 ? '当天' : '提前 $_remindDaysBefore 天',
            onTap: _selectRemindDays,
          ),
          _buildSelectItem(
            label: '时间',
            value: '${fmt2(_remindHour)}:${fmt2(_remindMinute)}',
            onTap: _selectRemindTime,
          ),
          ListenableBuilder(
            listenable: _perms,
            builder: (context, _) => _buildRemindHints(),
          ),
        ],
      ],
    );
  }

  /// 提醒能不能响，有三个前提，任何一个不成立都在这儿说清楚。
  ///
  /// 这些提示存在的理由只有一个：一个亮着的提醒开关却什么都不做，是最让人
  /// 失去信任的失败方式 —— 用户不会发现，直到那个日子安安静静地过去。
  Widget _buildRemindHints() {
    final service = NotificationService.instance;
    final hints = <String>[
      if (service.notificationDenied.value) '系统没有给通知权限，提醒不会响',
      if (service.exactAlarmDenied.value) '系统收回了精确闹钟权限，提醒可能晚几分钟',
      if (!_remindWillFire) '这个日期（含提前天数）已经过去了，不会响 —— 改成「每年」就能每年提醒你',
    ];
    if (hints.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final h in hints)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 13, color: AppColors.of(context).onBackgroundFaint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(h, style: AppTextStyles.of(context).emptyHintStyle),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 提醒排下去的那一刻会不会真的响。和 `NotificationService._remindAt` 同一个
  /// 判断口径：非重复记录的日期一旦过去，排班时会跳过它。
  bool get _remindWillFire {
    final at = DateTime(_targetDay.year, _targetDay.month, _targetDay.day, _remindHour, _remindMinute)
        .subtract(Duration(days: _remindDaysBefore));
    return at.isAfter(DateTime.now());
  }

  Widget _buildSwitchItem({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              // 整行可点，不然只有那个小滑块可点，很容易按空
              onTap: () => onChanged(!value),
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width - 100,
                child: Text(label, style: AppTextStyles.of(context).inputLabelStyle),
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRemind(bool value) async {
    unawaited(toggleFeedback());
    setState(() => _remindEnabled = value);
    // 只在打开的时候问权限：关掉提醒还要弹一次权限框就纯属骚扰
    if (value) await NotificationService.instance.requestPermissions();
  }

  Future<void> _selectRemindDays() async {
    const options = [0, 1, 2, 3, 7, 14];
    final picked = await showModalBottomSheet<int>(
      context: context,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final days in options)
              ListTile(
                title: Text(
                  days == 0 ? '当天' : '提前 $days 天',
                  style: AppTextStyles.of(ctx).aboutMiddleStyle,
                ),
                trailing: days == _remindDaysBefore
                    ? Icon(Icons.check, size: 20, color: AppColors.of(ctx).onBackground)
                    : null,
                onTap: () => Navigator.pop(ctx, days),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      unawaited(toggleFeedback());
      setState(() => _remindDaysBefore = picked);
    }
  }

  Future<void> _selectRemindTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _remindHour, minute: _remindMinute),
    );
    if (picked != null && mounted) {
      unawaited(toggleFeedback());
      setState(() {
        _remindHour = picked.hour;
        _remindMinute = picked.minute;
      });
    }
  }

  // Input Item
  Widget _buildInputItem({
    required String label,
    required String placeHolder,
    required TextEditingController controller,
  }) {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return SizedBox(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Text(label, style: styles.inputLabelStyle),
            const SizedBox(width: 20),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.text,
                style: styles.inputValueStyle,
                decoration: InputDecoration(
                  hintText: placeHolder,
                  hintStyle: styles.inputHintStyle,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                  // 用 ValueListenableBuilder 局部刷新，避免每敲一个字符
                  // 就 setState 重建整个表单（包括封面图）
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            onTap: controller.clear,
                            child: Icon(Icons.cancel, size: 18, color: colors.onBackground),
                          ),
                  ),
                ),
                // 老代码用的是近乎透明的浅灰，光标基本看不见
                cursorColor: colors.onBackgroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Content
  Widget _buildContentField() {
    final colors = AppColors.of(context);
    final styles = AppTextStyles.of(context);
    return Container(
      height: 170,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          maxLines: 5,
          maxLength: 500,
          controller: _contentController,
          cursorColor: colors.onBackgroundMuted,
          style: styles.inputValueStyle,
          decoration: InputDecoration(
            hintText: '在这里写下有关这个日子的故事吧～',
            hintStyle: styles.inputHintStyle,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(10),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDay,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );
    if (picked != null && mounted) {
      unawaited(toggleFeedback());
      setState(() => _targetDay = picked);
    }
  }

  Future<void> _selectRepeat() async {
    final picked = await showModalBottomSheet<RepeatRule>(
      context: context,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        final styles = AppTextStyles.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final rule in RepeatRule.values)
                ListTile(
                  title: Text(rule.label, style: styles.aboutMiddleStyle),
                  trailing: rule == _repeatRule
                      ? Icon(Icons.check, size: 20, color: colors.onBackground)
                      : null,
                  onTap: () => Navigator.pop(ctx, rule),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) {
      unawaited(toggleFeedback());
      setState(() => _repeatRule = picked);
    }
  }

  Future<void> _pickPhoto() async {
    final key = await _cover.pickPhoto();
    // key == null 说明用户在相册里取消了
    if (key != null && mounted) setState(() {});
  }

  void _pickGradient(int index) {
    _cover.selectGradient(index);
    setState(() {});
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty) {
      showToast('标题名是必须填写的哦～');
      return;
    }
    // 防连点：不然一次双击会插两条
    if (_saving) return;
    setState(() => _saving = true);

    var daily = Daily(
      id: widget.daily?.id ?? 0,
      title: _titleController.text,
      headText: _headTextController.text.isEmpty ? kDefaultHeadText : _headTextController.text,
      targetDay: fmtStorage(_targetDay),
      remark: _contentController.text.isEmpty ? kDefaultRemark : _contentController.text,
      coverKey: _cover.currentKey,
      repeatRule: _repeatRule,
      remindEnabled: _remindEnabled,
      remindDaysBefore: _remindDaysBefore,
      remindHour: _remindHour,
      remindMinute: _remindMinute,
    );

    final repo = DailyRepository.instance;
    if (widget.isEdit) {
      final ok = await repo.update(daily);
      if (!ok) {
        if (mounted) setState(() => _saving = false);
        showToast('修改失败，请重试');
        return;
      }
    } else {
      daily = daily.copyWith(id: await repo.insert(daily));
    }

    // 数据库写成功之后才动文件：先删文件再写库，写库失败就没图了
    await _cover.commit();
    _committed = true;

    unawaited(successFeedback());
    showToast(widget.isEdit ? '修改成功' : '添加成功');
    if (mounted) Navigator.pop(context, FormSaved(daily));
  }

  /// 确认框走全 App 共用的 `confirmDelete` —— 长按菜单里的删除也是同一个，
  /// 两处的文案和交互因此不会各自漂移。
  Future<void> _deleteDialog() async {
    if (!await confirmDelete(context)) return;
    await _delete();
  }

  Future<void> _delete() async {
    unawaited(warningFeedback());
    final old = widget.daily!.coverKey;
    await DailyRepository.instance.delete(widget.daily!.id);
    // 数据库删成功之后再删文件
    _cover.rollback();
    if (old != null && old.startsWith(kPhotoPrefix)) {
      await Covers.instance.remove(old);
    }
    // 记录已经没了，dispose 里不该再做回滚
    _committed = true;
    showToast('删除成功');
    if (mounted) Navigator.pop(context, const FormDeleted());
  }
}
