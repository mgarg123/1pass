import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/vault_entry.dart';
import '../../models/entry_type.dart';
import '../../providers/vault_provider.dart';

class AddEditIdentityScreen extends ConsumerStatefulWidget {
  final VaultEntry? entry;

  const AddEditIdentityScreen({super.key, this.entry});

  @override
  ConsumerState<AddEditIdentityScreen> createState() => _AddEditIdentityScreenState();
}

class _AddEditIdentityScreenState extends ConsumerState<AddEditIdentityScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _identityTitleController; // Mr, Mrs, Dr
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _genderController;
  late TextEditingController _birthDateController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalCodeController;
  late TextEditingController _countryController;
  late TextEditingController _passportController;
  late TextEditingController _nationalIdController;
  late TextEditingController _licenseController;
  late TextEditingController _companyController;
  late TextEditingController _occupationController;
  late TextEditingController _notesController;
  late TextEditingController _tagsController;
  late List<CustomField> _customFields;

  bool _isFavorite = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _customFields = List<CustomField>.from(e?.customFields ?? []);
    _titleController = TextEditingController(text: e?.title ?? '');
    _identityTitleController = TextEditingController(text: e?.identityTitle ?? '');
    _firstNameController = TextEditingController(text: e?.identityFirstName ?? '');
    _middleNameController = TextEditingController(text: e?.identityMiddleName ?? '');
    _lastNameController = TextEditingController(text: e?.identityLastName ?? '');
    _genderController = TextEditingController(text: e?.identityGender ?? '');
    _birthDateController = TextEditingController(text: e?.identityBirthDate ?? '');
    _emailController = TextEditingController(text: e?.identityEmail ?? '');
    _phoneController = TextEditingController(text: e?.identityPhone ?? '');
    _address1Controller = TextEditingController(text: e?.identityAddress1 ?? '');
    _address2Controller = TextEditingController(text: e?.identityAddress2 ?? '');
    _cityController = TextEditingController(text: e?.identityCity ?? '');
    _stateController = TextEditingController(text: e?.identityState ?? '');
    _postalCodeController = TextEditingController(text: e?.identityPostalCode ?? '');
    _countryController = TextEditingController(text: e?.identityCountry ?? '');
    _passportController = TextEditingController(text: e?.identityPassportNumber ?? '');
    _nationalIdController = TextEditingController(text: e?.identityNationalId ?? '');
    _licenseController = TextEditingController(text: e?.identityLicenseNumber ?? '');
    _companyController = TextEditingController(text: e?.identityCompany ?? '');
    _occupationController = TextEditingController(text: e?.identityOccupation ?? '');
    _notesController = TextEditingController(text: e?.notes ?? '');
    _tagsController = TextEditingController(text: e?.tags.join(', ') ?? '');
    _isFavorite = e?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _identityTitleController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _genderController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    _passportController.dispose();
    _nationalIdController.dispose();
    _licenseController.dispose();
    _companyController.dispose();
    _occupationController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  String get _computedTitle {
    final parts = [
      _identityTitleController.text.trim(),
      _firstNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((p) => p.isNotEmpty).join(' ');

    if (parts.isNotEmpty) return parts;
    return 'Identity Profile';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              surface: const Color(0xFF1C1C1E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _addCustomDocument([CustomField? initialField, int? editIndex]) async {
    final nameController = TextEditingController(text: initialField?.name ?? '');
    final valueController = TextEditingController(text: initialField?.value ?? '');
    bool isObscured = initialField?.isObscured ?? true;
    final List<Map<String, TextEditingController>> detailControllers = (initialField?.details ?? []).map((d) {
      return {
        'label': TextEditingController(text: d.label),
        'value': TextEditingController(text: d.value),
      };
    }).toList();

    final presets = ['Aadhaar Card', 'PAN Card', 'Passport', "Driver's License", 'Voter ID', 'Tax ID / SIN', 'Health Insurance #', 'Green Card'];

    final result = await showDialog<CustomField>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(initialField == null ? 'Add Identity Document / Card' : 'Edit Document / Card'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (initialField == null) ...[
                    const Text('Quick Presets', style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presets.map((preset) {
                        final isSelected = nameController.text == preset;
                        return ActionChip(
                          label: Text(preset, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white70)),
                          backgroundColor: isSelected ? Colors.indigoAccent.withValues(alpha: 0.4) : const Color(0xFF2C2C2E),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onPressed: () {
                            setDialogState(() {
                              nameController.text = preset;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Card / Document Type *',
                      hintText: 'e.g. Aadhaar, PAN Card, Voter ID',
                      prefixIcon: Icon(Icons.badge_outlined, color: Colors.indigoAccent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Primary Card / ID Number *',
                      hintText: 'e.g. 1234 5678 9012 or ABCDE1234F',
                      prefixIcon: Icon(Icons.pin_outlined, color: Colors.indigoAccent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Conceal Card Number', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Mask value until revealed with eye icon', style: TextStyle(fontSize: 11, color: Colors.white54)),
                    value: isObscured,
                    activeColor: Colors.indigoAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => isObscured = val),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Colors.white12),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'ADDITIONAL DETAILS',
                          style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            detailControllers.add({
                              'label': TextEditingController(),
                              'value': TextEditingController(),
                            });
                          });
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Detail', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  if (detailControllers.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Tap "Add Detail" to attach extra info like Expiry Date, Issue Date, Father\'s Name, or Issuing Authority to this card.',
                        style: TextStyle(fontSize: 12, color: Colors.white38, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  ...detailControllers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final controllers = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers['label'],
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Detail Name',
                                hintText: 'e.g. Expiry',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controllers['value'],
                              decoration: const InputDecoration(
                                labelText: 'Detail Value',
                                hintText: 'e.g. 2030-05',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
                            onPressed: () {
                              setDialogState(() {
                                detailControllers.removeAt(idx);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final val = valueController.text.trim();
                if (name.isNotEmpty && val.isNotEmpty) {
                  final details = detailControllers
                      .where((c) => c['label']!.text.trim().isNotEmpty && c['value']!.text.trim().isNotEmpty)
                      .map((c) => CustomFieldDetail(label: c['label']!.text.trim(), value: c['value']!.text.trim()))
                      .toList();

                  Navigator.pop(
                    ctx,
                    CustomField(
                      name: name,
                      value: val,
                      isObscured: isObscured,
                      details: details,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigoAccent,
                foregroundColor: Colors.white,
              ),
              child: Text(initialField == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (editIndex != null) {
          _customFields[editIndex] = result;
        } else {
          _customFields.add(result);
        }
      });
    }
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

    final title = _titleController.text.trim().isNotEmpty ? _titleController.text.trim() : _computedTitle;

    final newEntry = VaultEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      type: EntryType.identity,
      title: title,
      username: _emailController.text.trim(),
      password: '',
      identityTitle: _identityTitleController.text.trim().isEmpty ? null : _identityTitleController.text.trim(),
      identityFirstName: _firstNameController.text.trim().isEmpty ? null : _firstNameController.text.trim(),
      identityMiddleName: _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
      identityLastName: _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
      identityGender: _genderController.text.trim().isEmpty ? null : _genderController.text.trim(),
      identityBirthDate: _birthDateController.text.trim().isEmpty ? null : _birthDateController.text.trim(),
      identityEmail: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      identityPhone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      identityAddress1: _address1Controller.text.trim().isEmpty ? null : _address1Controller.text.trim(),
      identityAddress2: _address2Controller.text.trim().isEmpty ? null : _address2Controller.text.trim(),
      identityCity: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      identityState: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
      identityPostalCode: _postalCodeController.text.trim().isEmpty ? null : _postalCodeController.text.trim(),
      identityCountry: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      identityPassportNumber: _passportController.text.trim().isEmpty ? null : _passportController.text.trim(),
      identityNationalId: _nationalIdController.text.trim().isEmpty ? null : _nationalIdController.text.trim(),
      identityLicenseNumber: _licenseController.text.trim().isEmpty ? null : _licenseController.text.trim(),
      identityCompany: _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      identityOccupation: _occupationController.text.trim().isEmpty ? null : _occupationController.text.trim(),
      customFields: _customFields,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      tags: tags,
      isFavorite: _isFavorite,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save identity: $e')),
        );
      }
    }
  }

  Future<void> _delete() async {
    if (widget.entry == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Identity?'),
        content: const Text('Are you sure you want to delete this identity profile?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete identity. Please try again.')),
          );
        }
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.indigoAccent),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Add Identity' : 'Edit Identity'),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : Colors.white70,
            ),
            tooltip: _isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
          if (widget.entry != null)
            _isDeleting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
              // Profile Name / Custom Title
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Profile Label (optional)',
                      prefixIcon: const Icon(Icons.badge_outlined, color: Colors.indigoAccent),
                      hintText: _computedTitle,
                    ),
                  ),
                ),
              ),

              // 1. Personal Details Section
              _buildSectionHeader('Personal Details', Icons.person_outline),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: _identityTitleController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'Title', hintText: 'Mr/Ms/Dr'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'First Name *'),
                              validator: (val) {
                                if ((val == null || val.trim().isEmpty) && _lastNameController.text.trim().isEmpty) {
                                  return 'Name required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _middleNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'Middle Name'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'Last Name *'),
                              validator: (val) {
                                if ((val == null || val.trim().isEmpty) && _firstNameController.text.trim().isEmpty) {
                                  return 'Name required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _genderController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'Gender', hintText: 'Male / Female'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _birthDateController,
                              readOnly: true,
                              onTap: _pickBirthDate,
                              decoration: const InputDecoration(
                                labelText: 'Date of Birth',
                                hintText: 'YYYY-MM-DD',
                                suffixIcon: Icon(Icons.calendar_today, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Contact Details Section
              _buildSectionHeader('Contact Information', Icons.contact_mail_outlined),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Address Details Section
              _buildSectionHeader('Address', Icons.location_on_outlined),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _address1Controller,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Address Line 1', prefixIcon: Icon(Icons.home_outlined)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _address2Controller,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Address Line 2 (Apt / Suite)', prefixIcon: Icon(Icons.apartment_outlined)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'City'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'State / Province'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _postalCodeController,
                              decoration: const InputDecoration(labelText: 'ZIP / Postal Code'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _countryController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(labelText: 'Country'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Identification Numbers Section
              _buildSectionHeader('Identification Documents', Icons.credit_card_outlined),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nationalIdController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'National ID / SSN / Aadhaar',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passportController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Passport Number',
                          prefixIcon: Icon(Icons.flight_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _licenseController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: "Driver's License Number",
                          prefixIcon: Icon(Icons.drive_eta_outlined),
                        ),
                      ),
                      if (_customFields.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: Colors.white12),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'OTHER IDENTIFICATION CARDS',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _customFields.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, color: Colors.white12),
                          itemBuilder: (context, idx) {
                            final field = _customFields[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.badge_outlined, color: Colors.indigoAccent, size: 20),
                              title: Text(field.name, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    field.isObscured ? '••••••••••••' : field.value,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                                  ),
                                  if (field.details.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: field.details.map((d) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.indigoAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${d.label}: ${d.value}',
                                          style: const TextStyle(fontSize: 10, color: Colors.indigoAccent),
                                        ),
                                      )).toList(),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white38),
                                    onPressed: () => _addCustomDocument(field, idx),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    onPressed: () => setState(() => _customFields.removeAt(idx)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _addCustomDocument(),
                        icon: const Icon(Icons.add, size: 18, color: Colors.indigoAccent),
                        label: const Text('Add Document / Card (e.g. PAN, Voter ID)', style: TextStyle(color: Colors.indigoAccent, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.indigoAccent.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Work Details Section
              _buildSectionHeader('Work & Employment', Icons.work_outline),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _companyController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Company / Employer',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _occupationController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Job Title / Occupation',
                          prefixIcon: Icon(Icons.work_history_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Tags & Notes
              _buildSectionHeader('Tags & Notes', Icons.notes_outlined),
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
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes',
                          prefixIcon: Icon(Icons.notes),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ].animate(interval: 40.ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
          ),
        ),
      ),
    );
  }
}
