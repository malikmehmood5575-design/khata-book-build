import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';
import 'store.dart';
import 'helpers.dart';

final _navy = PdfColor.fromHex('#10243E');
final _amber = PdfColor.fromHex('#FFB300');
final _grey = PdfColor.fromHex('#666666');

pw.Widget _header(String business, String title) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _navy,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(business,
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold)),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(
                color: _amber,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 12),
    ],
  );
}

/// Party ke khate ki PDF report — share/print ke liye.
Future<void> sharePartyKhataPdf(AppStore store, Party party) async {
  final entries = store.partyEntries(party.id);
  final balance = store.partyBalance(party.id);
  final doc = pw.Document();

  // Running balance ke sath rows
  double run = 0;
  final rows = <List<String>>[];
  for (final e in entries) {
    run += e.signed;
    rows.add([
      fmtDate(e.date),
      e.typeLabel,
      e.note,
      e.signed >= 0 ? rs(e.amount) : '-${rs(e.amount)}',
      rs(run),
    ]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        _header(store.businessName, 'KHATA REPORT'),
        pw.Text('Party: ${party.name}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        if (party.siteName.isNotEmpty)
          pw.Text('Site: ${party.siteName}', style: pw.TextStyle(color: _grey)),
        if (party.phone.isNotEmpty)
          pw.Text('Phone: ${party.phone}', style: pw.TextStyle(color: _grey)),
        pw.Text(party.isSupplier ? 'Type: Supplier' : 'Type: Customer',
            style: pw.TextStyle(color: _grey)),
        pw.SizedBox(height: 10),
        if (rows.isEmpty)
          pw.Text('Abhi koi entry nahi hai.')
        else
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Note', 'Amount', 'Balance'],
            data: rows,
            headerStyle: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: _navy),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
        pw.SizedBox(height: 14),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F6F4EF'),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(
            balance >= 0
                ? 'Kul Baqaya (lena hai): ${rs(balance)}'
                : 'Kul Baqaya (dena hai): ${rs(-balance)}',
            style:
                pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  await Printing.sharePdf(
      bytes: await doc.save(), filename: 'khata-${party.name}.pdf');
}

/// Bill ki PDF — share/print ke liye.
Future<void> shareBillPdf(AppStore store, Bill bill) async {
  final doc = pw.Document();

  final measureRows = bill.measureLines
      .map((l) => [
            l.label,
            '${qtyFmt(l.lengthFt)} x ${qtyFmt(l.widthFt)}',
            qtyFmt(l.sqft),
            rs(l.ratePerSqft),
            rs(l.amount),
          ])
      .toList();
  final materialRows = bill.materialLines
      .map((l) => [
            l.itemName,
            '${qtyFmt(l.qty)} ${l.unit}',
            rs(l.rate),
            rs(l.amount),
          ])
      .toList();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _header(store.businessName, 'BILL / INVOICE'),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Bill No: ${bill.number}',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date: ${fmtDate(bill.date)}'),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text('Customer: ${bill.partyName}', style: pw.TextStyle(fontSize: 12)),
          if (bill.note.isNotEmpty) pw.Text('Note: ${bill.note}'),
          pw.SizedBox(height: 12),
          if (measureRows.isNotEmpty) ...[
            pw.Text('Measurement (Ceiling)',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['Item', 'Size (ft)', 'Sq Ft', 'Rate/SqFt', 'Amount'],
              data: measureRows,
              headerStyle: pw.TextStyle(
                  color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: _navy),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Measurement Total: ${rs(bill.measureTotal)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
          ],
          if (materialRows.isNotEmpty) ...[
            pw.Text('Material',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['Item', 'Qty', 'Rate', 'Amount'],
              data: materialRows,
              headerStyle: pw.TextStyle(
                  color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(color: _navy),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 6),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Material Total: ${rs(bill.materialTotal)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
          ],
          pw.Divider(),
          if (bill.extraCharges > 0)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                    'Extra Charges${bill.extraNote.isNotEmpty ? ' (${bill.extraNote})' : ''}'),
                pw.Text(rs(bill.extraCharges)),
              ],
            ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Kul Total',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(rs(bill.total),
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Advance Mila'),
              pw.Text('- ${rs(bill.advance)}'),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F6F4EF'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Baqaya',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(rs(bill.baqaya),
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Text('Shukriya! — ${store.businessName}',
              style: pw.TextStyle(color: _grey)),
        ],
      ),
    ),
  );

  await Printing.sharePdf(
      bytes: await doc.save(), filename: 'bill-${bill.number}.pdf');
}

/// Bill ka WhatsApp text summary.
String billWhatsAppText(AppStore store, Bill bill) {
  final b = StringBuffer();
  b.writeln('*${store.businessName}*');
  b.writeln('Bill No: ${bill.number}  (${fmtDate(bill.date)})');
  b.writeln('Customer: ${bill.partyName}');
  b.writeln('--------------------------');
  for (final l in bill.measureLines) {
    b.writeln(
        '${l.label}: ${qtyFmt(l.lengthFt)} x ${qtyFmt(l.widthFt)} ft = ${qtyFmt(l.sqft)} sq ft @ ${rs(l.ratePerSqft)} = ${rs(l.amount)}');
  }
  for (final l in bill.materialLines) {
    b.writeln(
        '${l.itemName}: ${qtyFmt(l.qty)} ${l.unit} @ ${rs(l.rate)} = ${rs(l.amount)}');
  }
  if (bill.extraCharges > 0) {
    b.writeln(
        'Extra${bill.extraNote.isNotEmpty ? ' (${bill.extraNote})' : ''}: ${rs(bill.extraCharges)}');
  }
  b.writeln('--------------------------');
  b.writeln('Kul Total: ${rs(bill.total)}');
  b.writeln('Advance: ${rs(bill.advance)}');
  b.writeln('*Baqaya: ${rs(bill.baqaya)}*');
  b.writeln('Shukriya!');
  return b.toString();
}
