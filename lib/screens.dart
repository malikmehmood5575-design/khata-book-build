import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'models.dart';
import 'store.dart';
import 'helpers.dart';
import 'pdf_gen.dart';
import 'theme.dart';

AppStore get store => AppStore.instance;

Widget loadingWrap(Widget child) {
  return AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      if (!store.ready) {
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: kAmber),
                SizedBox(height: 14),
                Text('Khata Book khul raha hai…'),
              ],
            ),
          ),
        );
      }
      return child;
    },
  );
}

Widget storeBuilder(Widget Function(BuildContext) builder) {
  return AnimatedBuilder(
    animation: store,
    builder: (context, _) => builder(context),
  );
}

void push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

// ===========================================================================
// Main shell — bottom nav: Home, Khata, [+], Stock, Reports
// ===========================================================================

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static const _tabs = [
    HomeScreen(),
    KhataScreen(),
    StockScreen(),
    ReportsScreen(),
  ];
  // nav index mapping: 0 Home, 1 Khata, 2 (+) action, 3 Stock, 4 Reports
  int get _pageIndex => _tab <= 1 ? _tab : _tab - 1;

  void _onNavTap(int i) {
    if (i == 2) {
      _showQuickAdd(context);
      return;
    }
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    return loadingWrap(
      Scaffold(
        body: _tabs[_pageIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _onNavTap,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Khata'),
            NavigationDestination(
              icon: Icon(Icons.add_circle, color: kAmber, size: 38),
              label: 'Naya',
            ),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Stock'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          ],
        ),
      ),
    );
  }
}

void _showQuickAdd(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Naya kya banana hai?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long, color: kNavy),
            title: const Text('Naya Bill'),
            subtitle: const Text('Sq ft measurement + material'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const BillFormScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add, color: kNavy),
            title: const Text('Nayi Party'),
            subtitle: const Text('Customer ya supplier jodo'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const PartyFormScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz, color: kNavy),
            title: const Text('Cash Entry'),
            subtitle: const Text('CashBook me paisa in / out'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const CashEntryFormScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.money_off, color: kNavy),
            title: const Text('Kharcha'),
            subtitle: const Text('Category ke sath kharcha likho'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const ExpenseFormScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_box, color: kNavy),
            title: const Text('Naya Item (Stock)'),
            subtitle: const Text('Ceiling material jodo'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const ItemFormScreen());
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ===========================================================================
// Home
// ===========================================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final today = store.totalsFor(dayStart, dayStart.add(const Duration(days: 1)));
      final lowStock = store.items.where((i) => i.stockQty <= 0).toList();
      final recent = [...store.ledger]
        ..sort((a, b) => b.date.compareTo(a.date));
      final recentBills = [...store.bills]
        ..sort((a, b) => b.date.compareTo(a.date));

      return Scaffold(
        appBar: AppBar(
          title: Text(store.businessName),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => push(context, const SettingsScreen()),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          children: [
            // Kul baqaya hero card (navy)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kNavy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kul Baqaya (lena hai)',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(rs(store.totalLena),
                      style: const TextStyle(
                          color: kAmber,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Dena hai: ${rs(store.totalDena)}',
                            style: const TextStyle(color: Colors.white)),
                      ),
                      Text('Cash: ${rs(store.cashBalance())}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Aaj Wasooli (In)',
                              style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                          Text(rs(today.cashIn),
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: kGreen)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Aaj Gaya (Out + Kharcha)',
                              style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                          Text(rs(today.cashOut + today.kharcha),
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: kRed)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 10, 14, 2),
              child: Text('Jaldi kaam',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.12,
                children: [
                  _QuickBtn(icon: Icons.receipt_long, label: 'Naya Bill', onTap: () => push(context, const BillFormScreen())),
                  _QuickBtn(icon: Icons.list_alt, label: 'Saare Bills', onTap: () => push(context, const BillsListScreen())),
                  _QuickBtn(icon: Icons.swap_horiz, label: 'CashBook', onTap: () => push(context, const CashbookScreen())),
                  _QuickBtn(icon: Icons.money_off, label: 'Kharcha', onTap: () => push(context, const ExpensesScreen())),
                  _QuickBtn(icon: Icons.person_add, label: 'Nayi Party', onTap: () => push(context, const PartyFormScreen())),
                  _QuickBtn(icon: Icons.qr_code_scanner, label: 'Barcode Scan', onTap: () => _scanFromHome(context)),
                ],
              ),
            ),
            if (lowStock.isNotEmpty)
              Card(
                color: const Color(0xFFFFF3D6),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber, color: Color(0xFF8A6100)),
                  title: Text('${lowStock.length} item ka stock khatam hai',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(lowStock.take(3).map((e) => e.name).join(', ')),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 2),
              child: Text('Haal ki khata entries',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Abhi koi entry nahi. + button se shuru karo.'),
              ),
            ...recent.take(6).map((e) {
              final p = store.partyById(e.partyId);
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text('${p?.name ?? ''} — ${e.typeLabel}'),
                  subtitle: Text('${fmtDate(e.date)}${e.note.isNotEmpty ? ' · ${e.note}' : ''}'),
                  trailing: Text(
                    '${e.signed >= 0 ? '+' : '-'}${rs(e.amount)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: e.signed >= 0 ? kGreen : kRed),
                  ),
                ),
              );
            }),
            if (recentBills.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 2),
                child: Text('Haal ke bills',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              ...recentBills.take(3).map((b) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text('Bill No ${b.number} — ${b.partyName}'),
                      subtitle: Text(fmtDate(b.date)),
                      trailing: Text(rs(b.total),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      onTap: () => push(context, BillDetailScreen(billId: b.id)),
                    ),
                  )),
            ],
          ],
        ),
      );
    });
  }

  Future<void> _scanFromHome(BuildContext context) async {
    final code = await pushForResult<String>(context, const ScannerScreen());
    if (code == null || !context.mounted) return;
    final item = store.itemByBarcode(code);
    if (item != null) {
      push(context, ItemFormScreen(existing: item));
    } else {
      toast(context, 'Is barcode ka item nahi mila: $code');
    }
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kCardBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFFD98E00), size: 26),
            const SizedBox(height: 5),
            Text(label,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

/// Result ke sath screen kholne ka helper.
Future<T?> pushForResult<T>(BuildContext context, Widget screen) {
  return Navigator.of(context)
      .push<T>(MaterialPageRoute(builder: (_) => screen));
}

// ===========================================================================
// Khata — parties ki list
// ===========================================================================

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final list = store.parties.where((p) {
        final q = _q.toLowerCase();
        return q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.siteName.toLowerCase().contains(q) ||
            p.phone.contains(q);
      }).toList()
        ..sort((a, b) => store
            .partyBalance(b.id)
            .abs()
            .compareTo(store.partyBalance(a.id).abs()));

      return Scaffold(
        appBar: AppBar(title: const Text('Khata — Parties')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => push(context, const PartyFormScreen()),
          icon: const Icon(Icons.person_add),
          label: const Text('Nayi Party'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Party, site ya number dhundo…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('Koi party nahi. "Nayi Party" se jodo.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 84),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final p = list[i];
                        final bal = store.partyBalance(p.id);
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: kNavy,
                              child: Text(
                                p.name.isNotEmpty
                                    ? p.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: kAmber, fontWeight: FontWeight.w800),
                              ),
                            ),
                            title: Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text([
                              if (p.siteName.isNotEmpty) 'Site: ${p.siteName}',
                              p.isSupplier ? 'Supplier' : 'Customer',
                            ].join(' · ')),
                            trailing: bal == 0
                                ? const Text('Clear',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: kGreen))
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(rs(bal.abs()),
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: bal > 0 ? kRed : kGreen)),
                                      Text(bal > 0 ? 'Lena hai' : 'Dena hai',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.black54)),
                                    ],
                                  ),
                            onTap: () =>
                                push(context, PartyDetailScreen(partyId: p.id)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }
}

// ===========================================================================
// Party banana / edit karna
// ===========================================================================

class PartyFormScreen extends StatefulWidget {
  final Party? existing;
  const PartyFormScreen({super.key, this.existing});

  @override
  State<PartyFormScreen> createState() => _PartyFormScreenState();
}

class _PartyFormScreenState extends State<PartyFormScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phone ?? '');
  late final TextEditingController _site =
      TextEditingController(text: widget.existing?.siteName ?? '');
  late bool _isSupplier = widget.existing?.isSupplier ?? false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _site.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Naam likhna zaroori hai');
      return;
    }
    if (widget.existing == null) {
      await store.addParty(Party(
        id: newId(),
        name: name,
        phone: _phone.text.trim(),
        siteName: _site.text.trim(),
        isSupplier: _isSupplier,
      ));
      if (mounted) toast(context, 'Party ban gayi');
    } else {
      final p = widget.existing!;
      p.name = name;
      p.phone = _phone.text.trim();
      p.siteName = _site.text.trim();
      p.isSupplier = _isSupplier;
      await store.updateParty(p);
      if (mounted) toast(context, 'Party update ho gayi');
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null ? 'Nayi Party' : 'Party Edit Karo')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Naam *', hintText: 'Masalan: Ahmed Raza'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Phone (WhatsApp)',
                hintText: '03xx-xxxxxxx'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _site,
            decoration: const InputDecoration(
                labelText: 'Site / Jagah ka naam',
                hintText: 'Masalan: Gulberg House'),
          ),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Customer'), icon: Icon(Icons.person)),
              ButtonSegment(value: true, label: Text('Supplier'), icon: Icon(Icons.store)),
            ],
            selected: {_isSupplier},
            onSelectionChanged: (s) => setState(() => _isSupplier = s.first),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Karo'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Party detail — pura khata
// ===========================================================================

class PartyDetailScreen extends StatelessWidget {
  final String partyId;
  const PartyDetailScreen({super.key, required this.partyId});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final party = store.partyById(partyId);
      if (party == null) {
        return const Scaffold(body: Center(child: Text('Party nahi mili')));
      }
      final entries = store.partyEntries(partyId);
      final balance = store.partyBalance(partyId);

      // Running balance har entry ke sath
      double run = 0;
      final rows = <(LedgerEntry, double)>[];
      for (final e in entries) {
        run += e.signed;
        rows.add((e, run));
      }
      final display = rows.reversed.toList();

      return Scaffold(
        appBar: AppBar(
          title: Text(party.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () =>
                  push(context, PartyFormScreen(existing: party)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmDeleteParty(context, party),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: kNavy, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party.isSupplier ? 'Supplier' : 'Customer',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  if (party.siteName.isNotEmpty)
                    Text('Site: ${party.siteName}',
                        style: const TextStyle(color: Colors.white)),
                  if (party.phone.isNotEmpty)
                    Text(party.phone,
                        style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    balance == 0
                        ? 'Hisaab Clear'
                        : balance > 0
                            ? 'Lena hai: ${rs(balance)}'
                            : 'Dena hai: ${rs(-balance)}',
                    style: const TextStyle(
                        color: kAmber,
                        fontSize: 21,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionChip(
                    icon: Icons.arrow_upward,
                    label: 'Udhaar Diya',
                    onTap: () => push(context,
                        LedgerEntryFormScreen(party: party, type: 'udhaarDiya')),
                  ),
                  _ActionChip(
                    icon: Icons.arrow_downward,
                    label: 'Udhaar Liya',
                    onTap: () => push(context,
                        LedgerEntryFormScreen(party: party, type: 'udhaarLiya')),
                  ),
                  _ActionChip(
                    icon: Icons.payments,
                    label: 'Payment Mili',
                    onTap: () => push(context, LedgerEntryFormScreen(
                        party: party, type: 'paymentMili')),
                  ),
                  _ActionChip(
                    icon: Icons.money,
                    label: 'Payment Di',
                    onTap: () => push(context,
                        LedgerEntryFormScreen(party: party, type: 'paymentDi')),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sendReminder(context, party, balance),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('WhatsApp Reminder'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => sharePartyKhataPdf(store, party),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Khata PDF'),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 2),
              child: Text('Pura Khata',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            if (display.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Abhi koi entry nahi hai.'),
              ),
            ...display.map((row) {
              final e = row.$1;
              final balAfter = row.$2;
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text(e.typeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${fmtDate(e.date)}${e.note.isNotEmpty ? ' · ${e.note}' : ''}\nBalance: ${rs(balAfter)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${e.signed >= 0 ? '+' : '-'}${rs(e.amount)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: e.signed >= 0 ? kGreen : kRed),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 19),
                        onPressed: () async {
                          await store.deleteLedgerEntry(e.id);
                          if (context.mounted) {
                            toast(context, 'Entry delete ho gayi');
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: e.billId != null
                      ? () => push(
                          context, BillDetailScreen(billId: e.billId!))
                      : null,
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  Future<void> _sendReminder(
      BuildContext context, Party party, double balance) async {
    if (balance <= 0) {
      toast(context, 'Is party ka koi baqaya nahi hai');
      return;
    }
    final msg = 'Assalam-o-Alaikum ${party.name} Sahab,\n'
        '${store.businessName} ki taraf se yaad dehani hai ke aap ka baqaya '
        '${rs(balance)} hai. Meharbani karke payment ka bandobast kar dein.\n'
        'Shukriya!';
    await openWhatsApp(context, party.phone, msg);
  }

  Future<void> _confirmDeleteParty(BuildContext context, Party party) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Party delete karein?'),
        content: Text(
            '${party.name} aur us ka saara khata delete ho jayega. Ye wapas nahi aayega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nahi')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) {
      await store.deleteParty(party.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 17, color: kNavy),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: kCardBorder),
    );
  }
}

// ===========================================================================
// Khata entry form (udhaar / payment)
// ===========================================================================

class LedgerEntryFormScreen extends StatefulWidget {
  final Party party;
  final String type;
  const LedgerEntryFormScreen(
      {super.key, required this.party, required this.type});

  @override
  State<LedgerEntryFormScreen> createState() =>
      _LedgerEntryFormScreenState();
}

class _LedgerEntryFormScreenState extends State<LedgerEntryFormScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _alsoCash = true;

  String get _title {
    switch (widget.type) {
      case 'udhaarDiya':
        return 'Udhaar Diya';
      case 'udhaarLiya':
        return 'Udhaar Liya';
      case 'paymentMili':
        return 'Payment Mili';
      case 'paymentDi':
        return 'Payment Di';
      default:
        return 'Entry';
    }
  }

  bool get _isPayment =>
      widget.type == 'paymentMili' || widget.type == 'paymentDi';

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) {
      toast(context, 'Sahi raqam likho');
      return;
    }
    await store.addLedgerEntry(
      LedgerEntry(
        id: newId(),
        partyId: widget.party.id,
        type: widget.type,
        amount: amt,
        note: _note.text.trim(),
        date: _date,
      ),
      alsoCash: _isPayment && _alsoCash,
    );
    if (mounted) {
      toast(context, 'Entry save ho gayi');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$_title — ${widget.party.name}')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Raqam (Rs) *', hintText: 'Masalan: 5000'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'Note', hintText: 'Masalan: Gypsum sheets ka udhaar'),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month, color: kNavy),
            title: Text('Date: ${fmtDate(_date)}'),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await pickDate(context, _date);
              if (d != null) setState(() => _date = d);
            },
          ),
          if (_isPayment)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('CashBook me bhi darj karo'),
              subtitle: const Text('Payment cash me aayi/di gayi hai'),
              value: _alsoCash,
              onChanged: (v) => setState(() => _alsoCash = v),
            ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Karo'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// CashBook
// ===========================================================================

class CashbookScreen extends StatelessWidget {
  const CashbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final entries = [...store.cashbook]
        ..sort((a, b) => b.date.compareTo(a.date));

      // Din ke hisaab se groups + closing balance
      final byDay = <String, List<CashEntry>>{};
      for (final e in entries) {
        final key = fmtDate(e.date);
        byDay.putIfAbsent(key, () => []).add(e);
      }

      return Scaffold(
        appBar: AppBar(title: const Text('CashBook')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => push(context, const CashEntryFormScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Cash Entry'),
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 84),
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: kNavy, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cash Balance',
                      style: TextStyle(color: Colors.white70)),
                  Text(rs(store.cashBalance()),
                      style: const TextStyle(
                          color: kAmber,
                          fontSize: 21,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Abhi koi cash entry nahi hai.'),
              ),
            ...byDay.entries.map((day) {
              final dayEntries = day.value;
              double inSum = 0, outSum = 0;
              for (final e in dayEntries) {
                if (e.isIn) {
                  inSum += e.amount;
                } else {
                  outSum += e.amount;
                }
              }
              final d0 = dayEntries.first.date;
              final endOfDay =
                  DateTime(d0.year, d0.month, d0.day, 23, 59, 59);
              final closing = store.cashBalance(upto: endOfDay);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(day.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 13.5)),
                        Text(
                          'In ${rs(inSum)} · Out ${rs(outSum)} · Closing ${rs(closing)}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  ...dayEntries.map((e) => Card(
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            e.isIn
                                ? Icons.arrow_circle_down
                                : Icons.arrow_circle_up,
                            color: e.isIn ? kGreen : kRed,
                          ),
                          title: Text(e.note.isEmpty
                              ? (e.isIn ? 'Paisa Aaya' : 'Paisa Gaya')
                              : e.note),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${e.isIn ? '+' : '-'}${rs(e.amount)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: e.isIn ? kGreen : kRed),
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                onPressed: () => store.deleteCashEntry(e.id),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              );
            }),
          ],
        ),
      );
    });
  }
}

class CashEntryFormScreen extends StatefulWidget {
  const CashEntryFormScreen({super.key});

  @override
  State<CashEntryFormScreen> createState() => _CashEntryFormScreenState();
}

class _CashEntryFormScreenState extends State<CashEntryFormScreen> {
  bool _isIn = true;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) {
      toast(context, 'Sahi raqam likho');
      return;
    }
    await store.addCashEntry(CashEntry(
      id: newId(),
      isIn: _isIn,
      amount: amt,
      note: _note.text.trim(),
      date: _date,
    ));
    if (mounted) {
      toast(context, 'Cash entry save ho gayi');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nayi Cash Entry')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                  value: true,
                  label: Text('Paisa Aaya (IN)'),
                  icon: Icon(Icons.arrow_circle_down)),
              ButtonSegment(
                  value: false,
                  label: Text('Paisa Gaya (OUT)'),
                  icon: Icon(Icons.arrow_circle_up)),
            ],
            selected: {_isIn},
            onSelectionChanged: (s) => setState(() => _isIn = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Raqam (Rs) *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'Note', hintText: 'Masalan: Ahmed Raza se advance'),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month, color: kNavy),
            title: Text('Date: ${fmtDate(_date)}'),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await pickDate(context, _date);
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Karo'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Expenses (Kharcha)
// ===========================================================================

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final list = [...store.expenses]
        ..sort((a, b) => b.date.compareTo(a.date));
      final byCat = <String, double>{};
      double total = 0;
      for (final e in store.expenses) {
        byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
        total += e.amount;
      }
      final cats = byCat.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Scaffold(
        appBar: AppBar(
          title: const Text('Kharcha — Expenses'),
          actions: [
            IconButton(
              icon: const Icon(Icons.category_outlined),
              tooltip: 'Categories',
              onPressed: () => push(context, const CategoriesScreen()),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => push(context, const ExpenseFormScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Naya Kharcha'),
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 84),
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: kNavy, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kul Kharcha',
                      style: TextStyle(color: Colors.white70)),
                  Text(rs(total),
                      style: const TextStyle(
                          color: kAmber,
                          fontSize: 21,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            if (cats.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 10, 14, 2),
                child: Text('Category ke hisaab se',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              ...cats.map((c) => Card(
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.category, color: kNavy),
                      title: Text(c.key),
                      trailing: Text(rs(c.value),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  )),
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 2),
                child: Text('Saare kharchay',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ],
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Abhi koi kharcha nahi hai.'),
              ),
            ...list.map((e) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(
                        '${e.category}${e.note.isNotEmpty ? ' — ${e.note}' : ''}'),
                    subtitle: Text(fmtDate(e.date)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(rs(e.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, color: kRed)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => store.deleteExpense(e.id),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      );
    });
  }
}

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  String? _category;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) {
      toast(context, 'Sahi raqam likho');
      return;
    }
    await store.addExpense(Expense(
      id: newId(),
      category: _category ?? store.expenseCategories.first,
      amount: amt,
      note: _note.text.trim(),
      date: _date,
    ));
    if (mounted) {
      toast(context, 'Kharcha save ho gaya');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = store.expenseCategories;
    _category ??= cats.isNotEmpty ? cats.first : 'Deegar';
    return Scaffold(
      appBar: AppBar(title: const Text('Naya Kharcha')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: cats
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Raqam (Rs) *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
                labelText: 'Note', hintText: 'Masalan: Site tak petrol'),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month, color: kNavy),
            title: Text('Date: ${fmtDate(_date)}'),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await pickDate(context, _date);
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Karo'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Expense categories manage
// ===========================================================================

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _newCat = TextEditingController();

  @override
  void dispose() {
    _newCat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final cats = store.expenseCategories;
      return Scaffold(
        appBar: AppBar(title: const Text('Kharcha Categories')),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCat,
                    decoration:
                        const InputDecoration(labelText: 'Nayi category'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final v = _newCat.text.trim();
                    if (v.isEmpty || cats.contains(v)) return;
                    await store.setCategories([...cats, v]);
                    _newCat.clear();
                    setState(() {});
                  },
                  child: const Text('Jodo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...cats.map((c) => Card(
                  child: ListTile(
                    dense: true,
                    title: Text(c),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 19),
                      onPressed: cats.length <= 1
                          ? null
                          : () async {
                              await store.setCategories(
                                  cats.where((x) => x != c).toList());
                              setState(() {});
                            },
                    ),
                  ),
                )),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Note: category delete karne se puranay kharchay nahi udtay, sirf list se naam hat jata hai.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ===========================================================================
// Stock / Inventory
// ===========================================================================

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _q = '';

  String unitLabel(String u) {
    switch (u) {
      case 'sheet':
        return 'Sheet';
      case 'bag':
        return 'Bag';
      case 'ft':
        return 'Ft';
      default:
        return 'Piece';
    }
  }

  Future<void> _scanSearch() async {
    final code = await pushForResult<String>(context, const ScannerScreen());
    if (code == null || !mounted) return;
    final item = store.itemByBarcode(code);
    if (item != null) {
      push(context, ItemFormScreen(existing: item));
    } else {
      setState(() => _q = code);
      toast(context, 'Is barcode ka item nahi mila: $code');
    }
  }

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final list = store.items.where((i) {
        final q = _q.toLowerCase();
        return q.isEmpty ||
            i.name.toLowerCase().contains(q) ||
            i.barcode.toLowerCase().contains(q);
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      double stockValue = 0;
      for (final i in store.items) {
        stockValue += i.stockQty * i.purchaseRate;
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('Stock — Ceiling Material'),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Barcode scan karo',
              onPressed: _scanSearch,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => push(context, const ItemFormScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Naya Item'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Item ya barcode dhundo…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Stock ki kul value (khareed rate par): ${rs(stockValue)}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('Koi item nahi. "Naya Item" se jodo.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 84),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final item = list[i];
                        final out = item.stockQty <= 0;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: out ? kRed : kNavy,
                              child: Icon(
                                out
                                    ? Icons.remove_shopping_cart
                                    : Icons.inventory_2,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                            title: Text(item.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                'Stock: ${qtyFmt(item.stockQty)} ${unitLabel(item.unit)} · Sale ${rs(item.saleRate)}'
                                '${item.barcode.isNotEmpty ? '\nBarcode: ${item.barcode}' : ''}'),
                            trailing: out
                                ? const Text('KHATAM',
                                    style: TextStyle(
                                        color: kRed,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11))
                                : null,
                            onTap: () => push(
                                context, ItemFormScreen(existing: item)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }
}

// ===========================================================================
// Item banana / edit karna (stock adjust bhi yahin se)
// ===========================================================================

class ItemFormScreen extends StatefulWidget {
  final Item? existing;
  const ItemFormScreen({super.key, this.existing});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _qty = TextEditingController(
      text: widget.existing == null
          ? ''
          : qtyFmt(widget.existing!.stockQty));
  late final TextEditingController _purchase = TextEditingController(
      text: widget.existing == null || widget.existing!.purchaseRate == 0
          ? ''
          : qtyFmt(widget.existing!.purchaseRate));
  late final TextEditingController _sale = TextEditingController(
      text: widget.existing == null || widget.existing!.saleRate == 0
          ? ''
          : qtyFmt(widget.existing!.saleRate));
  late final TextEditingController _barcode =
      TextEditingController(text: widget.existing?.barcode ?? '');
  late String _unit = widget.existing?.unit ?? 'sheet';

  static const _units = ['sheet', 'bag', 'piece', 'ft'];

  String _unitLabel(String u) {
    switch (u) {
      case 'sheet':
        return 'Sheet';
      case 'bag':
        return 'Bag';
      case 'ft':
        return 'Ft';
      default:
        return 'Piece';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _purchase.dispose();
    _sale.dispose();
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await pushForResult<String>(context, const ScannerScreen());
    if (code != null) setState(() => _barcode.text = code);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Item ka naam likho');
      return;
    }
    final qty = double.tryParse(_qty.text.trim()) ?? 0;
    final pr = double.tryParse(_purchase.text.trim()) ?? 0;
    final sr = double.tryParse(_sale.text.trim()) ?? 0;
    if (widget.existing == null) {
      await store.addItem(Item(
        id: newId(),
        name: name,
        unit: _unit,
        stockQty: qty,
        purchaseRate: pr,
        saleRate: sr,
        barcode: _barcode.text.trim(),
      ));
      if (mounted) toast(context, 'Item jod diya gaya');
    } else {
      final it = widget.existing!;
      it.name = name;
      it.unit = _unit;
      it.stockQty = qty;
      it.purchaseRate = pr;
      it.saleRate = sr;
      it.barcode = _barcode.text.trim();
      await store.updateItem(it);
      if (mounted) toast(context, 'Item update ho gaya');
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Item delete karein?'),
        content: Text('${widget.existing!.name} stock se hat jayega.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nahi')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) {
      await store.deleteItem(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Naya Item' : 'Item Edit Karo'),
        actions: [
          if (widget.existing != null)
            IconButton(
                icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Item ka naam *',
                hintText: 'Masalan: Gypsum Sheet 4x8'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: _units
                .map((u) =>
                    DropdownMenuItem(value: u, child: Text(_unitLabel(u))))
                .toList(),
            onChanged: (v) => setState(() => _unit = v ?? _unit),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Stock Quantity',
                      hintText: 'Kitna stock hai'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _purchase,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Khareed Rate (Rs)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sale,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Sale Rate (Rs)'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcode,
                  decoration: const InputDecoration(
                      labelText: 'Barcode', hintText: 'Barcode number'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _scanBarcode,
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Barcode scan karo',
                style: IconButton.styleFrom(
                    backgroundColor: kNavy, foregroundColor: kAmber),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Karo'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Barcode scanner — mobile_scanner
// ===========================================================================

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code != null && code.isNotEmpty) {
      _done = true;
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Scan Karo')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kNavy.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Barcode ko camera ke saamne lao — khud scan ho jayega',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Bills — list
// ===========================================================================

class BillsListScreen extends StatelessWidget {
  const BillsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final bills = [...store.bills]
        ..sort((a, b) => b.date.compareTo(a.date));
      return Scaffold(
        appBar: AppBar(title: const Text('Saare Bills')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => push(context, const BillFormScreen()),
          icon: const Icon(Icons.add),
          label: const Text('Naya Bill'),
        ),
        body: bills.isEmpty
            ? const Center(child: Text('Abhi koi bill nahi bana.'))
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 84),
                itemCount: bills.length,
                itemBuilder: (context, i) {
                  final b = bills[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kNavy,
                        child: Text('${b.number}',
                            style: const TextStyle(
                                color: kAmber, fontWeight: FontWeight.w800)),
                      ),
                      title: Text('${b.partyName} — ${rs(b.total)}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          '${fmtDate(b.date)} · Baqaya: ${rs(b.baqaya)}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          push(context, BillDetailScreen(billId: b.id)),
                    ),
                  );
                },
              ),
      );
    });
  }
}

// ===========================================================================
// Bill banana — sq ft measurement + material
// ===========================================================================

class _MeasureEdit {
  final label = TextEditingController();
  final len = TextEditingController();
  final wid = TextEditingController();
  final rate = TextEditingController();

  double get sqft =>
      (double.tryParse(len.text) ?? 0) * (double.tryParse(wid.text) ?? 0);
  double get amount => sqft * (double.tryParse(rate.text) ?? 0);

  void dispose() {
    label.dispose();
    len.dispose();
    wid.dispose();
    rate.dispose();
  }
}

class _MaterialEdit {
  final Item item;
  final qty = TextEditingController(text: '1');
  late final rate = TextEditingController(text: qtyFmt(item.saleRate));

  _MaterialEdit(this.item);

  double get amount =>
      (double.tryParse(qty.text) ?? 0) * (double.tryParse(rate.text) ?? 0);

  void dispose() {
    qty.dispose();
    rate.dispose();
  }
}

class BillFormScreen extends StatefulWidget {
  const BillFormScreen({super.key});

  @override
  State<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  Party? _party;
  final _measures = <_MeasureEdit>[_MeasureEdit()];
  final _materials = <_MaterialEdit>[];
  final _extra = TextEditingController();
  final _extraNote = TextEditingController();
  final _advance = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  double get _measureTotal =>
      _measures.fold(0.0, (s, m) => s + m.amount);
  double get _materialTotal =>
      _materials.fold(0.0, (s, m) => s + m.amount);
  double get _extraAmt => double.tryParse(_extra.text) ?? 0;
  double get _total => _measureTotal + _materialTotal + _extraAmt;
  double get _advAmt => double.tryParse(_advance.text) ?? 0;
  double get _baqaya => _total - _advAmt;

  @override
  void dispose() {
    for (final m in _measures) {
      m.dispose();
    }
    for (final m in _materials) {
      m.dispose();
    }
    _extra.dispose();
    _extraNote.dispose();
    _advance.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickMaterial() async {
    if (store.items.isEmpty) {
      toast(context, 'Pehle Stock me item jodo');
      return;
    }
    final item = await showModalBottomSheet<Item>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text('Material chuno',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            ...store.items.map((i) => ListTile(
                  title: Text(i.name),
                  subtitle: Text(
                      'Stock: ${qtyFmt(i.stockQty)} ${i.unit} · Sale ${rs(i.saleRate)}'),
                  onTap: () => Navigator.pop(ctx, i),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (item != null) {
      setState(() => _materials.add(_MaterialEdit(item)));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_party == null) {
      toast(context, 'Pehle customer chuno');
      return;
    }
    if (_total <= 0) {
      toast(context, 'Bill ka total zero hai — measurement ya material jodo');
      return;
    }
    setState(() => _saving = true);
    final measureLines = _measures
        .where((m) => m.sqft > 0)
        .map((m) => MeasureLine(
              label: m.label.text.trim().isEmpty
                  ? 'Ceiling'
                  : m.label.text.trim(),
              lengthFt: double.tryParse(m.len.text) ?? 0,
              widthFt: double.tryParse(m.wid.text) ?? 0,
              ratePerSqft: double.tryParse(m.rate.text) ?? 0,
            ))
        .toList();
    final materialLines = _materials
        .where((m) => (double.tryParse(m.qty.text) ?? 0) > 0)
        .map((m) => MaterialLine(
              itemId: m.item.id,
              itemName: m.item.name,
              unit: m.item.unit,
              qty: double.tryParse(m.qty.text) ?? 0,
              rate: double.tryParse(m.rate.text) ?? 0,
            ))
        .toList();
    final bill = await store.createBill(
      party: _party!,
      measureLines: measureLines,
      materialLines: materialLines,
      extraCharges: _extraAmt,
      extraNote: _extraNote.text.trim(),
      advance: _advAmt,
      note: _note.text.trim(),
      date: _date,
    );
    if (mounted) {
      toast(context, 'Bill No ${bill.number} ban gaya');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bill.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final parties = store.parties;
    return Scaffold(
      appBar: AppBar(title: const Text('Naya Bill')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (parties.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: kRed),
                title: const Text('Pehle ek party (customer) jodo'),
                trailing: TextButton(
                  onPressed: () => push(context, const PartyFormScreen()),
                  child: const Text('Party Jodo'),
                ),
              ),
            )
          else
            DropdownButtonFormField<Party>(
              initialValue: _party,
              decoration: const InputDecoration(labelText: 'Customer *'),
              items: parties
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(
                            '${p.name}${p.siteName.isNotEmpty ? ' (${p.siteName})' : ''}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _party = v),
            ),
          const SizedBox(height: 6),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month, color: kNavy),
            title: Text('Date: ${fmtDate(_date)}'),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await pickDate(context, _date);
              if (d != null) setState(() => _date = d);
            },
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Measurement (Sq Ft)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _measures.add(_MeasureEdit())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Line Jodo'),
              ),
            ],
          ),
          ..._measures.asMap().entries.map((entry) {
            final idx = entry.key;
            final m = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: m.label,
                            decoration: InputDecoration(
                                labelText: 'Jagah / Kamra ${idx + 1}',
                                hintText: 'Masalan: Drawing Room'),
                          ),
                        ),
                        if (_measures.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: kRed),
                            onPressed: () => setState(() {
                              _measures[idx].dispose();
                              _measures.removeAt(idx);
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: m.len,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Lambai (ft)'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: m.wid,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Chorai (ft)'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: m.rate,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Rate / Sq Ft'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '= ${qtyFmt(m.sqft)} sq ft · ${rs(m.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Material (Stock se)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              TextButton.icon(
                onPressed: _pickMaterial,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Item Jodo'),
              ),
            ],
          ),
          if (_materials.isEmpty)
            const Text('Koi material nahi joda.',
                style: TextStyle(color: Colors.black54, fontSize: 12.5)),
          ..._materials.asMap().entries.map((entry) {
            final idx = entry.key;
            final m = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(m.item.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Text('Stock: ${qtyFmt(m.item.stockQty)} ${m.item.unit}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black54)),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline,
                              color: kRed),
                          onPressed: () => setState(() {
                            _materials[idx].dispose();
                            _materials.removeAt(idx);
                          }),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: m.qty,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Quantity'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: m.rate,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Rate (Rs)'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(rs(m.amount),
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _extra,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Extra Charges (Rs)'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _extraNote,
                  decoration:
                      const InputDecoration(labelText: 'Extra kis cheez ka?'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _advance,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Advance Mila (Rs)',
                hintText: 'Customer ne abhi kitne diye'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: kNavy,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _totalRow('Measurement Total', rs(_measureTotal), false),
                _totalRow('Material Total', rs(_materialTotal), false),
                if (_extraAmt > 0)
                  _totalRow('Extra', rs(_extraAmt), false),
                const Divider(color: Colors.white24),
                _totalRow('Kul Total', rs(_total), true),
                _totalRow('Advance', '- ${rs(_advAmt)}', false),
                _totalRow('Baqaya', rs(_baqaya), true, amber: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Save ho raha hai…' : 'Bill Save Karo'),
            style: ElevatedButton.styleFrom(
                backgroundColor: kAmber, foregroundColor: kNavy),
          ),
          const SizedBox(height: 6),
          const Text(
            'Bill save honay par: stock kam ho jayega, customer ke khate me udhaar darj hoga aur advance cash me jama ho jayega.',
            style: TextStyle(fontSize: 11.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String k, String v, bool bold, {bool amber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(v,
              style: TextStyle(
                  color: amber ? kAmber : Colors.white,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 16 : 14)),
        ],
      ),
    );
  }
}

// ===========================================================================
// Bill detail
// ===========================================================================

class BillDetailScreen extends StatelessWidget {
  final String billId;
  const BillDetailScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final bill = store.bills.where((b) => b.id == billId).firstOrNull;
      if (bill == null) {
        return const Scaffold(body: Center(child: Text('Bill nahi mila')));
      }
      final party = store.partyById(bill.partyId);
      return Scaffold(
        appBar: AppBar(
          title: Text('Bill No ${bill.number}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Bill delete',
              onPressed: () => _confirmDelete(context, bill),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill.partyName,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(
                        '${fmtDate(bill.date)}${bill.note.isNotEmpty ? ' · ${bill.note}' : ''}',
                        style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ),
            if (bill.measureLines.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 10, 14, 2),
                child: Text('Measurement (Ceiling)',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              ...bill.measureLines.map((l) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text(l.label),
                      subtitle: Text(
                          '${qtyFmt(l.lengthFt)} x ${qtyFmt(l.widthFt)} ft = ${qtyFmt(l.sqft)} sq ft @ ${rs(l.ratePerSqft)}'),
                      trailing: Text(rs(l.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  )),
            ],
            if (bill.materialLines.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 10, 14, 2),
                child: Text('Material',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              ...bill.materialLines.map((l) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text(l.itemName),
                      subtitle: Text(
                          '${qtyFmt(l.qty)} ${l.unit} @ ${rs(l.rate)}'),
                      trailing: Text(rs(l.amount),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  )),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    if (bill.extraCharges > 0)
                      _row('Extra${bill.extraNote.isNotEmpty ? ' (${bill.extraNote})' : ''}',
                          rs(bill.extraCharges), false),
                    _row('Kul Total', rs(bill.total), true),
                    _row('Advance Mila', '- ${rs(bill.advance)}', false),
                    const Divider(),
                    _row('Baqaya', rs(bill.baqaya), true),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: party == null
                          ? null
                          : () => openWhatsApp(context, party.phone,
                              billWhatsAppText(store, bill)),
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('WhatsApp Bill'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: kAmber, foregroundColor: kNavy),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => shareBillPdf(store, bill),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Bill PDF'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _row(String k, String v, bool bold) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(v,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 15.5 : 14)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Bill bill) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bill delete karein?'),
        content: const Text(
            'Bill delete honay se stock wapas aa jayega aur is bill ki khata entries bhi hat jayengi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nahi')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: kRed))),
        ],
      ),
    );
    if (ok == true) {
      await store.deleteBill(bill.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ===========================================================================
// Reports
// ===========================================================================

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final weekStart = dayStart.subtract(Duration(days: now.weekday - 1));
      final monthStart = DateTime(now.year, now.month, 1);

      final today =
          store.totalsFor(dayStart, dayStart.add(const Duration(days: 1)));
      final week =
          store.totalsFor(weekStart, dayStart.add(const Duration(days: 1)));
      final month =
          store.totalsFor(monthStart, dayStart.add(const Duration(days: 1)));

      final baqayaList = store.parties
          .map((p) => (p, store.partyBalance(p.id)))
          .where((x) => x.$2 != 0)
          .toList()
        ..sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));

      return Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => push(context, const SettingsScreen()),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            _PeriodCard(title: 'Aaj', t: today),
            _PeriodCard(title: 'Is Hafta', t: week),
            _PeriodCard(title: 'Is Mahina', t: month),
            Card(
              child: ListTile(
                leading: const Icon(Icons.list_alt, color: kNavy),
                title: const Text('Saare Bills dekho'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const BillsListScreen()),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.swap_horiz, color: kNavy),
                title: const Text('CashBook dekho'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const CashbookScreen()),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 2),
              child: Text('Baqaya List (kis se lena / kis ko dena)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            if (baqayaList.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Kisi ka baqaya nahi — sab clear hai.'),
              ),
            ...baqayaList.map((x) {
              final p = x.$1;
              final bal = x.$2;
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle:
                      Text(p.siteName.isNotEmpty ? 'Site: ${p.siteName}' : (p.isSupplier ? 'Supplier' : 'Customer')),
                  trailing: Text(
                    '${bal > 0 ? 'Lena' : 'Dena'}: ${rs(bal.abs())}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: bal > 0 ? kRed : kGreen),
                  ),
                  onTap: () =>
                      push(context, PartyDetailScreen(partyId: p.id)),
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}

class _PeriodCard extends StatelessWidget {
  final String title;
  final ({double cashIn, double cashOut, double kharcha}) t;
  const _PeriodCard({required this.title, required this.t});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _mini('Cash In', rs(t.cashIn), kGreen)),
                Expanded(child: _mini('Cash Out', rs(t.cashOut), kRed)),
                Expanded(child: _mini('Kharcha', rs(t.kharcha), kRed)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String k, String v, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        Text(v,
            style: TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w800, color: c)),
      ],
    );
  }
}

// ===========================================================================
// Settings — business name, categories, backup / restore
// ===========================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _biz =
      TextEditingController(text: store.businessName);
  final _importCtrl = TextEditingController();

  @override
  void dispose() {
    _biz.dispose();
    _importCtrl.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final data = store.exportJson();
    await Clipboard.setData(ClipboardData(text: data));
    if (mounted) {
      toast(context,
          'Backup copy ho gaya — isay kahin safe jagah (WhatsApp/Notes) save kar lo');
    }
  }

  Future<void> _import() async {
    final raw = _importCtrl.text.trim();
    if (raw.isEmpty) {
      toast(context, 'Pehle backup wali text yahan paste karo');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Data restore karein?'),
        content: const Text(
            'Maujooda saara data is backup se badal jayega. Yaqeen hai?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Nahi')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore Karo')),
        ],
      ),
    );
    if (ok != true) return;
    final done = await store.importJson(raw);
    if (mounted) {
      toast(context,
          done ? 'Data restore ho gaya' : 'Ye backup text sahi nahi hai');
      if (done) _importCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            const Text('Business ka naam',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Ye naam bill aur PDF par ayega.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _biz,
                    decoration:
                        const InputDecoration(labelText: 'Business Name'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await store.setBusinessName(_biz.text);
                    if (context.mounted) toast(context, 'Naam save ho gaya');
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
            const Divider(height: 30),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.category_outlined, color: kNavy),
                title: const Text('Kharcha Categories'),
                subtitle: const Text('Category jodo ya hatao'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, const CategoriesScreen()),
              ),
            ),
            const Divider(height: 30),
            const Text('Backup (Data mehfooz rakho)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Backup = poora data ek text ki shakal me. Copy karke kahin safe rakh lo. Phone badlo ya app dobara lagao to yahi text paste karke saara data wapas aa jayega.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.copy),
              label: const Text('Backup Copy Karo'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: kAmber, foregroundColor: kNavy),
            ),
            const SizedBox(height: 18),
            const Text('Restore (Backup wapas lao)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _importCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Backup text yahan paste karo',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _import,
              icon: const Icon(Icons.restore),
              label: const Text('Restore Karo'),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text('Khata Book — koi subscription nahi, data aap ke phone par',
                  style: TextStyle(fontSize: 11.5, color: Colors.black45)),
            ),
          ],
        ),
      );
    });
  }
}
