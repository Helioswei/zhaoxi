import 'dart:async';

import 'package:flutter/material.dart';

/// 撤销提示条。
///
/// 注意：不能只依赖 [SnackBar.duration] —— 实测在某些环境下
/// ScaffoldMessenger 的自动消失计时器不会生效，提示条会一直挂着。
/// 这里额外挂一个兜底定时器，到点**强制移除**（不依赖动画）。
const _undoDuration = Duration(seconds: 4);
const _fallbackAfter = Duration(seconds: 6);

void showUndoSnack(BuildContext context, String message, VoidCallback onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: _undoDuration,
      action: SnackBarAction(label: '撤销', onPressed: onUndo),
    ),
  );
  _forceRemoveLater(messenger);
}

void showInfoSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
  );
  _forceRemoveLater(messenger);
}

void _forceRemoveLater(ScaffoldMessengerState messenger) {
  Timer(_fallbackAfter, () {
    if (messenger.mounted) messenger.removeCurrentSnackBar();
  });
}
