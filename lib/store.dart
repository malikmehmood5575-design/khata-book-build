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
  List<Karigar> karigars = [];
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
    // Purane data/backups me karigars nahi hain — absent ho to khali list.
    karigars = ((j['karigars'] ?? []) as List)
        .map((e) => Karigar.fromJson(e as Map<String, dynamic>))
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
        'karigars': karigars.map((e) => e.toJson()).toList(),
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

  /// id null ho (apna kharcha ki entry) to hamesha null — lookup safe hai.
  Party? partyById(String? id) {
    if (id == null) return null;
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

  // -------------------------------------------------------------------------
  // v1.4 Advance model — Baqi Paisa (advance - kharcha)
  // -------------------------------------------------------------------------

  /// Customer ka kitna paisa abhi hamaray paas baqi hai.
  double partyBaqi(String partyId) {
    double b = 0;
    for (final e in ledger) {
      if (e.partyId == partyId) b += e.baqiEffect;
    }
    return b;
  }

  /// Customer se kul kitna advance liya (legacy paymentMili bhi shamil,
  /// kyun ke purane model me wahi advance ka kaam karti thi).
  double partyAdvanceTotal(String partyId) {
    double t = 0;
    for (final e in ledger) {
      if (e.partyId != partyId) continue;
      if (e.type == 'advance' || e.type == 'paymentMili') t += e.amount;
    }
    return t;
  }

  /// Customer ke paisay mein se kul kitna kharcha hua.
  double partyKharchaTotal(String partyId) {
    double t = 0;
    for (final e in ledger) {
      if (e.partyId == partyId && e.type == 'kharcha') t += e.amount;
    }
    return t;
  }

  double get totalBaqi {
    double t = 0;
    for (final p in parties) {
      t += partyBaqi(p.id);
    }
    return t;
  }

  double get totalAdvance {
    double t = 0;
    for (final p in parties) {
      t += partyAdvanceTotal(p.id);
    }
    return t;
  }

  /// Kul kharcha — customer-wise kharcha AUR apna (general) kharcha dono.
  double get totalKharcha {
    double t = 0;
    for (final e in ledger) {
      if (e.type == 'kharcha') t += e.amount;
    }
    return t;
  }

  // -------------------------------------------------------------------------
  // v1.8 Apna Kharcha — partyId NULL wali kharcha entries (Home wale
  // "Kharcha Karo" se banti hain; kisi customer ke baqi par asar nahi,
  // sirf category ke hisaab se darj + galle se minus).
  // -------------------------------------------------------------------------

  /// Sirf apna (general) kharcha ka kul.
  double get generalKharchaTotal {
    double t = 0;
    for (final e in ledger) {
      if (e.type == 'kharcha' && e.partyId == null) t += e.amount;
    }
    return t;
  }

  /// Apna kharcha ki saari entries, nayi pehle.
  List<LedgerEntry> get generalKharchaEntries {
    final list = ledger
        .where((e) => e.type == 'kharcha' && e.partyId == null)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Apna kharcha category ke hisaab se: 'Material', 'Karigar', ya Custom
  /// ka apna likha naam (masalan 'Petrol') — har category ka kul.
  Map<String, double> generalKharchaByCategory() {
    final map = <String, double>{};
    for (final e in ledger) {
      if (e.type != 'kharcha' || e.partyId != null) continue;
      final cat = e.karigarId != null
          ? 'Karigar'
          : (e.kharchaLabel != null && e.kharchaLabel!.isNotEmpty
                ? e.kharchaLabel!
                : 'Kharcha');
      map[cat] = (map[cat] ?? 0) + e.amount;
    }
    return map;
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

  /// Ledger entry ki type CashBook me kis simt jati hai:
  /// true = IN (paisa aaya), false = OUT (paisa gaya), null = cash posting
  /// hoti hi nahi (udhaar wali legacy types).
  bool? _cashDirection(String type) {
    switch (type) {
      case 'paymentMili':
      case 'advance':
        return true;
      case 'paymentDi':
      case 'kharcha':
        return false;
      default:
        return null;
    }
  }

  /// CashBook entry ka note — posting aur delete-cascade dono yahi istemal
  /// karte hain taake hamesha ek jaisi pehchaan bane.
  String _cashNoteFor(LedgerEntry e) {
    if (e.note.isNotEmpty) return e.note;
    switch (e.type) {
      case 'advance':
        return 'Advance';
      case 'kharcha':
        return 'Kharcha';
      default:
        return 'Khata payment';
    }
  }

  Future<void> addLedgerEntry(LedgerEntry e, {bool alsoCash = false}) async {
    ledger.add(e);
    // CashBook se link: paisa aane wali entries (paymentMili + advance)
    // cash me IN, paisa jane wali (paymentDi + kharcha) cash me OUT darj
    // ho jati hain — jab cash toggle ON ho.
    // NOTE: v1.2 me kharcha ko CashBook se bahar rakha gaya tha; v1.4 me
    // client ke advance model ki wazahat ke baad wo rule KHATAM hai —
    // kharcha bhi galle se hi kata jata hai (toggle ON ho to).
    if (alsoCash) _postCashEntry(e);
    await save();
  }

  /// Ledger entry se linked CashBook entry ki pehchaan — partyId + date +
  /// raqam + simt + note. Posting, delete-cascade aur edit teeno yahi
  /// istemal karte hain.
  int _linkedCashIndex(LedgerEntry e) {
    final dir = _cashDirection(e.type);
    if (dir == null) return -1;
    final note = _cashNoteFor(e);
    return cashbook.indexWhere((c) =>
        c.partyId == e.partyId &&
        c.isIn == dir &&
        c.amount == e.amount &&
        c.date == e.date &&
        c.note == note);
  }

  /// Is entry ki cash posting CashBook me mojood hai ya nahi (edit form
  /// ka cash toggle isi hisaab se shuru hota hai).
  bool hasLinkedCashEntry(LedgerEntry e) => _linkedCashIndex(e) >= 0;

  bool _removeLinkedCashEntry(LedgerEntry e) {
    final idx = _linkedCashIndex(e);
    if (idx < 0) return false;
    cashbook.removeAt(idx);
    return true;
  }

  void _postCashEntry(LedgerEntry e) {
    final dir = _cashDirection(e.type);
    if (dir == null) return;
    cashbook.add(CashEntry(
      id: newId(),
      isIn: dir,
      amount: e.amount,
      note: _cashNoteFor(e),
      date: e.date,
      partyId: e.partyId,
    ));
  }

  Future<void> deleteLedgerEntry(String id) async {
    final e = ledger.where((x) => x.id == id).firstOrNull;
    if (e != null) {
      // Linked CashBook entry bhi sath delete ho — jo entry add par cash
      // me darj hui thi.
      _removeLinkedCashEntry(e);
    }
    ledger.removeWhere((x) => x.id == id);
    await save();
  }

  /// Entry edit karna (v1.5): purani entry (usi id par) [updated] se badal
  /// jati hai. Cash ka hisaab bhi durust rehta hai — pehle purani linked
  /// cash entry hat ti hai, phir [postCash] ON ho to nayi entry ki cash
  /// posting dobara ho jati hai. Baqi/cash totals getters se khud recalc
  /// ho jate hain.
  Future<void> updateLedgerEntry(LedgerEntry updated,
      {required bool postCash}) async {
    final idx = ledger.indexWhere((x) => x.id == updated.id);
    if (idx < 0) return;
    _removeLinkedCashEntry(ledger[idx]);
    ledger[idx] = updated;
    if (postCash) _postCashEntry(updated);
    await save();
  }

  // -------------------------------------------------------------------------
  // Karigar — workers jin ko customer ke advance mein se payment jati hai
  // -------------------------------------------------------------------------

  Karigar? karigarById(String id) {
    for (final k in karigars) {
      if (k.id == id) return k;
    }
    return null;
  }

  Future<void> addKarigar(Karigar k) async {
    karigars.add(k);
    await save();
  }

  Future<void> updateKarigar(Karigar k) async {
    await save();
  }

  /// Karigar delete honay par us ki purani kharcha entries nahi mitti —
  /// un par karigarId laga rehta hai (detail lookup missing karigar ko
  /// bardasht karta hai aur sirf 'Karigar' label dikhata hai).
  Future<void> deleteKarigar(String id) async {
    karigars.removeWhere((k) => k.id == id);
    await save();
  }

  /// Is karigar ko ab tak kul kitna paisa diya gaya.
  double karigarTotalPaid(String karigarId) {
    double t = 0;
    for (final e in ledger) {
      if (e.type == 'kharcha' && e.karigarId == karigarId) t += e.amount;
    }
    return t;
  }

  /// Karigar ki saari payments (kharcha entries), nayi pehle.
  List<LedgerEntry> entriesForKarigar(String karigarId) {
    final list = ledger
        .where((e) => e.type == 'kharcha' && e.karigarId == karigarId)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
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
    required List<AmountLine> amountLines,
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
      amountLines: amountLines,
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
