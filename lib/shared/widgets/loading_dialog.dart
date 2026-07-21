import 'package:flutter/material.dart';

void showLoadingDialog(
  BuildContext context, {
  String message = 'Please wait...',
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
