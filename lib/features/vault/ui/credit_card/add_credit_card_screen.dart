import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/vault_entry.dart';
import '../../models/entry_type.dart';
import '../../providers/vault_provider.dart';
import '../widgets/credit_card_widget.dart';

class AddCreditCardScreen extends ConsumerStatefulWidget {
  final VaultEntry? entry;

  const AddCreditCardScreen({super.key, this.entry});

  @override
  ConsumerState<AddCreditCardScreen> createState() => _AddCreditCardScreenState();
}

class _AddCreditCardScreenState extends ConsumerState<AddCreditCardScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _cardNumberController;
  late TextEditingController _cardholderNameController;
  late TextEditingController _expiryDateController;
  late TextEditingController _cvvController;
  late TextEditingController _pinController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;
  TextEditingController? _bankNameController;

  static const List<String> _bankOptions = [
    'State Bank of India', 'Bank of Baroda', 'Bank of India', 'Bank of Maharashtra', 
    'Canara Bank', 'Central Bank of India', 'Indian Bank', 'Indian Overseas Bank', 
    'Punjab National Bank', 'Punjab & Sind Bank', 'UCO Bank', 'Union Bank of India', 
    'Axis Bank', 'HDFC Bank', 'ICICI Bank', 'Kotak Mahindra Bank', 'IndusInd Bank', 
    'IDFC FIRST Bank', 'Yes Bank', 'Federal Bank', 'South Indian Bank', 'Karnataka Bank', 
    'Karur Vysya Bank', 'City Union Bank', 'Tamilnad Mercantile Bank', 'Dhanlaxmi Bank', 
    'CSB Bank', 'Jammu & Kashmir Bank', 'RBL Bank', 'Nainital Bank', 'Bandhan Bank', 
    'DBS Bank India', 'AU Small Finance Bank', 'Equitas Small Finance Bank', 
    'ESAF Small Finance Bank', 'Jana Small Finance Bank', 'Suryoday Small Finance Bank', 
    'Ujjivan Small Finance Bank', 'Utkarsh Small Finance Bank', 'Unity Small Finance Bank', 
    'Shivalik Small Finance Bank', 'Capital Small Finance Bank', 'North East Small Finance Bank', 
    'India Post Payments Bank', 'Airtel Payments Bank', 'Fino Payments Bank', 'NSDL Payments Bank',
    'Chase', 'Bank of America', 'Wells Fargo', 'Citibank', 'Capital One', 
    'American Express', 'Discover', 'US Bank', 'PNC Bank', 'HSBC', 'Barclays', 
    'Lloyds Bank', 'NatWest', 'Standard Chartered', 'Santander', 'BNP Paribas', 
    'ING', 'RBC', 'TD Bank'
  ];

  bool _isSaving = false;
  bool _isDeleting = false;
  bool _obscureCvv = true;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    
    String formattedCardNumber = widget.entry?.cardNumber ?? '';
    if (formattedCardNumber.isNotEmpty) {
      final clean = formattedCardNumber.replaceAll(RegExp(r'\s+'), '');
      final buffer = StringBuffer();
      for (int i = 0; i < clean.length; i++) {
        if (i > 0 && i % 4 == 0) buffer.write(' ');
        buffer.write(clean[i]);
      }
      formattedCardNumber = buffer.toString();
    }
    _cardNumberController = TextEditingController(text: formattedCardNumber);
    _cardholderNameController = TextEditingController(text: widget.entry?.cardholderName ?? '');
    _expiryDateController = TextEditingController(text: widget.entry?.expiryDate ?? '');
    _cvvController = TextEditingController(text: widget.entry?.cvv ?? '');
    _pinController = TextEditingController(text: widget.entry?.pin ?? '');
    _notesController = TextEditingController(text: widget.entry?.notes ?? '');
    _tagsController = TextEditingController(text: widget.entry?.tags.join(', ') ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cardNumberController.dispose();
    _cardholderNameController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _pinController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);

    final tags = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final now = DateTime.now().toUtc();
    DateTime newUpdatedAt = now;
    if (widget.entry != null && !newUpdatedAt.isAfter(widget.entry!.updatedAt)) {
      newUpdatedAt = widget.entry!.updatedAt.add(const Duration(milliseconds: 1));
    }

    final newEntry = VaultEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      type: EntryType.creditCard,
      title: _titleController.text.isNotEmpty ? _titleController.text : 'Credit Card',
      username: '',
      password: '',
      cardNumber: _cardNumberController.text.replaceAll(RegExp(r'\s+'), ''),
      cardholderName: _cardholderNameController.text,
      expiryDate: _expiryDateController.text,
      cvv: _cvvController.text,
      pin: _pinController.text.isEmpty ? null : _pinController.text,
      bankName: _bankNameController?.text.isEmpty ?? true ? null : _bankNameController!.text.trim(),
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      tags: tags,
      createdAt: widget.entry?.createdAt ?? now,
      updatedAt: newUpdatedAt,
    );

    try {
      await ref.read(vaultProvider.notifier).saveEntry(newEntry);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save credit card: $e')));
      }
    }
  }

  Future<void> _delete() async {
    if (widget.entry == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Credit Card?'),
        content: const Text('Are you sure you want to delete this credit card?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isDeleting = true);
      try {
        await ref.read(vaultProvider.notifier).deleteEntry(widget.entry!.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          setState(() => _isDeleting = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete entry. Please try again.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Add Credit Card' : 'Edit Credit Card'),
        actions: [
          if (widget.entry != null)
            _isDeleting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: _isSaving ? null : _delete,
                  ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _isDeleting ? null : _save,
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CreditCardWidget(
                bankName: _bankNameController?.text.trim() ?? widget.entry?.bankName,
                cardNumber: _cardNumberController.text,
                cardholderName: _cardholderNameController.text,
                expiryDate: _expiryDateController.text,
                cvv: _cvvController.text,
                obscureCvv: _obscureCvv,
                onCvvToggle: () => setState(() => _obscureCvv = !_obscureCvv),
              ),
              const SizedBox(height: 24),
              Card(
                margin: const EdgeInsets.only(bottom: 24),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: widget.entry?.bankName ?? ''),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _bankOptions.where((String option) {
                            return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (String selection) {
                          setState(() {});
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          _bankNameController = controller;
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Bank / Issuer Name',
                              prefixIcon: Icon(Icons.account_balance),
                            ),
                            onChanged: (_) => setState(() {}),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [TitleCaseTextFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Title * (e.g. Personal Chase Sapphire)',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cardNumberController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          CardNumberFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Card Number *',
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          if (val.replaceAll(RegExp(r'\s+'), '').length < 14) return 'Card number too short';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _cardholderNameController,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [UpperCaseTextFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Cardholder Name *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expiryDateController,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: 'Expiry (MM/YY) *',
                                prefixIcon: Icon(Icons.date_range),
                              ),
                              inputFormatters: [ExpiryDateFormatter()],
                              onChanged: (_) => setState(() {}),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Required';
                                if (val.length != 5) return 'Invalid expiry date (MM/YY)';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _cvvController,
                              keyboardType: TextInputType.number,
                              obscureText: _obscureCvv,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: InputDecoration(
                                labelText: 'CVV *',
                                prefixIcon: const Icon(Icons.security),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureCvv ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscureCvv = !_obscureCvv),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Required';
                                final cardLen = _cardNumberController.text.replaceAll(RegExp(r'\s+'), '').length;
                                if (cardLen == 15) {
                                  if (val.length != 4) return 'CVV must be 4 digits';
                                } else if (cardLen >= 16) {
                                  if (val.length != 3) return 'CVV must be 3 digits';
                                } else if (val.length < 3) {
                                  return 'CVV must be 3 or 4 digits';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: _obscurePin,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Card PIN (optional)',
                          prefixIcon: const Icon(Icons.dialpad),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscurePin = !_obscurePin),
                          ),
                        ),
                        validator: (val) {
                          if (val != null && val.isNotEmpty && val.length < 4) {
                            return 'PIN must be at least 4 digits';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ].animate(interval: 50.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
          ),
        ),
      ),
    );
  }
}

class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    if (oldText.length > newText.length) {
      if (oldText.endsWith('/') && newText.length == 2 && newValue.selection.end == 2) {
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    }

    String cleaned = newText.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length > 4) {
      cleaned = cleaned.substring(0, 4);
    }

    String formatted = '';
    for (int i = 0; i < cleaned.length; i++) {
      if (i == 0) {
        if (int.parse(cleaned[0]) > 1) {
          formatted += '0${cleaned[0]}/';
        } else {
          formatted += cleaned[0];
        }
      } else if (i == 1) {
        formatted += cleaned[1];
        if (cleaned.length == 2 && formatted.length == 2) { 
           formatted += '/';
        } else if (cleaned.length > 2 && !formatted.contains('/')) {
           formatted += '/';
        }
      } else {
        formatted += cleaned[i];
      }
    }

    if (cleaned.length >= 2 && cleaned[0] == '1' && int.parse(cleaned[1]) > 2) {
      return oldValue;
    }

    int digitsBeforeCursor = 0;
    for (int i = 0; i < newValue.selection.end && i < newText.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(newText[i])) {
        digitsBeforeCursor++;
      }
    }
    
    if (cleaned.isNotEmpty && int.parse(cleaned[0]) > 1 && digitsBeforeCursor > 0 && oldText.isEmpty) {
        digitsBeforeCursor++;
    }

    int newSelection = 0;
    int digitsSeen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (digitsSeen == digitsBeforeCursor) {
        break;
      }
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        digitsSeen++;
      }
      newSelection++;
    }

    if (newSelection < formatted.length && formatted[newSelection] == '/') {
      newSelection++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newSelection),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class TitleCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String text = newValue.text;
    StringBuffer buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      if (text[i] == ' ') {
        capitalizeNext = true;
        buffer.write(text[i]);
      } else if (capitalizeNext) {
        buffer.write(text[i].toUpperCase());
        capitalizeNext = false;
      } else {
        buffer.write(text[i]);
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: newValue.selection,
    );
  }
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final oldText = oldValue.text;
    final newText = newValue.text;

    if (oldText.length > newText.length && oldText.endsWith(' ') && newText.endsWith(' ') && newValue.selection.end == newText.length) {
      // Allow seamless backspacing over spaces
      return TextEditingValue(
        text: newText.substring(0, newText.length - 1),
        selection: TextSelection.collapsed(offset: newText.length - 1),
      );
    }

    String cleaned = newText.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length > 19) {
      cleaned = cleaned.substring(0, 19);
    }
    
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(cleaned[i]);
    }

    String formatted = buffer.toString();

    int digitsBeforeCursor = 0;
    for (int i = 0; i < newValue.selection.end && i < newText.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(newText[i])) {
        digitsBeforeCursor++;
      }
    }

    int newSelection = 0;
    int digitsSeen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (digitsSeen == digitsBeforeCursor) {
        break;
      }
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        digitsSeen++;
      }
      newSelection++;
    }

    if (newSelection < formatted.length && formatted[newSelection] == ' ') {
      newSelection++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newSelection),
    );
  }
}
