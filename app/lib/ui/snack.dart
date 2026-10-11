import 'package:flutter/material.dart';

void showUndoSnack(BuildContext context, String message, VoidCallback onUndo) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: '撤销', onPressed: onUndo),
    ),
  );
}

void showInfoSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
  );
}
