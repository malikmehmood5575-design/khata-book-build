import 'dart:math';

String newId() {
  final r = Random();
  return '${DateTime.now().microsecondsSinceEpoch}-${r.nextInt(999999)}';
}

// ---------------------------------------------------------------------------
// Party (customer / supplier) + us ka khata ledger
// ---------------------------------------------------------------------------

/// Khata entry ki type:
/// advance     = customer se advance paisa liya (v1.4 ka asal model — paisa
///               hamaray paas, customer ka baqi barhta hai)
/// kharcha     = customer ke advance mein se kharcha hua (baqi kam hota hai);
///               karigar ko di gayi payment bhi kharcha hi hai (karigarId set)
/// udhaarDiya  = customer ko udhaar diya (purana model — sirf legacy data)
/// udhaarLiya  = supplier se udhaar liya (legacy)
/// paymentMili = customer se payment mili (legacy — baqi par advance jaisa asar)
/// paymentDi   = supplier ko payment di (legacy)
class LedgerEntry {
  final String id;
  final String partyId;
  final String type; // advance | kharcha | udhaarDiya | udhaarLiya | paymentMili | paymentDi
  final double amount;
  final String note;
  final DateTime date;
  final String? billId;

  /// Sirf kharcha entries par: kis karigar ko payment gayi (agar gayi ho).
  final String? karigarId;

  /// Sirf kharcha entries par: kharcha ki qisam ('Material', 'Doosra',
  /// ya doosra ka apna likha naam, masalan 'Khana'). Karigar wale kharche
  /// par null rehta hai.
  final String? kharchaLabel;

  LedgerEntry({
    required this.id,
    required this.partyId,
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
    this.billId,
    this.karigarId,
    this.kharchaLabel,
  });

  /// Balance par asar: + lena hai, - dena hai
  double get signed {
    switch (type) {
      case 'udhaarDiya':
        return amount;
      case 'udhaarLiya':
        return -amount;
      case 'paymentMili':
        return -amount;
      case 'paymentDi':
        return amount;
      case 'kharcha':
        return -amount;
      default:
        return 0;
    }
  }

  /// v1.4 advance model par asar: + matlab customer ka paisa hamaray paas
  /// barha (Baqi Paisa), - matlab us paisay mein se kharcha ho gaya.
  /// Legacy types ka mapping sirf is liye hai ke purana test data bhi
  /// sane tareeqay se render ho.
  double get baqiEffect {
    switch (type) {
      case 'advance':
        return amount;
      case 'kharcha':
        return -amount;
      case 'paymentMili':
        return amount;
      case 'paymentDi':
        return -amount;
      case 'udhaarDiya':
        return -amount;
      case 'udhaarLiya':
        return amount;
      default:
        return 0;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'advance':
        return 'Advance';
      case 'udhaarDiya':
        return 'Udhaar Diya';
      case 'udhaarLiya':
        return 'Udhaar Liya';
      case 'paymentMili':
        return 'Payment Mili';
      case 'paymentDi':
        return 'Payment Di';
      case 'kharcha':
        return 'Kharcha';
      default:
        return type;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'partyId': partyId,
        'type': type,
        'amount': amount,
        'note': note,
        'date': date.toIso8601String(),
        'billId': billId,
        'karigarId': karigarId,
        'kharchaLabel': kharchaLabel,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: j['id'] as String,
        partyId: j['partyId'] as String,
        type: j['type'] as String,
        amount: (j['amount'] as num).toDouble(),
        note: (j['note'] ?? '') as String,
        date: DateTime.parse(j['date'] as String),
        billId: j['billId'] as String?,
        // Purane data me ye fields nahi hain — absent ho to null.
        karigarId: j['karigarId'] as String?,
        kharchaLabel: j['kharchaLabel'] as String?,
      );
}

class Party {
  final String id;
  String name;
  String phone;
  String siteName;
  bool isSupplier;

  Party({
    required this.id,
    required this.name,
    this.phone = '',
    this.siteName = '',
    this.isSupplier = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'siteName': siteName,
        'isSupplier': isSupplier,
      };

  factory Party.fromJson(Map<String, dynamic> j) => Party(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        siteName: (j['siteName'] ?? '') as String,
        isSupplier: (j['isSupplier'] ?? false) as bool,
      );
}

// ---------------------------------------------------------------------------
// Karigar (worker) — customer ke advance mein se in ko payment jati hai.
// Har karigar payment ek 'kharcha' LedgerEntry hai jis par karigarId laga
// hota hai; isi liye karigar ki apni history bhi wohi entries hain.
// ---------------------------------------------------------------------------

class Karigar {
  final String id;
  String name;
  String phone;
  String note;
  final DateTime createdAt;

  Karigar({
    required this.id,
    required this.name,
    this.phone = '',
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Karigar.fromJson(Map<String, dynamic> j) => Karigar(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.now(),
      );
}

// ---------------------------------------------------------------------------
// CashBook
// ---------------------------------------------------------------------------

class CashEntry {
  final String id;
  final bool isIn; // true = paisa aaya (IN), false = paisa gaya (OUT)
  final double amount;
  final String note;
  final DateTime date;
  final String? partyId;

  CashEntry({
    required this.id,
    required this.isIn,
    required this.amount,
    required this.note,
    required this.date,
    this.partyId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'isIn': isIn,
        'amount': amount,
        'note': note,
        'date': date.toIso8601String(),
        'partyId': partyId,
      };

  factory CashEntry.fromJson(Map<String, dynamic> j) => CashEntry(
        id: j['id'] as String,
        isIn: (j['isIn'] ?? true) as bool,
        amount: (j['amount'] as num).toDouble(),
        note: (j['note'] ?? '') as String,
        date: DateTime.parse(j['date'] as String),
        partyId: j['partyId'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Expenses
// ---------------------------------------------------------------------------

class Expense {
  final String id;
  final String category;
  final double amount;
  final String note;
  final DateTime date;

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'amount': amount,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        category: (j['category'] ?? 'Deegar') as String,
        amount: (j['amount'] as num).toDouble(),
        note: (j['note'] ?? '') as String,
        date: DateTime.parse(j['date'] as String),
      );
}

// ---------------------------------------------------------------------------
// Inventory
// ---------------------------------------------------------------------------

class Item {
  final String id;
  String name;
  String unit; // sheet | bag | piece | ft
  double stockQty;
  double purchaseRate;
  double saleRate;
  String barcode;

  Item({
    required this.id,
    required this.name,
    this.unit = 'piece',
    this.stockQty = 0,
    this.purchaseRate = 0,
    this.saleRate = 0,
    this.barcode = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'stockQty': stockQty,
        'purchaseRate': purchaseRate,
        'saleRate': saleRate,
        'barcode': barcode,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        unit: (j['unit'] ?? 'piece') as String,
        stockQty: (j['stockQty'] ?? 0).toDouble(),
        purchaseRate: (j['purchaseRate'] ?? 0).toDouble(),
        saleRate: (j['saleRate'] ?? 0).toDouble(),
        barcode: (j['barcode'] ?? '') as String,
      );
}

// ---------------------------------------------------------------------------
// Bill / Invoice
// ---------------------------------------------------------------------------

/// Bill ki kaam wali line — sirf naam aur amount (koi measurement nahi).
class AmountLine {
  String label;
  double amount;

  AmountLine({
    this.label = '',
    this.amount = 0,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'amount': amount,
      };

  factory AmountLine.fromJson(Map<String, dynamic> j) => AmountLine(
        label: (j['label'] ?? '') as String,
        amount: (j['amount'] ?? 0).toDouble(),
      );

  /// Purani (v1.0/v1.1) measurement line se convert — purane saved bills
  /// khoonay par amount = lambai x chorai x rate.
  factory AmountLine.fromOldMeasureJson(Map<String, dynamic> j) => AmountLine(
        label: (j['label'] ?? '') as String,
        amount: ((j['lengthFt'] ?? 0) as num).toDouble() *
            ((j['widthFt'] ?? 0) as num).toDouble() *
            ((j['ratePerSqft'] ?? 0) as num).toDouble(),
      );
}

class MaterialLine {
  String itemId;
  String itemName;
  String unit;
  double qty;
  double rate;

  MaterialLine({
    required this.itemId,
    required this.itemName,
    this.unit = 'piece',
    this.qty = 0,
    this.rate = 0,
  });

  double get amount => qty * rate;

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'itemName': itemName,
        'unit': unit,
        'qty': qty,
        'rate': rate,
      };

  factory MaterialLine.fromJson(Map<String, dynamic> j) => MaterialLine(
        itemId: (j['itemId'] ?? '') as String,
        itemName: (j['itemName'] ?? '') as String,
        unit: (j['unit'] ?? 'piece') as String,
        qty: (j['qty'] ?? 0).toDouble(),
        rate: (j['rate'] ?? 0).toDouble(),
      );
}

class Bill {
  final String id;
  final int number; // Bill No (1, 2, 3...)
  final String partyId;
  final String partyName;
  final List<AmountLine> amountLines;
  final List<MaterialLine> materialLines;
  final double extraCharges;
  final String extraNote;
  final double advance;
  final DateTime date;
  final String note;

  Bill({
    required this.id,
    required this.number,
    required this.partyId,
    required this.partyName,
    required this.amountLines,
    required this.materialLines,
    this.extraCharges = 0,
    this.extraNote = '',
    this.advance = 0,
    required this.date,
    this.note = '',
  });

  double get amountTotal =>
      amountLines.fold(0.0, (s, l) => s + l.amount);
  double get materialTotal =>
      materialLines.fold(0.0, (s, l) => s + l.amount);
  double get total => amountTotal + materialTotal + extraCharges;
  double get baqaya => total - advance;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'partyId': partyId,
        'partyName': partyName,
        'amountLines': amountLines.map((e) => e.toJson()).toList(),
        'materialLines': materialLines.map((e) => e.toJson()).toList(),
        'extraCharges': extraCharges,
        'extraNote': extraNote,
        'advance': advance,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'] as String,
        number: (j['number'] ?? 0) as int,
        partyId: (j['partyId'] ?? '') as String,
        partyName: (j['partyName'] ?? '') as String,
        amountLines: j['amountLines'] != null
            ? ((j['amountLines'] as List)
                .map((e) => AmountLine.fromJson(e as Map<String, dynamic>))
                .toList())
            : ((j['measureLines'] ?? []) as List)
                .map((e) => AmountLine.fromOldMeasureJson(
                    e as Map<String, dynamic>))
                .toList(),
        materialLines: ((j['materialLines'] ?? []) as List)
            .map((e) => MaterialLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        extraCharges: (j['extraCharges'] ?? 0).toDouble(),
        extraNote: (j['extraNote'] ?? '') as String,
        advance: (j['advance'] ?? 0).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] ?? '') as String,
      );
}
