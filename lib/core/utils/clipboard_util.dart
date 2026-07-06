import 'dart:async';
import 'package:flutter/services.dart';

class ClipboardUtil {
  static Timer? _clipboardTimer;

  /// Copies text to the clipboard and clears it automatically after [duration].
  /// Cancels any previous timers to prevent premature clearing.
  static void copyTemporary(String text, {Duration duration = const Duration(seconds: 30)}) {
    Clipboard.setData(ClipboardData(text: text));
    
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(duration, () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  /// Cancels the clipboard clearing timer if it's running.
  static void cancelTimer() {
    _clipboardTimer?.cancel();
  }
}
