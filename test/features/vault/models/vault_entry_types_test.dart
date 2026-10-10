import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_pass/core/crypto/crypto_service.dart';
import 'package:one_pass/core/crypto/crypto_models.dart';
import 'package:one_pass/features/vault/models/entry_type.dart';
import 'package:one_pass/features/vault/models/vault_entry.dart';

void main() {
  group('VaultEntry Specialized Types Tests', () {
    final now = DateTime.now().toUtc();

    test('EntryType enum properties', () {
      expect(EntryType.secureNote.displayName, 'Secure Note');
      expect(EntryType.wifi.displayName, 'Wi-Fi Password');
      expect(EntryType.identity.displayName, 'Identity');

      expect(EntryType.secureNote.icon, isNotNull);
      expect(EntryType.wifi.icon, isNotNull);
      expect(EntryType.identity.icon, isNotNull);
    });

    test('Secure Note serialization & deserialization', () {
      final note = VaultEntry(
        id: 'note-1',
        type: EntryType.secureNote,
        title: 'Confidential Memo',
        username: '',
        password: '',
        notes: '# Secret Notes\n- Point 1\n- Point 2',
        tags: const ['work', 'private'],
        isFavorite: true,
        customFields: const [
          CustomField(name: 'Recovery Pin', value: '9988', isObscured: true),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final payloadStr = note.sensitivePayload;
      final payloadJson = jsonDecode(payloadStr) as Map<String, dynamic>;

      expect(payloadJson['type'], 'secureNote');
      expect(payloadJson['title'], 'Confidential Memo');
      expect(payloadJson['notes'], '# Secret Notes\n- Point 1\n- Point 2');
      expect(payloadJson['isFavorite'], true);
      expect(payloadJson['tags'], ['work', 'private']);
      expect(payloadJson['customFields'].length, 1);
      expect(payloadJson['customFields'][0]['name'], 'Recovery Pin');
    });

    test('Wi-Fi Network serialization & deserialization', () {
      final wifi = VaultEntry(
        id: 'wifi-1',
        type: EntryType.wifi,
        title: 'Office 5G',
        username: '',
        password: 'SuperSecretWifiPassword',
        wifiSsid: 'Office_Guest_5G',
        wifiPassword: 'SuperSecretWifiPassword',
        wifiSecurityType: 'WPA3',
        wifiIsHidden: true,
        notes: 'Router: 192.168.1.1',
        tags: const ['office'],
        isFavorite: false,
        createdAt: now,
        updatedAt: now,
      );

      final payloadStr = wifi.sensitivePayload;
      final payloadJson = jsonDecode(payloadStr) as Map<String, dynamic>;

      expect(payloadJson['type'], 'wifi');
      expect(payloadJson['wifiSsid'], 'Office_Guest_5G');
      expect(payloadJson['wifiPassword'], 'SuperSecretWifiPassword');
      expect(payloadJson['wifiSecurityType'], 'WPA3');
      expect(payloadJson['wifiIsHidden'], true);
      expect(payloadJson['notes'], 'Router: 192.168.1.1');
    });

    test('Identity Profile serialization & deserialization', () {
      final identity = VaultEntry(
        id: 'id-1',
        type: EntryType.identity,
        title: 'John Doe Profile',
        username: 'john.doe@example.com',
        password: '',
        identityTitle: 'Dr.',
        identityFirstName: 'John',
        identityMiddleName: 'Robert',
        identityLastName: 'Doe',
        identityGender: 'Male',
        identityBirthDate: '1988-05-15',
        identityEmail: 'john.doe@example.com',
        identityPhone: '+1-555-0199',
        identityAddress1: '123 Tech Blvd',
        identityAddress2: 'Suite 400',
        identityCity: 'San Francisco',
        identityState: 'CA',
        identityPostalCode: '94105',
        identityCountry: 'United States',
        identityPassportNumber: 'A12345678',
        identityNationalId: '987-65-4321',
        identityLicenseNumber: 'D9876543',
        identityCompany: 'Acme Corp',
        identityOccupation: 'Lead Architect',
        customFields: const [
          CustomField(
            name: 'PAN Card',
            value: 'ABCDE1234F',
            isObscured: true,
            details: [
              CustomFieldDetail(label: "Father's Name", value: 'Robert Doe'),
              CustomFieldDetail(label: 'Date of Issue', value: '2020-01-15'),
            ],
          ),
        ],
        tags: const ['personal'],
        createdAt: now,
        updatedAt: now,
      );

      final payloadStr = identity.sensitivePayload;
      final payloadJson = jsonDecode(payloadStr) as Map<String, dynamic>;

      expect(payloadJson['type'], 'identity');
      expect(payloadJson['identityTitle'], 'Dr.');
      expect(payloadJson['identityFirstName'], 'John');
      expect(payloadJson['identityLastName'], 'Doe');
      expect(payloadJson['identityEmail'], 'john.doe@example.com');
      expect(payloadJson['identityAddress1'], '123 Tech Blvd');
      expect(payloadJson['identityCity'], 'San Francisco');
      expect(payloadJson['identityPassportNumber'], 'A12345678');
      expect(payloadJson['identityNationalId'], '987-65-4321');
      expect(payloadJson['identityCompany'], 'Acme Corp');
      expect(payloadJson['customFields'].length, 1);
      expect(payloadJson['customFields'][0]['name'], 'PAN Card');
      expect(payloadJson['customFields'][0]['value'], 'ABCDE1234F');
      expect(payloadJson['customFields'][0]['details'].length, 2);
      expect(payloadJson['customFields'][0]['details'][0]['label'], "Father's Name");
      expect(payloadJson['customFields'][0]['details'][0]['value'], "Robert Doe");
      expect(payloadJson['customFields'][0]['details'][1]['label'], "Date of Issue");
    });

    test('Round-trip AES-256-GCM encryption & decryption for new item types', () async {
      final cryptoService = CryptoService();
      final salt = await cryptoService.generateSalt();
      final key = await cryptoService.deriveKey(password: 'MyMasterPassword123!', salt: salt);

      final identity = VaultEntry(
        id: 'test-crypto-id',
        type: EntryType.identity,
        title: 'Jane Smith',
        username: 'jane@example.com',
        password: '',
        identityFirstName: 'Jane',
        identityLastName: 'Smith',
        identityPassportNumber: 'P987654321',
        tags: const ['passport'],
        createdAt: now,
        updatedAt: now,
      );

      final payloadBytes = Uint8List.fromList(utf8.encode(identity.sensitivePayload));
      final encryptedBlob = await cryptoService.encrypt(payloadBytes, key);

      // Decrypt with correct key
      final decryptedBytes = await cryptoService.decrypt(encryptedBlob, key);
      final decryptedJson = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;

      expect(decryptedJson['identityFirstName'], 'Jane');
      expect(decryptedJson['identityLastName'], 'Smith');
      expect(decryptedJson['identityPassportNumber'], 'P987654321');
      expect(decryptedJson['type'], 'identity');

      key.clear();
    });

    test('Remote sync push and pull round-trip simulation for Wi-Fi, Note, and Identity', () async {
      final cryptoService = CryptoService();
      final salt = await cryptoService.generateSalt();
      final key = await cryptoService.deriveKey(password: 'TestSyncPassword123!', salt: salt);

      // Create entries of each new type
      final originalWifi = VaultEntry(
        id: 'sync-wifi-1',
        type: EntryType.wifi,
        title: 'Starbucks WiFi',
        username: '',
        password: 'CoffeePassword2026',
        wifiSsid: 'Starbucks_Guest',
        wifiPassword: 'CoffeePassword2026',
        wifiSecurityType: 'WPA3',
        wifiIsHidden: true,
        notes: 'Speed: 100Mbps',
        tags: const ['cafe'],
        isFavorite: true,
        createdAt: now,
        updatedAt: now,
      );

      final originalNote = VaultEntry(
        id: 'sync-note-1',
        type: EntryType.secureNote,
        title: 'Master Recovery Seeds',
        username: '',
        password: '',
        notes: 'seed1 seed2 seed3 seed4',
        customFields: const [
          CustomField(name: 'Seed Type', value: 'BIP-39', isObscured: false),
        ],
        tags: const ['crypto', 'backup'],
        createdAt: now,
        updatedAt: now,
      );

      final originalIdentity = VaultEntry(
        id: 'sync-id-1',
        type: EntryType.identity,
        title: 'Alice Wonder',
        username: 'alice@wonderland.com',
        password: '',
        identityTitle: 'Ms.',
        identityFirstName: 'Alice',
        identityLastName: 'Wonder',
        identityEmail: 'alice@wonderland.com',
        identityPhone: '+1-234-567-8900',
        identityAddress1: '42 Rabbit Hole Way',
        identityCity: 'Oxford',
        identityPassportNumber: 'UK1234567',
        identityCompany: 'Looking Glass Inc',
        identityOccupation: 'Explorer',
        tags: const ['identity'],
        createdAt: now,
        updatedAt: now,
      );

      for (final entry in [originalWifi, originalNote, originalIdentity]) {
        // 1. Client creates EncryptedBlob
        final payloadBytes = Uint8List.fromList(utf8.encode(entry.sensitivePayload));
        final blob = await cryptoService.encrypt(payloadBytes, key);
        final storageStr = blob.toStorageString();

        // 2. Simulated remote DB sync push payload
        final dbRow = {
          'id': entry.id,
          'encrypted_data': storageStr,
          'nonce': blob.nonce.toBase64(),
          'created_at': entry.createdAt.toIso8601String(),
          'updated_at': entry.updatedAt.toIso8601String(),
          'is_deleted': false,
        };

        // 3. Client pulls dbRow from remote backend and decrypts
        final pulledBlob = EncryptedBlob.fromStorageString(dbRow['encrypted_data'] as String);
        final decryptedBytes = await cryptoService.decrypt(pulledBlob, key);
        final decryptedJson = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;

        // Verify all fields are intact
        expect(decryptedJson['type'], entry.type.name);
        expect(decryptedJson['title'], entry.title);
        expect(decryptedJson['notes'], entry.notes);

        if (entry.type == EntryType.wifi) {
          expect(decryptedJson['wifiSsid'], 'Starbucks_Guest');
          expect(decryptedJson['wifiPassword'], 'CoffeePassword2026');
          expect(decryptedJson['wifiSecurityType'], 'WPA3');
          expect(decryptedJson['wifiIsHidden'], true);
        } else if (entry.type == EntryType.secureNote) {
          expect(decryptedJson['customFields'].length, 1);
          expect(decryptedJson['customFields'][0]['name'], 'Seed Type');
          expect(decryptedJson['customFields'][0]['value'], 'BIP-39');
        } else if (entry.type == EntryType.identity) {
          expect(decryptedJson['identityFirstName'], 'Alice');
          expect(decryptedJson['identityLastName'], 'Wonder');
          expect(decryptedJson['identityEmail'], 'alice@wonderland.com');
          expect(decryptedJson['identityPhone'], '+1-234-567-8900');
          expect(decryptedJson['identityAddress1'], '42 Rabbit Hole Way');
          expect(decryptedJson['identityCity'], 'Oxford');
          expect(decryptedJson['identityPassportNumber'], 'UK1234567');
          expect(decryptedJson['identityCompany'], 'Looking Glass Inc');
          expect(decryptedJson['identityOccupation'], 'Explorer');
        }
      }

      key.clear();
    });
  });
}
