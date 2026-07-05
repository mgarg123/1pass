import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../generator_service.dart';

class GeneratorScreen extends StatefulWidget {
  final bool isStandalone;
  
  const GeneratorScreen({super.key, this.isStandalone = false});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  double _length = 16;
  bool _uppercase = true;
  bool _lowercase = true;
  bool _numbers = true;
  bool _symbols = true;
  
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    setState(() {
      _generatedPassword = GeneratorService.generate(
        length: _length.toInt(),
        uppercase: _uppercase,
        lowercase: _lowercase,
        numbers: _numbers,
        symbols: _symbols,
      );
    });
  }

  void _copyAndClose() {
    if (widget.isStandalone) {
      Clipboard.setData(ClipboardData(text: _generatedPassword));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password copied to clipboard')),
      );
    } else {
      Navigator.pop(context, _generatedPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password Generator')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
              ),
              child: SelectableText(
                _generatedPassword,
                style: const TextStyle(fontSize: 24, letterSpacing: 2, fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.refresh),
              label: const Text('Regenerate'),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Length: ${_length.toInt()}'),
                Expanded(
                  child: Slider(
                    value: _length,
                    min: 8,
                    max: 64,
                    divisions: 56,
                    onChanged: (val) {
                      setState(() => _length = val);
                      _generate();
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile(
              title: const Text('Uppercase (A-Z)'),
              value: _uppercase,
              onChanged: (val) {
                setState(() => _uppercase = val);
                _generate();
              },
            ),
            SwitchListTile(
              title: const Text('Lowercase (a-z)'),
              value: _lowercase,
              onChanged: (val) {
                setState(() => _lowercase = val);
                _generate();
              },
            ),
            SwitchListTile(
              title: const Text('Numbers (0-9)'),
              value: _numbers,
              onChanged: (val) {
                setState(() => _numbers = val);
                _generate();
              },
            ),
            SwitchListTile(
              title: const Text('Symbols (!@#...)'),
              value: _symbols,
              onChanged: (val) {
                setState(() => _symbols = val);
                _generate();
              },
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: _copyAndClose,
              child: Text(widget.isStandalone ? 'Copy Password' : 'Use Password'),
            ),
          ],
        ),
      ),
    );
  }
}
