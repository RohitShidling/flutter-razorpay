import 'package:flutter_test/flutter_test.dart';
import 'package:meal_app/core/network/payment_repository.dart';

void main() {
  test('normalizeWalletTransactionList returns the direct list payload', () {
    final input = [
      {'id': 1},
      {'id': 2},
    ];

    expect(normalizeWalletTransactionList(input), input);
  });

  test('normalizeWalletTransactionList unwraps nested transactions payloads', () {
    final input = {
      'transactions': [
        {'id': 11, 'direction': 'credit'},
      ],
    };

    expect(normalizeWalletTransactionList(input), hasLength(1));
    expect(normalizeWalletTransactionList(input).first, {'id': 11, 'direction': 'credit'});
  });

  test('normalizeWalletTransactionList falls back to an empty list for unsupported payloads', () {
    expect(normalizeWalletTransactionList({'status': 'ok'}), isEmpty);
  });
}
