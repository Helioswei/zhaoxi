import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/speech_service.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';

/// 首页语音：**点击开始 / 点击结束**（与编辑页麦克风一致）。
///
/// 之前是"按住说话、松手建任务"，但弹出监听浮层会打断按压手势
/// （Android 上 onTapCancel），导致一按下就结束 → "没听清"。
/// 改成点击式后不再受手势影响；并且引擎因静音自动结束时也会自动建任务。
class QuickVoiceButton extends ConsumerStatefulWidget {
  const QuickVoiceButton({super.key});

  @override
  ConsumerState<QuickVoiceButton> createState() => _QuickVoiceButtonState();
}

class _QuickVoiceButtonState extends ConsumerState<QuickVoiceButton> {
  bool _dialogOpen = false;
  bool _finishing = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    SpeechService.instance.addListener(_onSpeechChanged);
  }

  @override
  void dispose() {
    SpeechService.instance.removeListener(_onSpeechChanged);
    super.dispose();
  }

  void _onSpeechChanged() {
    final svc = SpeechService.instance;
    if (mounted) setState(() => _listening = svc.isListening);

    // 引擎自己停了（说完静音 / 出错）→ 自动收尾
    if (!svc.isListening && _dialogOpen && !_finishing) {
      _finish();
    }
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
    if (!mounted) return;
    _showOverlay();
  }

  void _showOverlay() {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (ctx) => _ListeningDialog(onStop: _finish),
    ).whenComplete(() {
      _dialogOpen = false;
    });
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final svc = SpeechService.instance;
    final words = await svc.stop();
    final error = svc.errorMessage;

    if (_dialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      _dialogOpen = false;
    }

    if (!mounted) {
      _finishing = false;
      return;
    }
    if (words.isEmpty) {
      showInfoSnack(context, error ?? '没听清，再说一次？');
    } else {
      await _create(words);
    }
    _finishing = false;
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

  @override
  Widget build(BuildContext context) {
    final listening = _listening || SpeechService.instance.isListening;
    return Semantics(
      button: true,
      label: listening ? '结束语音' : '语音输入',
      child: Material(
        color: listening ? context.colors.error : context.colors.primary,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggle,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              listening ? Icons.stop : Icons.mic_none,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ListeningDialog extends StatelessWidget {
  const _ListeningDialog({required this.onStop});

  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                  color: svc.isListening
                      ? context.colors.error
                      : context.colors.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  words.isEmpty ? '正在听…' : words,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: words.isEmpty
                        ? context.colors.onSurfaceVariant
                        : context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '说完点「停止」；停一会儿也会自动结束',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop),
                    label: const Text('停止'),
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
