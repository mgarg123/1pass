import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/utils/clipboard_util.dart';
import '../../utils/totp_util.dart';

class TotpDisplay extends StatefulWidget {
  final String secret;

  const TotpDisplay({super.key, required this.secret});

  @override
  State<TotpDisplay> createState() => _TotpDisplayState();
}

class _TotpDisplayState extends State<TotpDisplay> {
  late String _currentCode;
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateTotp();
    _startTimer();
  }

  void _updateTotp() {
    setState(() {
      _currentCode = TotpUtil.generateCode(widget.secret);
      _remainingSeconds = TotpUtil.getRemainingSeconds();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final newRemaining = TotpUtil.getRemainingSeconds();
      if (newRemaining > _remainingSeconds) {
        // Window rolled over, new code generated
        _updateTotp();
      } else {
        setState(() {
          _remainingSeconds = newRemaining;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _copyCode() {
    final codeToCopy = _currentCode.replaceAll(' ', '');
    ClipboardUtil.copyTemporary(codeToCopy);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('2FA Code copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!TotpUtil.isValidBase32(widget.secret)) {
      return const SizedBox.shrink(); // Hide if secret is invalid/empty
    }

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'One-Time Password (2FA)',
              style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _currentCode,
                    style: TextStyle(
                      fontSize: 32,
                      letterSpacing: 4,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: _remainingSeconds <= 5 ? Colors.redAccent : Colors.white,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: _remainingSeconds / 30.0,
                        strokeWidth: 3,
                        backgroundColor: Colors.white12,
                        color: _remainingSeconds <= 5 ? Colors.redAccent : primaryColor,
                      ),
                      Center(
                        child: Text(
                          '$_remainingSeconds',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _remainingSeconds <= 5 ? Colors.redAccent : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.copy),
                  color: Colors.white70,
                  onPressed: _copyCode,
                  tooltip: 'Copy Code',
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
    );
  }
}
