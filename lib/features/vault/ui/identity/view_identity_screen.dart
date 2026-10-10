import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/vault_entry.dart';
import '../../providers/vault_provider.dart';
import '../../../../core/utils/clipboard_util.dart';
import 'add_edit_identity_screen.dart';

class ViewIdentityScreen extends ConsumerStatefulWidget {
  final VaultEntry entry;

  const ViewIdentityScreen({super.key, required this.entry});

  @override
  ConsumerState<ViewIdentityScreen> createState() => _ViewIdentityScreenState();
}

class _ViewIdentityScreenState extends ConsumerState<ViewIdentityScreen> {
  bool _obscureNationalId = true;
  bool _obscurePassport = true;
  bool _obscureLicense = true;
  final Set<int> _revealedCustomFields = {};

  void _copyToClipboard(String text, String label) {
    ClipboardUtil.copyTemporary(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  String _formatFullName(VaultEntry e) {
    final parts = [
      e.identityTitle,
      e.identityFirstName,
      e.identityMiddleName,
      e.identityLastName,
    ].where((p) => p != null && p.trim().isNotEmpty).map((p) => p!.trim()).toList();

    if (parts.isNotEmpty) return parts.join(' ');
    return e.title;
  }

  String _formatFullAddress(VaultEntry e) {
    final lines = <String>[];
    if (e.identityAddress1 != null && e.identityAddress1!.isNotEmpty) lines.add(e.identityAddress1!);
    if (e.identityAddress2 != null && e.identityAddress2!.isNotEmpty) lines.add(e.identityAddress2!);
    
    final cityStateZip = [
      e.identityCity,
      e.identityState,
      e.identityPostalCode,
    ].where((p) => p != null && p.isNotEmpty).join(', ');
    if (cityStateZip.isNotEmpty) lines.add(cityStateZip);

    if (e.identityCountry != null && e.identityCountry!.isNotEmpty) lines.add(e.identityCountry!);

    return lines.join('\n');
  }

  Widget _buildFieldTile({
    required IconData icon,
    required String label,
    required String? value,
    bool isObscured = false,
    bool canObscure = false,
    VoidCallback? onToggleObscure,
  }) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.indigoAccent, size: 22),
          title: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          subtitle: Text(
            isObscured ? '••••••••••••' : value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: isObscured ? 2 : 0,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canObscure && onToggleObscure != null)
                IconButton(
                  icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
                  onPressed: onToggleObscure,
                ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white38, size: 20),
                tooltip: 'Copy $label',
                onPressed: () => _copyToClipboard(value, label),
              ),
            ],
          ),
        ),
        const Divider(height: 1, indent: 56, color: Colors.white12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncEntries = ref.watch(vaultProvider);
    final currentEntry = asyncEntries.value?.cast<VaultEntry?>().firstWhere(
      (e) => e?.id == widget.entry.id,
      orElse: () => null,
    ) ?? widget.entry;

    final fullName = _formatFullName(currentEntry);
    final fullAddress = _formatFullAddress(currentEntry);

    final hasContactInfo = (currentEntry.identityEmail != null && currentEntry.identityEmail!.isNotEmpty) ||
        (currentEntry.identityPhone != null && currentEntry.identityPhone!.isNotEmpty);

    final hasAddress = fullAddress.isNotEmpty;

    final hasIds = (currentEntry.identityNationalId != null && currentEntry.identityNationalId!.isNotEmpty) ||
        (currentEntry.identityPassportNumber != null && currentEntry.identityPassportNumber!.isNotEmpty) ||
        (currentEntry.identityLicenseNumber != null && currentEntry.identityLicenseNumber!.isNotEmpty) ||
        currentEntry.customFields.isNotEmpty;

    final hasWork = (currentEntry.identityCompany != null && currentEntry.identityCompany!.isNotEmpty) ||
        (currentEntry.identityOccupation != null && currentEntry.identityOccupation!.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Profile'),
        actions: [
          IconButton(
            icon: Icon(
              currentEntry.isFavorite ? Icons.star : Icons.star_border,
              color: currentEntry.isFavorite ? Colors.amber : Colors.white70,
            ),
            tooltip: currentEntry.isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () {
              ref.read(vaultProvider.notifier).toggleFavorite(currentEntry);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Identity',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditIdentityScreen(entry: currentEntry),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Profile Card
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.person, color: Colors.indigoAccent, size: 32),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if (currentEntry.identityOccupation != null && currentEntry.identityOccupation!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              currentEntry.identityCompany != null && currentEntry.identityCompany!.isNotEmpty
                                  ? '${currentEntry.identityOccupation} at ${currentEntry.identityCompany}'
                                  : currentEntry.identityOccupation!,
                              style: const TextStyle(fontSize: 14, color: Colors.white54),
                            ),
                          ],
                          if (currentEntry.identityBirthDate != null && currentEntry.identityBirthDate!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'DOB: ${currentEntry.identityBirthDate}${currentEntry.identityGender != null ? ' (${currentEntry.identityGender})' : ''}',
                              style: const TextStyle(fontSize: 12, color: Colors.white38),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Contact Info
            if (hasContactInfo) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildFieldTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: currentEntry.identityEmail,
                    ),
                    _buildFieldTile(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: currentEntry.identityPhone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Address Details
            if (hasAddress) ...[
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: Colors.indigoAccent, size: 22),
                  title: const Text('Address', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      fullAddress,
                      style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white38, size: 20),
                    tooltip: 'Copy Address',
                    onPressed: () => _copyToClipboard(fullAddress, 'Address'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Identification Documents
            if (hasIds) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildFieldTile(
                      icon: Icons.pin_outlined,
                      label: 'National ID / SSN / Aadhaar',
                      value: currentEntry.identityNationalId,
                      canObscure: true,
                      isObscured: _obscureNationalId,
                      onToggleObscure: () => setState(() => _obscureNationalId = !_obscureNationalId),
                    ),
                    _buildFieldTile(
                      icon: Icons.flight_outlined,
                      label: 'Passport Number',
                      value: currentEntry.identityPassportNumber,
                      canObscure: true,
                      isObscured: _obscurePassport,
                      onToggleObscure: () => setState(() => _obscurePassport = !_obscurePassport),
                    ),
                    _buildFieldTile(
                      icon: Icons.drive_eta_outlined,
                      label: "Driver's License",
                      value: currentEntry.identityLicenseNumber,
                      canObscure: true,
                      isObscured: _obscureLicense,
                      onToggleObscure: () => setState(() => _obscureLicense = !_obscureLicense),
                    ),
                    ...currentEntry.customFields.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final field = entry.value;
                      final isRevealed = _revealedCustomFields.contains(idx);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldTile(
                            icon: Icons.badge_outlined,
                            label: field.name,
                            value: field.value,
                            canObscure: field.isObscured,
                            isObscured: field.isObscured && !isRevealed,
                            onToggleObscure: () {
                              setState(() {
                                if (isRevealed) {
                                  _revealedCustomFields.remove(idx);
                                } else {
                                  _revealedCustomFields.add(idx);
                                }
                              });
                            },
                          ),
                          if (field.details.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 48.0, right: 16.0, bottom: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  children: field.details.map((d) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            d.label,
                                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                d.value,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                              ),
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _copyToClipboard(d.value, d.label),
                                                child: const Icon(Icons.copy, size: 14, color: Colors.white38),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Work Info
            if (hasWork) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildFieldTile(
                      icon: Icons.business_outlined,
                      label: 'Company',
                      value: currentEntry.identityCompany,
                    ),
                    _buildFieldTile(
                      icon: Icons.work_outline,
                      label: 'Occupation / Job Title',
                      value: currentEntry.identityOccupation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Notes
            if (currentEntry.notes != null && currentEntry.notes!.trim().isNotEmpty) ...[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NOTES',
                        style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        currentEntry.notes!,
                        style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tags
            if (currentEntry.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: currentEntry.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '#$tag',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Created: ${DateFormat.yMMMd().format(currentEntry.createdAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  Text(
                    'Updated: ${DateFormat.yMMMd().format(currentEntry.updatedAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ].animate(interval: 40.ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
        ),
      ),
    );
  }
}
