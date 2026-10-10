import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_pass/features/vault/models/vault_entry.dart';
import 'package:one_pass/features/vault/models/entry_type.dart';
import 'package:one_pass/features/vault/ui/widgets/vault_category_chips.dart';
import 'package:one_pass/features/vault/ui/widgets/vault_favorites_carousel.dart';
import 'package:one_pass/features/vault/ui/widgets/add_item_sheet.dart';

void main() {
  testWidgets('VaultCategoryChips displays categories and responds to selection', (tester) async {
    String selected = 'all';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => VaultCategoryChips(
              selectedCategory: selected,
              onCategorySelected: (cat) => setState(() => selected = cat),
              counts: const {'all': 10, 'login': 5, 'note': 2, 'card': 3},
            ),
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Logins'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    // Verify 0-count categories are hidden
    expect(find.text('Wi-Fi'), findsNothing);
    expect(find.text('Identities'), findsNothing);
    expect(find.text('2FA'), findsNothing);
    expect(find.text('Passkeys'), findsNothing);

    // Tap Logins
    await tester.tap(find.text('Logins'));
    await tester.pumpAndSettle();
    expect(selected, 'login');
  });

  testWidgets('VaultFavoritesCarousel renders favorites and copy action', (tester) async {
    final entry = VaultEntry(
      id: '1',
      title: 'Google Account',
      username: 'user@google.com',
      password: 'mypassword123',
      type: EntryType.login,
      tags: const [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isFavorite: true,
    );

    String? copiedText;
    VaultEntry? tappedEntry;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultFavoritesCarousel(
            favorites: [entry],
            onItemTap: (e) => tappedEntry = e,
            onCopy: (txt, label) => copiedText = txt,
          ),
        ),
      ),
    );

    expect(find.text('FAVORITES'), findsOneWidget);
    expect(find.text('Google Account'), findsOneWidget);
    expect(find.text('user@google.com'), findsOneWidget);

    // Tap item
    await tester.tap(find.text('Google Account'));
    expect(tappedEntry?.id, '1');

    // Tap quick copy
    await tester.tap(find.byIcon(Icons.copy));
    expect(copiedText, 'mypassword123');
  });

  testWidgets('AddItemSheet renders options', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AddItemSheet(),
        ),
      ),
    );

    expect(find.text('Add to Vault'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Secure Note'), findsOneWidget);
    expect(find.text('Credit Card'), findsOneWidget);
    expect(find.text('2FA Token'), findsOneWidget);
    expect(find.text('Wi-Fi Network'), findsOneWidget);
    expect(find.text('Identity'), findsOneWidget);
  });
}
