// v1.7 KHATA PRINT + PDF SHARE (2026-11-02): do print features —
//  1) Customer ka khata statement (Customer Detail screen ka button
//     'Khata Print Karo').
//  2) Total Khata (Home screen ka button 'Total Khata Print Karo') —
//     customer-wise summary + 'Date Wise Kul Hisab' (saari entries
//     tareekh ke hisaab se, poori kitab ka running baqi).
// Dono PDF `pdf` package se banti hain aur `Printing.layoutPdf` se
// system print / save / share UI khulta hai. Is ke ilawa dono ki
// 'PDF Share Karo' wali share actions bhi hain — wohi PDF bytes
// `Printing.sharePdf` se Android share sheet me jati hain (WhatsApp /
// koi bhi app user khud chunta hai; auto-send kabhi nahi). Totals hamesha store ke
// apne getters se ate hain (partyAdvanceTotal / partyKharchaTotal /
// partyBaqi / totalAdvance / totalKharcha / totalBaqi / cashBalance) —
// screens par jo numbers dikhte hain, print par bhi wohi.
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'helpers.dart';
import 'models.dart';
import 'store.dart';

// Design 2 ke rang, PDF ke liye (navy #10243E, amber #FFB300).
const _navy = PdfColor(0.063, 0.141, 0.243);
const _amber = PdfColor(1.0, 0.702, 0.0);
const _green = PdfColor(0.118, 0.490, 0.196);
const _red = PdfColor(0.776, 0.157, 0.157);

// pdf package ki built-in Helvetica '—' (em dash, U+2014) draw nahi kar
// sakti — 'Kharcha — Material' jaisi labels aadhi reh jati theen. Is liye
// bundle ki hui Roboto TTF (assets/fonts/) ko PDF theme bana kar dete
// hain; ek dafa load ho kar cache ho jati hai.
pw.ThemeData? _themeCache;

Future<pw.ThemeData> _pdfTheme() async {
  final cached = _themeCache;
  if (cached != null) return cached;
  final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
  final theme = pw.ThemeData.withFont(
    base: pw.Font.ttf(regular),
    bold: pw.Font.ttf(bold),
  );
  _themeCache = theme;
  return theme;
}

/// Print par entry ki detail wahi andaz me jo app ki history me hai:
/// advance → 'Advance Liya', karigar kharcha → 'Kharcha — {karigar naam}'
/// (store ka karigarById lookup; karigar delete ho chuka ho to 'Karigar'),
/// Material / Custom → 'Kharcha — {kharchaLabel}', legacy types →
/// un ka typeLabel ('Payment Mili' / 'Payment Di' / 'Udhaar Diya' /
/// 'Udhaar Liya').
String khataDetailLabel(AppStore store, LedgerEntry e) {
  switch (e.type) {
    case 'advance':
      return 'Advance Liya';
    case 'kharcha':
      if (e.karigarId != null) {
        final k = store.karigarById(e.karigarId!);
        return 'Kharcha — ${k?.name ?? 'Karigar'}';
      }
      final lbl = e.kharchaLabel;
      if (lbl != null && lbl.isNotEmpty) return 'Kharcha — $lbl';
      return 'Kharcha';
    default:
      return e.typeLabel;
  }
}

/// Entries ko date ke hisaab se ascending sort — same date par store ki
/// insertion order barkarar (Dart ki sort stable nahi hoti, is liye
/// asal index tie-breaker hai). Total Khata ki date-wise section aur
/// us ke running baqi ke liye.
List<LedgerEntry> dateWiseEntries(List<LedgerEntry> entries) {
  final indexed = <(int, LedgerEntry)>[
    for (var i = 0; i < entries.length; i++) (i, entries[i]),
  ];
  indexed.sort((a, b) {
    final c = a.$2.date.compareTo(b.$2.date);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final t in indexed) t.$2];
}

// ---------------------------------------------------------------------------
// Chhoti PDF helpers
// ---------------------------------------------------------------------------

pw.Widget _cell(
  String text, {
  bool bold = false,
  PdfColor? color,
  pw.Alignment align = pw.Alignment.centerLeft,
  double size = 10.5,
  PdfColor? bg,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
    alignment: align,
    decoration: bg == null ? null : pw.BoxDecoration(color: bg),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
    ),
  );
}

pw.Widget _headCell(String text, {pw.Alignment align = pw.Alignment.centerLeft}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    alignment: align,
    decoration: const pw.BoxDecoration(color: _navy),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );
}

/// Detail cell — label upar, note ho to neeche chhoti grey line me.
pw.Widget _detailCell(AppStore store, LedgerEntry e) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
    alignment: pw.Alignment.centerLeft,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          khataDetailLabel(store, e),
          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
        ),
        if (e.note.isNotEmpty)
          pw.Text(
            e.note,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
      ],
    ),
  );
}

String _signedAmt(LedgerEntry e) =>
    '${e.baqiEffect >= 0 ? '+' : '-'}${rs(e.amount)}';

PdfColor _amtColor(LedgerEntry e) => e.baqiEffect >= 0 ? _green : _red;

/// Upar wala navy banner (shop ka naam settings se; default 'Khata Book')
/// + print date.
pw.Widget _banner(AppStore store, DateTime printedOn) {
  final shop = store.businessName.trim();
  final hasShop = shop.isNotEmpty && shop != 'Khata Book';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: _navy,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              hasShop ? shop : 'Khata Book',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _amber,
              ),
            ),
            if (hasShop)
              pw.Text(
                'Khata Book',
                style: const pw.TextStyle(
                  fontSize: 10.5,
                  color: PdfColors.white,
                ),
              ),
          ],
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Print date: ${fmtDate(printedOn)}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 10),
    ],
  );
}

pw.Widget _totalLine(String label, String value, {bool bold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _pageFooter(pw.Context ctx) {
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
    ),
  );
}

// ---------------------------------------------------------------------------
// 1) Customer ka khata statement
// ---------------------------------------------------------------------------

Future<Uint8List> buildCustomerKhataPdf(AppStore store, Party party) async {
  // partyEntries date ascending deta hai — wohi order jo Customer Detail
  // screen running baqi ke liye istemal karti hai.
  final entries = store.partyEntries(party.id);
  final kulAdvance = store.partyAdvanceTotal(party.id);
  final kulKharcha = store.partyKharchaTotal(party.id);
  final baqi = store.partyBaqi(party.id);

  final rows = <pw.TableRow>[
    pw.TableRow(
      children: [
        _headCell('Date'),
        _headCell('Detail'),
        _headCell('Amount', align: pw.Alignment.centerRight),
        _headCell('Baqi', align: pw.Alignment.centerRight),
      ],
    ),
  ];
  double run = 0;
  for (final e in entries) {
    run += e.baqiEffect;
    rows.add(
      pw.TableRow(
        children: [
          _cell(fmtDate(e.date)),
          _detailCell(store, e),
          _cell(
            _signedAmt(e),
            align: pw.Alignment.centerRight,
            color: _amtColor(e),
            bold: true,
          ),
          _cell(rs(run), align: pw.Alignment.centerRight),
        ],
      ),
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      theme: await _pdfTheme(),
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: _pageFooter,
      build: (ctx) => [
        _banner(store, DateTime.now()),
        pw.Text(
          'Customer: ${party.name}',
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            color: _navy,
          ),
        ),
        if (party.phone.isNotEmpty)
          pw.Text(
            'Phone: ${party.phone}',
            style: const pw.TextStyle(fontSize: 11),
          ),
        if (party.siteName.isNotEmpty)
          pw.Text(
            'Site: ${party.siteName}',
            style: const pw.TextStyle(fontSize: 11),
          ),
        pw.SizedBox(height: 10),
        if (entries.isEmpty)
          pw.Text(
            'Abhi koi entry nahi hai.',
            style: const pw.TextStyle(fontSize: 11),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(80),
              1: pw.FlexColumnWidth(),
              2: pw.FixedColumnWidth(95),
              3: pw.FixedColumnWidth(95),
            },
            children: rows,
          ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 250,
              child: pw.Column(
                children: [
                  _totalLine('Kul Advance', rs(kulAdvance)),
                  _totalLine('Kul Kharcha', rs(kulKharcha)),
                  pw.Divider(color: _navy, thickness: 1),
                  _totalLine('Baqi Paisa', rs(baqi), bold: true),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

Future<void> printCustomerKhata(AppStore store, Party party) async {
  await Printing.layoutPdf(
    name: 'Khata - ${party.name}',
    onLayout: (format) => buildCustomerKhataPdf(store, party),
  );
}

/// Share-sheet ke filename ke liye mehfooz naam — sirf A-Z / a-z / 0-9
/// rehte hain, baqi har character (spaces, dashes, ghair-ASCII) '_'
/// ban jata hai. Kuch bhi na bache to 'Customer'.
String safePdfFilePart(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  final core = cleaned.replaceAll(RegExp(r'^_+|_+$'), '');
  return core.isEmpty ? 'Customer' : core;
}

/// Wohi customer khata PDF seedha Android share sheet se bhejo —
/// WhatsApp / doosri apps user khud chunta hai.
Future<void> shareCustomerKhata(AppStore store, Party party) async {
  final bytes = await buildCustomerKhataPdf(store, party);
  await Printing.sharePdf(
    bytes: bytes,
    filename: '${safePdfFilePart(party.name)}_Khata.pdf',
  );
}

// ---------------------------------------------------------------------------
// 2) Total Khata — customer-wise summary + date-wise kul hisaab
// ---------------------------------------------------------------------------

Future<Uint8List> buildTotalKhataPdf(AppStore store) async {
  final parties = [...store.parties]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  // --- Section 1: customer-wise summary ---
  final summaryRows = <pw.TableRow>[
    pw.TableRow(
      children: [
        _headCell('Customer'),
        _headCell('Kul Advance', align: pw.Alignment.centerRight),
        _headCell('Kul Kharcha', align: pw.Alignment.centerRight),
        _headCell('Baqi Paisa', align: pw.Alignment.centerRight),
      ],
    ),
  ];
  for (final p in parties) {
    summaryRows.add(
      pw.TableRow(
        children: [
          _cell(p.name, bold: true),
          _cell(
            rs(store.partyAdvanceTotal(p.id)),
            align: pw.Alignment.centerRight,
          ),
          _cell(
            rs(store.partyKharchaTotal(p.id)),
            align: pw.Alignment.centerRight,
          ),
          _cell(
            rs(store.partyBaqi(p.id)),
            align: pw.Alignment.centerRight,
            bold: true,
          ),
        ],
      ),
    );
  }
  // v1.8: apna (general) kharcha bhi summary me apni line par — taake
  // TOTAL wali Kul Kharcha customer rows ke kul se milti rahe.
  if (store.generalKharchaTotal > 0) {
    summaryRows.add(
      pw.TableRow(
        children: [
          _cell('Apna Kharcha', bold: true),
          _cell(rs(0), align: pw.Alignment.centerRight),
          _cell(
            rs(store.generalKharchaTotal),
            align: pw.Alignment.centerRight,
          ),
          _cell(rs(0), align: pw.Alignment.centerRight, bold: true),
        ],
      ),
    );
  }
  // Grand totals — Home hero ke wohi numbers (store ke total getters).
  summaryRows.add(
    pw.TableRow(
      children: [
        _cell('TOTAL', bold: true, bg: PdfColors.amber100),
        _cell(
          rs(store.totalAdvance),
          align: pw.Alignment.centerRight,
          bold: true,
          bg: PdfColors.amber100,
        ),
        _cell(
          rs(store.totalKharcha),
          align: pw.Alignment.centerRight,
          bold: true,
          bg: PdfColors.amber100,
        ),
        _cell(
          rs(store.totalBaqi),
          align: pw.Alignment.centerRight,
          bold: true,
          bg: PdfColors.amber100,
        ),
      ],
    ),
  );

  // --- Section 2: date-wise kul hisaab ---
  final wise = dateWiseEntries(store.ledger);
  final wiseRows = <pw.TableRow>[
    pw.TableRow(
      children: [
        _headCell('Date'),
        _headCell('Customer'),
        _headCell('Detail'),
        _headCell('Amount', align: pw.Alignment.centerRight),
        _headCell('Baqi', align: pw.Alignment.centerRight),
      ],
    ),
  ];
  double run = 0;
  for (final e in wise) {
    // Apna kharcha (partyId null) kisi customer ke baqi ko nahi badalta —
    // running baqi sirf customer entries par chalta hai, aur us row ki
    // Baqi cell me '—' ata hai.
    final isApna = e.partyId == null;
    if (!isApna) run += e.baqiEffect;
    wiseRows.add(
      pw.TableRow(
        children: [
          _cell(fmtDate(e.date)),
          _cell(
            isApna ? 'Apna Kharcha' : store.partyById(e.partyId)?.name ?? '',
          ),
          _detailCell(store, e),
          _cell(
            _signedAmt(e),
            align: pw.Alignment.centerRight,
            color: _amtColor(e),
            bold: true,
          ),
          _cell(isApna ? '—' : rs(run), align: pw.Alignment.centerRight),
        ],
      ),
    );
  }

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      theme: await _pdfTheme(),
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: _pageFooter,
      build: (ctx) => [
        _banner(store, DateTime.now()),
        pw.Text(
          'Total Khata',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: _navy,
          ),
        ),
        pw.SizedBox(height: 8),
        if (parties.isEmpty)
          pw.Text(
            'Abhi koi customer nahi hai.',
            style: const pw.TextStyle(fontSize: 11),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(),
              1: pw.FixedColumnWidth(100),
              2: pw.FixedColumnWidth(100),
              3: pw.FixedColumnWidth(100),
            },
            children: summaryRows,
          ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Cash (galla): ${rs(store.cashBalance())}',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 18),
        pw.Text(
          'Date Wise Kul Hisab',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: _navy,
          ),
        ),
        pw.SizedBox(height: 8),
        if (wise.isEmpty)
          pw.Text(
            'Abhi koi entry nahi hai.',
            style: const pw.TextStyle(fontSize: 11),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(72),
              1: pw.FixedColumnWidth(88),
              2: pw.FlexColumnWidth(),
              3: pw.FixedColumnWidth(90),
              4: pw.FixedColumnWidth(90),
            },
            children: wiseRows,
          ),
      ],
    ),
  );
  return doc.save();
}

Future<void> printTotalKhata(AppStore store) async {
  await Printing.layoutPdf(
    name: 'Total Khata',
    onLayout: (format) => buildTotalKhataPdf(store),
  );
}

/// Wohi Total Khata PDF seedha Android share sheet se bhejo —
/// WhatsApp / doosri apps user khud chunta hai.
Future<void> shareTotalKhata(AppStore store) async {
  final bytes = await buildTotalKhataPdf(store);
  await Printing.sharePdf(bytes: bytes, filename: 'Total_Khata.pdf');
}
