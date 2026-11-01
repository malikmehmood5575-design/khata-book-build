import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'store.dart';
import 'helpers.dart';
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
// Main shell — bottom nav: Home, Clients, [+], Settings (v1.3 SIMPLE)
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
    SettingsScreen(),
  ];
  // nav index mapping: 0 Home, 1 Clients, 2 (+) action, 3 Settings
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
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clients'),
            NavigationDestination(
              icon: Icon(Icons.add_circle, color: kAmber, size: 38),
              label: 'Naya',
            ),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
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
            leading: const Icon(Icons.payments, color: kGreen),
            title: const Text('Payment IN'),
            subtitle: const Text('Client se paisa aaya'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const PaymentPartyPickerScreen(type: 'paymentMili'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.money, color: kRed),
            title: const Text('Payment OUT'),
            subtitle: const Text('Client ko paisa diya'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const PaymentPartyPickerScreen(type: 'paymentDi'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add, color: kNavy),
            title: const Text('Naya Client'),
            subtitle: const Text('Customer ya supplier jodo'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const PartyFormScreen());
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ===========================================================================
// Home — sirf payments ka khulasa (v1.3 SIMPLE)
// ===========================================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      double inToday = 0, outToday = 0;
      for (final e in store.ledger) {
        if (e.date.isBefore(dayStart) || !e.date.isBefore(dayEnd)) continue;
        if (e.type == 'paymentMili') inToday += e.amount;
        if (e.type == 'paymentDi') outToday += e.amount;
      }
      final recent = store.ledger
          .where((e) => e.type == 'paymentMili' || e.type == 'paymentDi')
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      return Scaffold(
        appBar: AppBar(
          title: Text(store.businessName),
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          children: [
            // Kul lena hai hero card (navy)
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
                  const Text('Kul Lena hai',
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
                          const Text('Aaj Payment IN',
                              style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                          Text(rs(inToday),
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
                          const Text('Aaj Payment OUT',
                              style: TextStyle(fontSize: 11.5, color: Colors.black54)),
                          Text(rs(outToday),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
              child: Row(
                children: [
                  Expanded(
                    child: _BigPayButton(
                      color: kGreen,
                      icon: Icons.arrow_downward,
                      title: 'Payment IN',
                      subtitle: 'Paisa Aaya',
                      onTap: () => push(context,
                          const PaymentPartyPickerScreen(type: 'paymentMili')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BigPayButton(
                      color: kRed,
                      icon: Icons.arrow_upward,
                      title: 'Payment OUT',
                      subtitle: 'Paisa Gaya',
                      onTap: () => push(context,
                          const PaymentPartyPickerScreen(type: 'paymentDi')),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 2),
              child: Text('Haal ki payments',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                    'Abhi koi payment nahi. Payment IN / OUT button se pehli entry karo.'),
              ),
            ...recent.take(8).map((e) {
              final p = store.partyById(e.partyId);
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text('${p?.name ?? ''} — ${e.typeLabel}'),
                  subtitle: Text(
                      '${fmtDate(e.date)}${e.note.isNotEmpty ? ' · ${e.note}' : ''}'),
                  trailing: Text(
                    '${e.signed >= 0 ? '+' : '-'}${rs(e.amount)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: e.signed >= 0 ? kGreen : kRed),
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }
}

class _BigPayButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _BigPayButton({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            Text(subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Payment ke liye client chunna
// ===========================================================================

class PaymentPartyPickerScreen extends StatelessWidget {
  final String type; // paymentMili | paymentDi
  const PaymentPartyPickerScreen({super.key, required this.type});

  bool get _isIn => type == 'paymentMili';

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final list = [...store.parties]
        ..sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Scaffold(
        appBar: AppBar(
          title: Text(_isIn
              ? 'Payment IN — Client Chuno'
              : 'Payment OUT — Client Chuno'),
        ),
        body: list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Abhi koi client nahi hai.\nPehle client jodo, phir payment likho.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () =>
                            push(context, const PartyFormScreen()),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Naya Client'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final p = list[i];
                  final bal = store.partyBalance(p.id);
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kNavy,
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                              color: kAmber, fontWeight: FontWeight.w800),
                        ),
                      ),
                      title: Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text([
                        if (p.siteName.isNotEmpty) 'Site: ${p.siteName}',
                        p.isSupplier ? 'Supplier' : 'Customer',
                      ].join(' · ')),
                      trailing: bal == 0
                          ? const Text('Clear',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, color: kGreen))
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
                                        fontSize: 10, color: Colors.black54)),
                              ],
                            ),
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              LedgerEntryFormScreen(party: p, type: type),
                        ),
                      ),
                    ),
                  );
                },
              ),
      );
    });
  }
}


// ===========================================================================
// Clients — parties ki list
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
        appBar: AppBar(title: const Text('Clients')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => push(context, const PartyFormScreen()),
          icon: const Icon(Icons.person_add),
          label: const Text('Naya Client'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Client, site ya number dhundo…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('Koi client nahi. "Naya Client" se jodo.'))
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
// Party detail — pura khata (sirf payments)
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
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                      onPressed: () => push(
                          context,
                          LedgerEntryFormScreen(
                              party: party, type: 'paymentMili')),
                      icon: const Icon(Icons.payments, size: 19),
                      label: const Text('Payment IN'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: kRed),
                      onPressed: () => push(
                          context,
                          LedgerEntryFormScreen(
                              party: party, type: 'paymentDi')),
                      icon: const Icon(Icons.money, size: 19),
                      label: const Text('Payment OUT'),
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
                ),
              );
            }),
          ],
        ),
      );
    });
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


// ===========================================================================
// Khata entry form (payment in / out)
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
      case 'kharcha':
        return 'Kharcha';
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
// Settings — business name, backup / restore
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
              'Ye naam Home screen par dikhega.',
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
