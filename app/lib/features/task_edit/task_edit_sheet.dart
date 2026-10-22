import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dao/list_dao.dart';
import '../../data/db/database.dart';
import '../../domain/day_boundary.dart';
import '../../domain/repeat_rule.dart';
import '../../providers/app_providers.dart';
import '../../services/notification_service.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';

Future<void> openTaskEditSheet(BuildContext context, {Task? task}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.tokens.sheetRadius),
      ),
    ),
    builder: (_) => TaskEditSheet(task: task),
  );
}

class TaskEditSheet extends ConsumerStatefulWidget {
  const TaskEditSheet({super.key, this.task});

  final Task? task;

  @override
  ConsumerState<TaskEditSheet> createState() => _TaskEditSheetState();
}

class _TaskEditSheetState extends ConsumerState<TaskEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late String _listId;
  int? _dueAt;
  bool _dueHasTime = false;
  late int _offsetMinutes;
  bool _noteOpen = false;
  bool _saving = false;
  bool _canPop = false;
  RepeatRule? _repeat;

  // 初值快照：用于判断「有没有改动过」，决定关闭前要不要确认。
  String _originalTitle = '';
  String _originalNote = '';
  late String _originalListId;
  int? _originalDueAt;
  bool _originalDueHasTime = false;
  late int _originalOffsetMinutes;
  String? _originalRepeatRule;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _note = TextEditingController(text: t?.note ?? '');
    _listId =
        t?.listId ?? ref.read(selectedListIdProvider) ?? kDefaultNewTaskListId;
    _dueAt = t?.dueAt ?? planDateOnly(DayBounds().todayStart).dueAt;
    _dueHasTime = t?.dueHasTime ?? false;
    _noteOpen = (t?.note ?? '').isNotEmpty;
    _repeat = RepeatRule.decode(t?.repeatRule);

    // 默认提前量取自设置；编辑已有任务时按它实际存的提醒反推。
    _offsetMinutes = ref.read(remindOffsetProvider);
    if (t?.dueAt != null && t?.remindAt != null) {
      final inferred =
          ((_baseRemindAt(t!.dueAt!, t.dueHasTime) - t.remindAt!) / 60000)
              .round();
      if (inferred >= 0) _offsetMinutes = inferred;
    }

    _originalTitle = _title.text;
    _originalNote = _note.text;
    _originalListId = _listId;
    _originalDueAt = _dueAt;
    _originalDueHasTime = _dueHasTime;
    _originalOffsetMinutes = _offsetMinutes;
    _originalRepeatRule = t?.repeatRule;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  static int _baseRemindAt(int dueAt, bool dueHasTime) => dueHasTime
      ? dueAt
      : planDateOnly(DateTime.fromMillisecondsSinceEpoch(dueAt)).remindAt;

  /// 实际写入的提醒时间：日期型以当天 09:00 为基准，再减去提前量。
  int get _remindAt =>
      _baseRemindAt(_dueAt!, _dueHasTime) - _offsetMinutes * 60000;

  void _applyDate(DateTime day) {
    setState(() {
      _dueAt = planDateOnly(day).dueAt;
      _dueHasTime = false;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: '选择日期',
    );
    if (picked != null) _applyDate(picked);
  }

  Future<void> _pickTime() async {
    final dueAt = _dueAt;
    if (dueAt == null) return;
    final due = DateTime.fromMillisecondsSinceEpoch(dueAt);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: due.hour, minute: due.minute),
      helpText: '选择时间',
    );
    if (picked == null) return;
    setState(() {
      _dueAt = DateTime(
        due.year,
        due.month,
        due.day,
        picked.hour,
        picked.minute,
      ).millisecondsSinceEpoch;
      _dueHasTime = true;
    });
  }

  /// 用户动了任何东西（标题 / 备注 / 清单 / 时间 / 提前量 / 重复）就算有未保存输入。
  bool _hasUnsavedInput() =>
      _title.text != _originalTitle ||
      _note.text != _originalNote ||
      _listId != _originalListId ||
      _dueAt != _originalDueAt ||
      _dueHasTime != _originalDueHasTime ||
      _offsetMinutes != _originalOffsetMinutes ||
      _repeat?.encode() != _originalRepeatRule;

  /// 关闭入口（✕ / 下滑 / 返回手势都走这里）：有输入先问一嘴，别让人白打字。
  Future<void> _requestClose() async {
    if (!_hasUnsavedInput()) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃这次编辑？'),
        content: const Text('输入的内容不会被保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) _closeAfterLeaveGuard();
  }

  /// PopScope 设了 canPop:false，真正离开前先放行。
  void _closeAfterLeaveGuard() {
    setState(() => _canPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showInfoSnack(context, '写点什么呢？');
      return;
    }
    setState(() => _saving = true);

    final remindAt = _remindAt;
    // 首次设置提醒时再申请权限；被拒就当场说清楚，别让人以为提醒会响。
    final granted = await NotificationService.instance.requestPermissions();
    if (!granted && mounted) {
      showInfoSnack(context, '提醒可能不会响：通知权限没打开，可在设置里开启');
    }

    final repo = ref.read(taskRepositoryProvider);
    final listRepo = ref.read(listRepositoryProvider);
    final note = _note.text.trim();
    final noteOrNull = note.isEmpty ? null : note;

    if (_isEditing) {
      await repo.updateTask(
        id: widget.task!.id,
        title: title,
        listId: _listId,
        note: noteOrNull,
        dueAt: _dueAt!,
        dueHasTime: _dueHasTime,
        remindAt: remindAt,
        repeatRule: _repeat?.encode(),
      );
    } else {
      await repo.createTask(
        title: title,
        listId: _listId,
        note: noteOrNull,
        dueAt: _dueAt!,
        dueHasTime: _dueHasTime,
        remindAt: remindAt,
        repeatRule: _repeat?.encode(),
      );
      await listRepo.rememberLastUsedList(_listId);
    }
    if (!mounted) return;
    setState(() => _canPop = true); // 已保存，直接走，不用询问
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final repo = ref.read(taskRepositoryProvider);
    final id = widget.task!.id;
    await repo.softDelete(id);
    if (!mounted) return;
    setState(() => _canPop = true);
    Navigator.of(context).pop();
    showUndoSnack(context, '已删除', () => repo.restore(id));
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider).value ?? const <TaskList>[];
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final navInset = MediaQuery.paddingOf(context).bottom;

    // 弹层最高只长到「状态栏下方 24px」：键盘越高可用越小（内容滚动），
    // 顶部不再上移、不与状态栏重叠；极小屏兜底至少 200 逻辑像素。
    final maxContentHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).top -
        24 -
        bottomInset -
        navInset;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _requestClose();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxContentHeight.clamp(200, double.infinity),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isEditing ? '编辑任务' : '新建任务',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: '关闭',
                              onPressed: _requestClose,
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _sectionLabel('清单'),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final l in lists)
                              ChoiceChip(
                                label: Text(l.name),
                                selected: _listId == l.id,
                                onSelected: (_) =>
                                    setState(() => _listId = l.id),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _title,
                          autofocus: !_isEditing,
                          textInputAction: TextInputAction.done,
                          maxLength: 200,
                          style: const TextStyle(fontSize: 18),
                          decoration: const InputDecoration(
                            hintText: '要做什么？',
                            counterText: '',
                          ),
                          onSubmitted: (_) => _save(),
                        ),
                        const SizedBox(height: 12),
                        _sectionLabel('时间'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _quickDateChip('今天', 0),
                            _quickDateChip('明天', 1),
                            _quickDateChip('后天', 2),
                            _quickDateChip('下周', 0, fromWeekStart: true),
                            ActionChip(
                              label: const Text('选…'),
                              onPressed: _pickDate,
                            ),
                          ],
                        ),
                        // 具体时间属于「时间」：设置的是到点时间，不是提前量。
                        TextButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(_dueHasTime ? '改具体时间' : '加一个具体时间'),
                        ),
                        const SizedBox(height: 4),
                        _sectionLabel('提醒'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            for (final m in const [0, 5, 15, 30])
                              ChoiceChip(
                                label: Text(m == 0 ? '准时' : '提前 $m 分'),
                                selected: _offsetMinutes == m,
                                onSelected: (_) =>
                                    setState(() => _offsetMinutes = m),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dueSummary(),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _sectionLabel('重复'),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('不重复'),
                              selected: _repeat == null,
                              onSelected: (_) => setState(() => _repeat = null),
                            ),
                            _repeatChip('每天', () => RepeatRule.daily()),
                            _repeatChip(
                              '每周',
                              () => RepeatRule.weekly(
                                _dueAt == null
                                    ? DateTime.now()
                                    : DateTime.fromMillisecondsSinceEpoch(
                                        _dueAt!,
                                      ),
                              ),
                            ),
                            _repeatChip('每月', () => RepeatRule.monthly()),
                            _repeatIntervalChip(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(() => _noteOpen = !_noteOpen),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Icon(
                                _noteOpen
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              const Text('备注'),
                            ],
                          ),
                        ),
                        if (_noteOpen) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _note,
                            maxLines: 4,
                            maxLength: 2000,
                            decoration: InputDecoration(
                              hintText: '补充说明（可选）',
                              filled: true,
                              fillColor: context.appBackground,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving ? '正在保存…' : '保存',
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _delete,
                            child: Text(
                              '删除这条任务',
                              style: TextStyle(color: context.colors.error),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// T-5：「每 N 天」的入口。数据层早就有（`RepeatRule.everyDays`），这里补 UI。
  ///
  /// 选中后芯片直接显示「每 3 天」，不用另外再弹一次确认。
  Widget _repeatIntervalChip() {
    final days = _repeat?.freq == RepeatFreq.interval
        ? _repeat!.intervalDays
        : null;
    return ChoiceChip(
      label: Text(days == null ? '每 N 天' : '每 $days 天'),
      selected: days != null,
      onSelected: (_) => _pickInterval(days),
    );
  }

  Future<void> _pickInterval(int? current) async {
    // 常用值一点就好；当前值不在表里时补进去，免得编辑已有任务时选不到。
    final options = <int>{
      2, 3, 4, 5, 6, 7, 10, 14, 30,
      ?current,
    }.toList()..sort();

    // 弹层关掉后焦点会回到标题输入框、把键盘顶出来，先手动收一次。
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.colors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.tokens.sheetRadius),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '隔几天重复？',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                '比如「每 2 天浇花」：勾完这一条，隔 2 天再提醒。',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in options)
                    ChoiceChip(
                      label: Text('$d 天'),
                      selected: d == current,
                      onSelected: (_) => Navigator.pop(ctx, d),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    FocusManager.instance.primaryFocus?.unfocus();
    if (picked == null || !mounted) return;
    setState(() => _repeat = RepeatRule.everyDays(picked));
  }

  Widget _repeatChip(String label, RepeatRule Function() build) {
    final rule = build();
    return ChoiceChip(
      label: Text(label),
      selected: _repeat?.freq == rule.freq,
      onSelected: (_) => setState(() => _repeat = rule),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );

  Widget _quickDateChip(
    String label,
    int offsetDays, {
    bool fromWeekStart = false,
  }) {
    final bounds = DayBounds();
    final base = fromWeekStart ? bounds.weekStart : bounds.todayStart;
    final day = DateTime(base.year, base.month, base.day + offsetDays);
    final dayMs = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final selected =
        !_dueHasTime &&
        _dueAt != null &&
        DayBounds(DateTime.fromMillisecondsSinceEpoch(_dueAt!)).todayStartMs ==
            dayMs;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _applyDate(day),
    );
  }

  String _dueSummary() {
    final due = DateTime.fromMillisecondsSinceEpoch(_dueAt!);
    final date = '${due.month}月${due.day}日';
    return _dueHasTime ? '$date ${_hm(due)}' : '$date（全天）';
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
