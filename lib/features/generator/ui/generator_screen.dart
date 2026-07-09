import 'package:flutter/material.dart';
import '../../../core/utils/clipboard_util.dart';
import '../generator_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum GeneratorMode { characters, words }

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SectionContainer extends StatelessWidget {
  final List<Widget> children;
  const _SectionContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _CustomDivider extends StatelessWidget {
  const _CustomDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: Colors.grey[850],
    );
  }
}

class GeneratorScreen extends StatefulWidget {
  final bool isStandalone;
  
  const GeneratorScreen({super.key, this.isStandalone = false});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  GeneratorMode _mode = GeneratorMode.characters;

  // Characters Mode State
  double _length = 16;
  bool _uppercase = true;
  bool _lowercase = true;
  bool _numbers = true;
  bool _symbols = true;
  
  // Words Mode State
  double _wordCount = 5;
  String _separator = '-';
  bool _capitalizeWords = false;
  bool _includeNumber = false;

  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    setState(() {
      if (_mode == GeneratorMode.characters) {
        _generatedPassword = GeneratorService.generate(
          length: _length.toInt(),
          uppercase: _uppercase,
          lowercase: _lowercase,
          numbers: _numbers,
          symbols: _symbols,
        );
      } else {
        _generatedPassword = GeneratorService.generatePassphrase(
          wordCount: _wordCount.toInt(),
          separator: _separator,
          capitalize: _capitalizeWords,
          includeNumber: _includeNumber,
        );
      }
    });
  }

  void _copyAndClose() {
    if (widget.isStandalone) {
      ClipboardUtil.copyTemporary(_generatedPassword);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password copied to clipboard')),
      );
    } else {
      Navigator.pop(context, _generatedPassword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SegmentedButton<GeneratorMode>(
              segments: const [
                ButtonSegment(
                  value: GeneratorMode.characters,
                  label: Text('Characters'),
                  icon: Icon(Icons.password),
                ),
                ButtonSegment(
                  value: GeneratorMode.words,
                  label: Text('Words (Diceware)'),
                  icon: Icon(Icons.text_fields),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (Set<GeneratorMode> newSelection) {
                setState(() {
                  _mode = newSelection.first;
                  _generate();
                });
              },
            ),
          ),
          const SizedBox(height: 24),
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
          Expanded(
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _mode == GeneratorMode.characters 
                    ? _buildCharactersControls()
                    : _buildWordsControls(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _copyAndClose,
            child: Text(widget.isStandalone ? 'Copy Password' : 'Use Password'),
          ),
        ].animate(interval: 50.ms).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
      ),
    );

    if (widget.isStandalone) {
      return Scaffold(
        appBar: AppBar(title: const Text('Password Generator')),
        body: bodyContent,
      );
    } else {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Password Generator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Expanded(child: bodyContent),
          ],
        ),
      );
    }
  }

  Widget _buildCharactersControls() {
    return Column(
      key: const ValueKey('characters'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Length'),
        _SectionContainer(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_length.toInt()} chars', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Expanded(
                    child: Slider(
                      value: _length,
                      min: 8,
                      max: 64,
                      divisions: 56,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setState(() => _length = val);
                        _generate();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const _SectionHeader('Character Types'),
        _SectionContainer(
          children: [
            SwitchListTile(
              title: const Text('Uppercase (A-Z)'),
              activeColor: Colors.blueAccent,
              value: _uppercase,
              onChanged: (val) {
                setState(() => _uppercase = val);
                _generate();
              },
            ),
            const _CustomDivider(),
            SwitchListTile(
              title: const Text('Lowercase (a-z)'),
              activeColor: Colors.blueAccent,
              value: _lowercase,
              onChanged: (val) {
                setState(() => _lowercase = val);
                _generate();
              },
            ),
            const _CustomDivider(),
            SwitchListTile(
              title: const Text('Numbers (0-9)'),
              activeColor: Colors.blueAccent,
              value: _numbers,
              onChanged: (val) {
                setState(() => _numbers = val);
                _generate();
              },
            ),
            const _CustomDivider(),
            SwitchListTile(
              title: const Text('Symbols (!@#...)'),
              activeColor: Colors.blueAccent,
              value: _symbols,
              onChanged: (val) {
                setState(() => _symbols = val);
                _generate();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWordsControls() {
    return Column(
      key: const ValueKey('words'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Word Count'),
        _SectionContainer(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_wordCount.toInt()} words', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Expanded(
                    child: Slider(
                      value: _wordCount,
                      min: 4,
                      max: 10,
                      divisions: 6,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setState(() => _wordCount = val);
                        _generate();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const _SectionHeader('Options'),
        _SectionContainer(
          children: [
            ListTile(
              title: const Text('Separator'),
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _separator,
                  icon: const Icon(Icons.expand_more, color: Colors.blueAccent),
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 16),
                  items: const [
                    DropdownMenuItem(value: '-', child: Text('Hyphen (-)')),
                    DropdownMenuItem(value: ' ', child: Text('Space ( )')),
                    DropdownMenuItem(value: '_', child: Text('Underscore (_)')),
                    DropdownMenuItem(value: '.', child: Text('Period (.)')),
                    DropdownMenuItem(value: ',', child: Text('Comma (,)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _separator = val);
                      _generate();
                    }
                  },
                ),
              ),
            ),
            const _CustomDivider(),
            SwitchListTile(
              title: const Text('Capitalize Words'),
              subtitle: const Text('e.g. Correct-Horse', style: TextStyle(color: Colors.white54, fontSize: 12)),
              activeColor: Colors.blueAccent,
              value: _capitalizeWords,
              onChanged: (val) {
                setState(() => _capitalizeWords = val);
                _generate();
              },
            ),
            const _CustomDivider(),
            SwitchListTile(
              title: const Text('Include a Number'),
              subtitle: const Text('Randomly appends a number', style: TextStyle(color: Colors.white54, fontSize: 12)),
              activeColor: Colors.blueAccent,
              value: _includeNumber,
              onChanged: (val) {
                setState(() => _includeNumber = val);
                _generate();
              },
            ),
          ],
        ),
      ],
    );
  }
}
