import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/totp_util.dart';

class TotpLiveSubtitle extends StatefulWidget {
  final String secret;

  const TotpLiveSubtitle({super.key, required this.secret});

  @override
  State<TotpLiveSubtitle> createState() => _TotpLiveSubtitleState();
}

class _TotpLiveSubtitleState extends State<TotpLiveSubtitle> {
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

  @override
  Widget build(BuildContext context) {
    if (!TotpUtil.isValidBase32(widget.secret)) {
      return const Text('Authenticator', style: TextStyle(color: Colors.white54));
    }

    final primaryColor = Theme.of(context).colorScheme.primary;
    final isUrgent = _remainingSeconds <= 5;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _currentCode,
          style: TextStyle(
            fontSize: 16,
            letterSpacing: 2,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: isUrgent ? Colors.redAccent : Colors.white70,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            value: _remainingSeconds / 30.0,
            strokeWidth: 2,
            backgroundColor: Colors.white12,
            color: isUrgent ? Colors.redAccent : primaryColor,
          ),
        ),
      ],
    );
  }
}
