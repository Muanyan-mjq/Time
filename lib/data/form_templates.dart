import 'package:daily/model/repeat_rule.dart';

/// 一键模板：常见纪念日的一整套默认值。
///
/// 每一项都只是**预填**，套用之后每个字段都还能改 —— 模板省的是「起名、
/// 挑配色、定重复和提醒」这几步，不是替用户决定。
class FormTemplate {
  /// chip 上的字
  final String label;
  final String title;

  /// 表单里的「描述」，也是贴在封面上的那句话
  final String headText;

  /// 渐变封面下标，对应 `kCoverGradients`：0恋爱 1家人 2朋友 3工作 4学习 5生日
  final int gradient;

  final RepeatRule repeatRule;

  /// 提前几天提醒。
  final int remindDaysBefore;

  const FormTemplate({
    required this.label,
    required this.title,
    required this.headText,
    required this.gradient,
    required this.repeatRule,
    required this.remindDaysBefore,
  });
}

/// 顺序就是 chip 的顺序：最常用的排前面。
const List<FormTemplate> kFormTemplates = [
  FormTemplate(
    label: '恋爱',
    title: '在一起',
    headText: '往后余生，风雪是你',
    gradient: 0,
    repeatRule: RepeatRule.yearly,
    remindDaysBefore: 3,
  ),
  FormTemplate(
    label: '生日',
    title: '生日快乐',
    headText: '愿你岁岁平安，年年欢喜',
    gradient: 5,
    repeatRule: RepeatRule.yearly,
    remindDaysBefore: 7,
  ),
  FormTemplate(
    label: '结婚',
    title: '结婚纪念',
    headText: '执子之手，与子偕老',
    gradient: 1,
    repeatRule: RepeatRule.yearly,
    remindDaysBefore: 7,
  ),
  FormTemplate(
    label: '入职',
    title: '入职纪念',
    headText: '认真做事的日子都算数',
    gradient: 3,
    repeatRule: RepeatRule.yearly,
    remindDaysBefore: 0,
  ),
  FormTemplate(
    label: '考试倒计时',
    title: '考试倒计时',
    headText: '再坚持一下',
    gradient: 4,
    // 考试不是一个每年都会重来的日子
    repeatRule: RepeatRule.none,
    remindDaysBefore: 1,
  ),
];
