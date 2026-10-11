import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/speech_service.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';

/// 首页"说一句就记下"。
///
/// - 手机：**按住说话，松手建任务**（US-026）；
/// - 桌面：鼠标按住别扭，改为**点击开始 / 点击结束**（03 §6.4）。
class QuickVoiceButton extends ConsumerStatefulWidget {
  const QuickVoiceButton({super.key});

  @override
  ConsumerState<QuickVoiceButton> createState() => _QuickVoiceButtonState();
}

class _QuickVoiceButtonState extends ConsumerState<QuickVoiceButton> {
  bool _dialogOpen = false;

  @override
  Widget build(BuildContext context) {
    final listening = SpeechService.instance.isListening;
    final desktop = SpeechService.isDesktop;

    final button = Material(
      color: listening ? AppColors.danger : Theme.of(context).colorScheme.primary,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: desktop ? _toggle : null,
        onTapDown: desktop ? null : (_) => _start(),
        onTapUp: desktop ? null : (_) => _finish(),
        onTapCancel: desktop ? null : _finish,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            listening ? Icons.mic : Icons.mic_none,
            color: Colors.white,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: desktop ? '点击说话' : '按住说话',
      child: button,
    );
  }

  Future<void> _toggle() async {
    if (SpeechService.instance.isListening) {
      await _finish();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    if (_dialogOpen) return;
    final error = await SpeechService.instance.start();
    if (error != null) {
      if (mounted) showInfoSnack(context, error);
      return;
    }
    _showOverlay();
  }

  void _showOverlay() {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => const _ListeningDialog(),
    ).whenComplete(() => _dialogOpen = false);
  }

  Future<void> _finish() async {
    final words = await SpeechService.instance.stop();
    if (_dialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _dialogOpen = false;
    }
    if (words.isEmpty) {
      if (mounted) showInfoSnack(context, '没听清，再说一次？');
      return;
    }
    await _create(words);
  }

  Future<void> _create(String title) async {
    final listId = await ref
        .read(listRepositoryProvider)
        .resolveDefaultListId(currentFilter: ref.read(selectedListIdProvider));
    final repo = ref.read(taskRepositoryProvider);
    final id = await repo.createTask(title: title, listId: listId);
    if (!mounted) return;
    showUndoSnack(context, '已添加：$title', () => repo.softDelete(id));
  }
}

class _ListeningDialog extends StatelessWidget {
  const _ListeningDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedBuilder(
          animation: SpeechService.instance,
          builder: (context, _) {
            final svc = SpeechService.instance;
            final words = svc.words;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  svc.isListening ? Icons.mic : Icons.mic_off,
                  size: 36,
                  color: svc.isListening ? AppColors.danger : AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  words.isEmpty ? '正在听…' : words,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: words.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  SpeechService.isDesktop ? '说完点一下麦克风' : '松手就会记下',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
