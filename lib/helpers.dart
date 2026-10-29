import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

final _rsFmt = NumberFormat('#,##0.##', 'en_US');
final _dateFmt = DateFormat('dd MMM yyyy');
final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

String rs(num v) {
  final neg = v < 0;
  final s = 'Rs ${_rsFmt.format(v.abs())}';
  return neg ? '-$s' : s;
}

String rsShort(num v) => _rsFmt.format(v);

String fmtDate(DateTime d) => _dateFmt.format(d);
String fmtDateTime(DateTime d) => _dateTimeFmt.format(d);

String qtyFmt(num v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

/// Phone ko WhatsApp ke liye saaf karo: 03xx -> 923xx
String waPhone(String raw) {
  var p = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (p.startsWith('0')) p = '92${p.substring(1)}';
  if (p.startsWith('3') && p.length == 10) p = '92$p';
  return p;
}

/// WhatsApp chat kholo pre-filled message ke sath.
/// Message khud user bhejta hai — app kabhi auto-send nahi karti.
Future<bool> openWhatsApp(
    BuildContext context, String phone, String message) async {
  final p = waPhone(phone);
  if (p.length < 10) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Is party ka sahi phone number nahi hai')),
      );
    }
    return false;
  }
  final uri = Uri.parse(
      'https://wa.me/$p?text=${Uri.encodeComponent(message)}');
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp nahi khul saka')),
      );
    }
    return ok;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp nahi khul saka')),
      );
    }
    return false;
  }
}

Future<DateTime?> pickDate(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));
}
