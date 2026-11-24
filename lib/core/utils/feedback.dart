import 'package:flutter/material.dart';

/// Lightweight, non-blocking feedback used across Phase 1 placeholder actions.
void showAppSnackBar(BuildContext context, String message) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        duration: const Duration(milliseconds: 2200),
      ),
    );
}
