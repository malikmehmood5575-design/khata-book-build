// v1.8 Apna Kharcha — partyId NULL wali kharcha entries ke test:
// kisi customer ke baqi par asar nahi, category totals alag, cash link
// null party par bhi pehchana jata hai.
import 'package:flutter_test/flutter_test.dart';

import 'package:khatabook/models.dart';
import 'package:khatabook/store.dart';

LedgerEntry entry({
  required String id,
  String? partyId,
  required String type,
  required double amount,
  String? karigarId,
  String? kharchaLabel,
  DateTime? date,
}) {
  return LedgerEntry(
    id: id,
    partyId: partyId,
    type: type,
    amount: amount,
    note: '',
    date: date ?? DateTime(2026, 11, 7),
    karigarId: karigarId,
    kharchaLabel: kharchaLabel,
  );
}

void main() {
  final store = AppStore.instance;
  final ali = Party(id: 'p1', name: 'Ali');

  setUp(() {
    store.parties = [ali];
    store.ledger = [
      entry(id: 'a1', partyId: 'p1', type: 'advance', amount: 50000),
      entry(
        id: 'k1',
        partyId: 'p1',
        type: 'kharcha',
        amount: 12000,
        kharchaLabel: 'Material',
      ),
      // Apna kharcha — koi customer nahi.
      entry(id: 'g1', type: 'kharcha', amount: 3000, kharchaLabel: 'Petrol'),
      entry(id: 'g2', type: 'kharcha', amount: 2000, kharchaLabel: 'Material'),
      entry(id: 'g3', type: 'kharcha', amount: 5000, karigarId: 'kar1'),
    ];
    store.cashbook = [];
    store.expenses = [];
  });

  test('Apna kharcha customer ke baqi ko nahi badalta', () {
    // 50,000 advance - 12,000 customer kharcha = 38,000 — apna kharcha
    // (3,000 + 2,000 + 5,000) is mein shamil NAHI.
    expect(store.partyBaqi('p1'), 38000);
    expect(store.totalBaqi, 38000);
    expect(store.partyKharchaTotal('p1'), 12000);
  });

  test('Kul kharcha me apna kharcha bhi shamil hai', () {
    expect(store.generalKharchaTotal, 10000);
    expect(store.totalKharcha, 22000);
  });

  test('Category ke hisaab se kul', () {
    final byCat = store.generalKharchaByCategory();
    expect(byCat['Petrol'], 3000);
    expect(byCat['Material'], 2000);
    expect(byCat['Karigar'], 5000);
  });

  test('Apna kharcha JSON roundtrip — partyId null rehta hai', () {
    final e = entry(id: 'g9', type: 'kharcha', amount: 700, kharchaLabel: 'Chai');
    final back = LedgerEntry.fromJson(e.toJson());
    expect(back.partyId, isNull);
    expect(back.amount, 700);
    expect(back.kharchaLabel, 'Chai');
  });

  test('Cash link null party par bhi pehchana jata hai', () {
    final e = entry(id: 'g1', type: 'kharcha', amount: 3000, kharchaLabel: 'Petrol');
    store.cashbook = [
      CashEntry(
        id: 'c1',
        isIn: false,
        amount: 3000,
        note: 'Kharcha',
        date: DateTime(2026, 11, 7),
        partyId: null,
      ),
    ];
    expect(store.hasLinkedCashEntry(e), isTrue);
  });

  test('Total remaining — kul advance minus kul kharcha (v1.8.1)', () {
    // Home hero ki bari rakam: 50,000 advance - 22,000 kul kharcha
    // (12,000 customer + 10,000 apna) = 28,000. Ye totalBaqi (38,000)
    // se mukhtalif hai — remaining me apna kharcha bhi kat ta hai.
    expect(store.totalAdvance, 50000);
    expect(store.totalRemaining, 28000);
  });
}
