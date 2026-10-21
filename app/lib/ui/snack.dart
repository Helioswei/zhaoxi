import 'dart:async';

import 'package:flutter/material.dart';

/// 撤销提示条。
///
/// 注意：不能只依赖 [SnackBar.duration] —— 实测在某些环境下
/// ScaffoldMessenger 的自动消失计时器不会生效，提示条会一直挂着。
/// 这里额外挂一个兜底定时器，到点**强制移除**（不依赖动画）。
///
/// 设计决定（有意为之，勿改回「不清即堆叠」）：
/// `clearSnackBars()` 会清掉上一条尚未过期的撤销窗口——**以最近一条为准**。
/// 这是可接受的：被顶掉的都可恢复操作（软删除进回收站保留 40 天、完成可再点回），
/// 兜底安全网在数据层，不在 snack 层；反过来堆叠多条 undo 反而让「撤销」语义含糊。
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
