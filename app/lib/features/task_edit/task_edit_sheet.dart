import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dao/list_dao.dart';
import '../../data/db/database.dart';
import '../../domain/day_boundary.dart';
import '../../providers/app_providers.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';

Future<void> openTaskEditSheet(BuildContext context, {Task? task}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
  int? _remindAt;
  bool _noteOpen = false;
  bool _saving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _note = TextEditingController(text: t?.note ?? '');
    _listId = t?.listId ??
        ref.read(selectedListIdProvider) ??
        kFallbackListId;
    _dueAt = t?.dueAt;
    _dueHasTime = t?.dueHasTime ?? false;
    _remindAt = t?.remindAt;
    _noteOpen = (t?.note ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _applyDate(DateTime day) {
    final plan = planDateOnly(day);
    setState(() {
      _dueAt = plan.dueAt;
      _dueHasTime = false;
      _remindAt = plan.remindAt;
    });
  }

  void _clearDate() {
    setState(() {
      _dueAt = null;
      _dueHasTime = false;
      _remindAt = null;
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
    if (_dueAt == null) return;
    final due = DateTime.fromMillisecondsSinceEpoch(_dueAt!);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: due.hour, minute: due.minute),
      helpText: '选择时间',
    );
    if (picked == null) return;
    final withTime =
        DateTime(due.year, due.month, due.day, picked.hour, picked.minute);
    setState(() {
      _dueAt = withTime.millisecondsSinceEpoch;
      _dueHasTime = true;
      _remindAt = _dueAt;
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showInfoSnack(context, '写点什么呢？');
      return;
    }
    setState(() => _saving = true);
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
        dueAt: _dueAt,
        dueHasTime: _dueHasTime,
        remindAt: _remindAt,
      );
    } else {
      await repo.createTask(
        title: title,
        listId: _listId,
        note: noteOrNull,
        dueAt: _dueAt,
        dueHasTime: _dueHasTime,
        remindAt: _remindAt,
      );
      await listRepo.rememberLastUsedList(_listId);
      if (!mounted) return;
      if (_dueAt == null) {
        showInfoSnack(context, '已存到「待定」，可随时补时间');
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final repo = ref.read(taskRepositoryProvider);
    final id = widget.task!.id;
    await repo.softDelete(id);
    if (!mounted) return;
    Navigator.of(context).pop();
    showUndoSnack(context, '已删除', () => repo.restore(id));
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(listsProvider);
    final lists = listsAsync.value ?? const <TaskList>[];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                    onPressed: () => Navigator.of(context).pop(),
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
                      onSelected: (_) => setState(() => _listId = l.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionLabel('标题'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _title,
                      autofocus: !_isEditing,
                      textInputAction: TextInputAction.done,
                      maxLength: 200,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        hintText: '输入或点 🎤 说话…',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  IconButton(
                    tooltip: '语音输入（M2 接入）',
                    onPressed: () =>
                        showInfoSnack(context, '语音输入将在 M2 加入'),
                    icon: const Icon(Icons.mic_none),
                  ),
                ],
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
                  _quickDateChip('下周', 7, fromWeekStart: true),
                  ActionChip(
                    label: const Text('选…'),
                    onPressed: _pickDate,
                  ),
                  ActionChip(
                    label: const Text('不设时间'),
                    onPressed: _clearDate,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _dueSummary(),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (_dueAt != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_dueHasTime ? '改时间' : '加一个具体时间'),
                  ),
                ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _noteOpen = !_noteOpen),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    Icon(_noteOpen ? Icons.expand_less : Icons.expand_more,
                        size: 20),
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
                  decoration: const InputDecoration(
                    hintText: '补充说明（可选）',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('保存', style: TextStyle(fontSize: 17)),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _delete,
                    child: const Text(
                      '删除这条任务',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _quickDateChip(String label, int offsetDays,
      {bool fromWeekStart = false}) {
    final bounds = DayBounds();
    final base = fromWeekStart ? bounds.weekStart : bounds.todayStart;
    final day = DateTime(base.year, base.month, base.day + offsetDays);
    final selected = !_dueHasTime &&
        _dueAt != null &&
        DayBounds(
          DateTime.fromMillisecondsSinceEpoch(_dueAt!),
        ).todayStartMs ==
            DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _applyDate(day),
    );
  }

  String _dueSummary() {
    if (_dueAt == null) return '未设置时间 → 会存到「待定」';
    final due = DateTime.fromMillisecondsSinceEpoch(_dueAt!);
    final date = '${due.year}-${due.month.toString().padLeft(2, '0')}-'
        '${due.day.toString().padLeft(2, '0')}';
    if (!_dueHasTime) return '$date（全天，默认 09:00 提醒）';
    final hm = '${due.hour.toString().padLeft(2, '0')}:'
        '${due.minute.toString().padLeft(2, '0')}';
    return '$date $hm';
  }
}
