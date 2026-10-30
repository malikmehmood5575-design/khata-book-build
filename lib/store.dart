import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// App ka saara data yahan rehta hai. shared_preferences me JSON collections
/// save hoti hain. Init LAZY hai: runApp() se pehle kuch await nahi hota,
/// data pehle frame ke baad load hota hai aur [ready] true ho jata hai.
class AppStore extends ChangeNotifier {
  static final AppStore instance = AppStore._();
  AppStore._();

  bool ready = false;
  bool _initStarted = false;

  List<Party> parties = [];
  List<LedgerEntry> ledger = [];
  List<CashEntry> cashbook = [];
  List<Expense> expenses = [];
  List<Item> items = [];
  List<Bill> bills = [];
  List<String> expenseCategories = [
    'Mazdoori',
    'Transport',
    'Khana',
    'Tool/Repair',
    'Deegar',
  ];
  String businessName = 'Khata Book';
  int billCounter = 0;

  static const _key = 'khatabook_data_v1';

  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        _loadFromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // Data corrupt ho to khali app se shuru — crash nahi karna.
    }
    ready = true;
    notifyListeners();
  }

  void _loadFromJson(Map<String, dynamic> j) {
    parties = ((j['parties'] ?? []) as List)
        .map((e) => Party.fromJson(e as Map<String, dynamic>))
        .toList();
    ledger = ((j['ledger'] ?? []) as List)
        .map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    cashbook = ((j['cashbook'] ?? []) as List)
        .map((e) => CashEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    expenses = ((j['expenses'] ?? []) as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
    items = ((j['items'] ?? []) as List)
        .map((e) => Item.fromJson(e as Map<String, dynamic>))
        .toList();
    bills = ((j['bills'] ?? []) as List)
        .map((e) => Bill.fromJson(e as Map<String, dynamic>))
        .toList();
    final cats = (j['expenseCategories'] ?? []) as List;
    if (cats.isNotEmpty) {
      expenseCategories = cats.map((e) => e.toString()).toList();
    }
    businessName = (j['businessName'] ?? 'Khata Book') as String;
    billCounter = (j['billCounter'] ?? 0) as int;
  }

  Map<String, dynamic> toJson() => {
        'parties': parties.map((e) => e.toJson()).toList(),
        'ledger': ledger.map((e) => e.toJson()).toList(),
        'cashbook': cashbook.map((e) => e.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'items': items.map((e) => e.toJson()).toList(),
        'bills': bills.map((e) => e.toJson()).toList(),
        'expenseCategories': expenseCategories,
        'businessName': businessName,
        'billCounter': billCounter,
      };

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(toJson()));
    } catch (_) {}
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Parties + Khata
  // -------------------------------------------------------------------------

  Party? partyById(String id) {
    for (final p in parties) {
      if (p.id == id) return p;
    }
    return null;
  }

  double partyBalance(String partyId) {
    double b = 0;
    for (final e in ledger) {
      if (e.partyId == partyId) b += e.signed;
    }
    return b;
  }

  List<LedgerEntry> partyEntries(String partyId) {
    final list = ledger.where((e) => e.partyId == partyId).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<void> addParty(Party p) async {
    parties.add(p);
    await save();
  }

  Future<void> updateParty(Party p) async {
    await save();
  }

  Future<void> deleteParty(String id) async {
    parties.removeWhere((p) => p.id == id);
    ledger.removeWhere((e) => e.partyId == id);
    await save();
  }

  Future<void> addLedgerEntry(LedgerEntry e, {bool alsoCash = false}) async {
    ledger.add(e);
    // CashBook se link: payment mili/di cash me bhi darj ho jati hai.
    if (alsoCash) {
      if (e.type == 'paymentMili') {
        cashbook.add(CashEntry(
          id: newId(),
          isIn: true,
          amount: e.amount,
          note: e.note.isEmpty ? 'Khata payment' : e.note,
          date: e.date,
          partyId: e.partyId,
        ));
      } else if (e.type == 'paymentDi') {
        cashbook.add(CashEntry(
          id: newId(),
          isIn: false,
          amount: e.amount,
          note: e.note.isEmpty ? 'Khata payment' : e.note,
          date: e.date,
          partyId: e.partyId,
        ));
      }
    }
    await save();
  }

  Future<void> deleteLedgerEntry(String id) async {
    ledger.removeWhere((e) => e.id == id);
    await save();
  }

  // -------------------------------------------------------------------------
  // CashBook
  // -------------------------------------------------------------------------

  double cashBalance({DateTime? upto}) {
    double b = 0;
    for (final e in cashbook) {
      if (upto != null && e.date.isAfter(upto)) continue;
      b += e.isIn ? e.amount : -e.amount;
    }
    // Kharcha bhi cash se hi jata hai — is liye cash balance se minus hoga,
    // warna Home ka "Cash" aur "Aaj Gaya (Out + Kharcha)" apas me nahi milte.
    for (final e in expenses) {
      if (upto != null && e.date.isAfter(upto)) continue;
      b -= e.amount;
    }
    return b;
  }

  Future<void> addCashEntry(CashEntry e) async {
    cashbook.add(e);
    await save();
  }

  Future<void> deleteCashEntry(String id) async {
    cashbook.removeWhere((e) => e.id == id);
    await save();
  }

  // -------------------------------------------------------------------------
  // Expenses
  // -------------------------------------------------------------------------

  Future<void> addExpense(Expense e) async {
    expenses.add(e);
    await save();
  }

  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((x) => x.id == id);
    await save();
  }

  Future<void> setCategories(List<String> cats) async {
    expenseCategories = cats;
    await save();
  }

  // -------------------------------------------------------------------------
  // Inventory
  // -------------------------------------------------------------------------

  Item? itemById(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  Item? itemByBarcode(String code) {
    for (final i in items) {
      if (i.barcode.isNotEmpty && i.barcode == code) return i;
    }
    return null;
  }

  Future<void> addItem(Item i) async {
    items.add(i);
    await save();
  }

  Future<void> updateItem(Item i) async {
    await save();
  }

  Future<void> deleteItem(String id) async {
    items.removeWhere((i) => i.id == id);
    await save();
  }

  // -------------------------------------------------------------------------
  // Bills
  // -------------------------------------------------------------------------

  /// Bill save karna: stock kam hota hai, khata me entries banti hain,
  /// advance CashBook me IN ho jata hai.
  Future<Bill> createBill({
    required Party party,
    required List<MeasureLine> measureLines,
    required List<MaterialLine> materialLines,
    required double extraCharges,
    required String extraNote,
    required double advance,
    required String note,
    required DateTime date,
  }) async {
    billCounter += 1;
    final bill = Bill(
      id: newId(),
      number: billCounter,
      partyId: party.id,
      partyName: party.name,
      measureLines: measureLines,
      materialLines: materialLines,
      extraCharges: extraCharges,
      extraNote: extraNote,
      advance: advance,
      date: date,
      note: note,
    );
    bills.add(bill);

    // Stock deduct
    for (final line in materialLines) {
      final item = itemById(line.itemId);
      if (item != null) {
        item.stockQty -= line.qty;
      }
    }

    // Khata entries: kul bill ka udhaar, phir advance as payment mili.
    if (bill.total > 0) {
      ledger.add(LedgerEntry(
        id: newId(),
        partyId: party.id,
        type: 'udhaarDiya',
        amount: bill.total,
        note: 'Bill No ${bill.number}',
        date: date,
        billId: bill.id,
      ));
    }
    if (advance > 0) {
      ledger.add(LedgerEntry(
        id: newId(),
        partyId: party.id,
        type: 'paymentMili',
        amount: advance,
        note: 'Bill No ${bill.number} — Advance',
        date: date,
        billId: bill.id,
      ));
      cashbook.add(CashEntry(
        id: newId(),
        isIn: true,
        amount: advance,
        note: 'Bill No ${bill.number} — Advance (${party.name})',
        date: date,
        partyId: party.id,
      ));
    }
    await save();
    return bill;
  }

  Future<void> deleteBill(String billId) async {
    final bill = bills.where((b) => b.id == billId).firstOrNull;
    if (bill == null) return;
    // Stock wapas
    for (final line in bill.materialLines) {
      final item = itemById(line.itemId);
      if (item != null) item.stockQty += line.qty;
    }
    bills.removeWhere((b) => b.id == billId);
    ledger.removeWhere((e) => e.billId == billId);
    await save();
  }

  // -------------------------------------------------------------------------
  // Reports helpers
  // -------------------------------------------------------------------------

  /// Range ke totals: cash in, cash out, kharcha (expenses)
  ({double cashIn, double cashOut, double kharcha}) totalsFor(
      DateTime from, DateTime to) {
    double ci = 0, co = 0, kh = 0;
    for (final e in cashbook) {
      if (!e.date.isBefore(from) && e.date.isBefore(to)) {
        if (e.isIn) {
          ci += e.amount;
        } else {
          co += e.amount;
        }
      }
    }
    for (final e in expenses) {
      if (!e.date.isBefore(from) && e.date.isBefore(to)) kh += e.amount;
    }
    return (cashIn: ci, cashOut: co, kharcha: kh);
  }

  double get totalLena {
    double t = 0;
    for (final p in parties) {
      final b = partyBalance(p.id);
      if (b > 0) t += b;
    }
    return t;
  }

  double get totalDena {
    double t = 0;
    for (final p in parties) {
      final b = partyBalance(p.id);
      if (b < 0) t += -b;
    }
    return t;
  }

  // -------------------------------------------------------------------------
  // Backup / Restore
  // -------------------------------------------------------------------------

  String exportJson() => jsonEncode(toJson());

  /// Paste ki gayi JSON se data restore. Ghalat JSON par false.
  Future<bool> importJson(String raw) async {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (!j.containsKey('parties')) return false;
      _loadFromJson(j);
      await save();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBusinessName(String name) async {
    businessName = name.trim().isEmpty ? 'Khata Book' : name.trim();
    await save();
  }
}
