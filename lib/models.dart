import 'dart:math';

String newId() {
  final r = Random();
  return '${DateTime.now().microsecondsSinceEpoch}-${r.nextInt(999999)}';
}

// ---------------------------------------------------------------------------
// Party (customer / supplier) + us ka khata ledger
// ---------------------------------------------------------------------------

/// Khata entry ki type:
/// udhaarDiya  = customer ko udhaar diya (balance barhta hai, lena hai)
/// udhaarLiya  = supplier se udhaar liya (balance negative, dena hai)
/// paymentMili = customer se payment mili (balance kam)
/// paymentDi   = supplier ko payment di (balance negative se kam)
class LedgerEntry {
  final String id;
  final String partyId;
  final String type; // udhaarDiya | udhaarLiya | paymentMili | paymentDi
  final double amount;
  final String note;
  final DateTime date;
  final String? billId;

  LedgerEntry({
    required this.id,
    required this.partyId,
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
    this.billId,
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
      default:
        return 0;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'udhaarDiya':
        return 'Udhaar Diya';
      case 'udhaarLiya':
        return 'Udhaar Liya';
      case 'paymentMili':
        return 'Payment Mili';
      case 'paymentDi':
        return 'Payment Di';
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
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: j['id'] as String,
        partyId: j['partyId'] as String,
        type: j['type'] as String,
        amount: (j['amount'] as num).toDouble(),
        note: (j['note'] ?? '') as String,
        date: DateTime.parse(j['date'] as String),
        billId: j['billId'] as String?,
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

class MeasureLine {
  String label;
  double lengthFt;
  double widthFt;
  double ratePerSqft;

  MeasureLine({
    this.label = '',
    this.lengthFt = 0,
    this.widthFt = 0,
    this.ratePerSqft = 0,
  });

  double get sqft => lengthFt * widthFt;
  double get amount => sqft * ratePerSqft;

  Map<String, dynamic> toJson() => {
        'label': label,
        'lengthFt': lengthFt,
        'widthFt': widthFt,
        'ratePerSqft': ratePerSqft,
      };

  factory MeasureLine.fromJson(Map<String, dynamic> j) => MeasureLine(
        label: (j['label'] ?? '') as String,
        lengthFt: (j['lengthFt'] ?? 0).toDouble(),
        widthFt: (j['widthFt'] ?? 0).toDouble(),
        ratePerSqft: (j['ratePerSqft'] ?? 0).toDouble(),
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
  final List<MeasureLine> measureLines;
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
    required this.measureLines,
    required this.materialLines,
    this.extraCharges = 0,
    this.extraNote = '',
    this.advance = 0,
    required this.date,
    this.note = '',
  });

  double get measureTotal =>
      measureLines.fold(0.0, (s, l) => s + l.amount);
  double get materialTotal =>
      materialLines.fold(0.0, (s, l) => s + l.amount);
  double get total => measureTotal + materialTotal + extraCharges;
  double get baqaya => total - advance;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'partyId': partyId,
        'partyName': partyName,
        'measureLines': measureLines.map((e) => e.toJson()).toList(),
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
        measureLines: ((j['measureLines'] ?? []) as List)
            .map((e) => MeasureLine.fromJson(e as Map<String, dynamic>))
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
