import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Entry ki woh label jo har jagah dikhti hai (Home activity, customer
/// history). Kharcha par category bhi sath: Material / Karigar / Custom
/// (Custom matlab kharchaLabel me user ka apna likha naam; purane
/// 'Doosra' wale labels bhi waisay hi dikhte rehte hain).
String entryLabel(LedgerEntry e) {
  switch (e.type) {
    case 'advance':
      return 'Advance';
    case 'kharcha':
      if (e.karigarId != null) {
        final k = store.karigarById(e.karigarId!);
        return 'Kharcha — Karigar: ${k?.name ?? 'Karigar'}';
      }
      final lbl = e.kharchaLabel;
      if (lbl != null && lbl.isNotEmpty) return 'Kharcha — $lbl';
      return 'Kharcha';
    default:
      return e.typeLabel;
  }
}

/// Edit form me raqam field ki shuruati value — 10000.0 ki jagah '10000'
/// taake field me saaf number aye aur parse bhi ho jaye.
String amtFieldText(double v) =>
    v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

/// Customer ke baqi paisay wala chip: sabz = paisa hamaray paas baqi hai,
/// laal = advance khatam, aur paisa lena hai.
Widget baqiChip(double baqi) {
  final neg = baqi < 0;
  final color = neg ? kRed : kGreen;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      neg ? 'Aur lena hai ${rs(-baqi)}' : 'Baqi ${rs(baqi)}',
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: color,
      ),
    ),
  );
}

// ===========================================================================
// Main shell — bottom nav: Home, Customers, [+], Karigar, Settings (v1.4)
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
    KarigarListScreen(),
    SettingsScreen(),
  ];
  // nav index mapping: 0 Home, 1 Customers, 2 (+) action, 3 Karigar, 4 Settings
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
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Customers',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle, color: kAmber, size: 38),
              label: 'Naya',
            ),
            NavigationDestination(
              icon: Icon(Icons.engineering_outlined),
              selectedIcon: Icon(Icons.engineering),
              label: 'Karigar',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
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
              child: Text(
                'Naya kya karna hai?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.payments, color: kGreen),
            title: const Text('Advance Liya'),
            subtitle: const Text('Customer se paisa aaya'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const EntryPartyPickerScreen(kind: 'advance'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.money_off, color: kRed),
            title: const Text('Kharcha Karo'),
            subtitle: const Text('Customer ke advance mein se kharcha'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const KharchaFormScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.engineering, color: kNavy),
            title: const Text('Karigar ko Payment'),
            subtitle: const Text('Karigar ko paisa do (kharcha banega)'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const KarigarPickerScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add, color: kNavy),
            title: const Text('Naya Customer'),
            subtitle: const Text('Customer ya supplier jodo'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const PartyFormScreen());
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt, color: kNavy),
            title: const Text('Naya Karigar'),
            subtitle: const Text('Worker / mazdoor jodo'),
            onTap: () {
              Navigator.pop(ctx);
              push(context, const KarigarFormScreen());
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ===========================================================================
// Home — advance model ka khulasa (v1.4)
// ===========================================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      double advToday = 0, khToday = 0;
      for (final e in store.ledger) {
        if (e.date.isBefore(dayStart) || !e.date.isBefore(dayEnd)) continue;
        if (e.type == 'advance' || e.type == 'paymentMili') {
          advToday += e.amount;
        }
        if (e.type == 'kharcha') khToday += e.amount;
      }
      final recent =
          store.ledger
              .where(
                (e) =>
                    e.type == 'advance' ||
                    e.type == 'kharcha' ||
                    e.type == 'paymentMili' ||
                    e.type == 'paymentDi',
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

      return Scaffold(
        appBar: AppBar(title: Text(store.businessName)),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          children: [
            // Baqi Paisa hero card (navy)
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
                  const Text(
                    'Baqi Paisa — sab customers ka',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    rs(store.totalBaqi),
                    style: const TextStyle(
                      color: kAmber,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Kul Advance: ${rs(store.totalAdvance)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      Text(
                        'Kul Kharcha: ${rs(store.totalKharcha)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cash (galla): ${rs(store.cashBalance())}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
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
                          const Text(
                            'Aaj Advance',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            rs(advToday),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: kGreen,
                            ),
                          ),
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
                          const Text(
                            'Aaj Kharcha',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black54,
                            ),
                          ),
                          Text(
                            rs(khToday),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: kRed,
                            ),
                          ),
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
                      title: 'Advance Liya',
                      subtitle: 'Customer se paisa aaya',
                      onTap: () => push(
                        context,
                        const EntryPartyPickerScreen(kind: 'advance'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BigPayButton(
                      color: kRed,
                      icon: Icons.arrow_upward,
                      title: 'Kharcha Karo',
                      subtitle: 'Paisa kharch hua',
                      onTap: () => push(context, const KharchaFormScreen()),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => printTotalKhata(store),
                  icon: const Icon(Icons.print, size: 19),
                  label: const Text('Total Khata Print Karo'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAmber,
                    foregroundColor: kNavy,
                  ),
                  onPressed: () async {
                    try {
                      await shareTotalKhata(store);
                    } catch (_) {
                      if (context.mounted) {
                        toast(context, 'PDF share nahi ho saka');
                      }
                    }
                  },
                  icon: const Icon(Icons.share, size: 19),
                  label: const Text('Total Khata PDF Share Karo'),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 2),
              child: Text(
                'Haal ki activity',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Abhi koi activity nahi. Advance Liya / Kharcha Karo button se pehli entry karo.',
                ),
              ),
            ...recent.take(10).map((e) {
              final p = store.partyById(e.partyId);
              final pos = e.baqiEffect >= 0;
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text('${p?.name ?? ''} — ${entryLabel(e)}'),
                  subtitle: Text(
                    '${fmtDate(e.date)}${e.note.isNotEmpty ? ' · ${e.note}' : ''}',
                  ),
                  trailing: Text(
                    '${pos ? '+' : '-'}${rs(e.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: pos ? kGreen : kRed,
                    ),
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
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Advance / Kharcha ke liye customer chunna
// ===========================================================================

class EntryPartyPickerScreen extends StatelessWidget {
  /// 'advance' | 'kharcha' | 'karigarKharcha'
  final String kind;
  final String? karigarId;
  const EntryPartyPickerScreen({super.key, required this.kind, this.karigarId});

  String get _title {
    switch (kind) {
      case 'advance':
        return 'Advance — Customer Chuno';
      case 'karigarKharcha':
        return 'Karigar Payment — Customer Chuno';
      default:
        return 'Kharcha — Customer Chuno';
    }
  }

  void _open(BuildContext context, Party p) {
    Widget screen;
    if (kind == 'advance') {
      screen = AdvanceFormScreen(party: p);
    } else if (kind == 'karigarKharcha') {
      screen = KharchaFormScreen(
        party: p,
        initialKarigar: karigarId == null
            ? null
            : store.karigarById(karigarId!),
      );
    } else {
      screen = KharchaFormScreen(party: p);
    }
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final list = [...store.parties]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Abhi koi customer nahi hai.\nPehle customer jodo, phir entry karo.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => push(context, const PartyFormScreen()),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Naya Customer'),
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
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kNavy,
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: kAmber,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          if (p.siteName.isNotEmpty) 'Site: ${p.siteName}',
                          p.isSupplier ? 'Supplier' : 'Customer',
                        ].join(' · '),
                      ),
                      trailing: baqiChip(store.partyBaqi(p.id)),
                      onTap: () => _open(context, p),
                    ),
                  );
                },
              ),
      );
    });
  }
}

// ===========================================================================
// Karigar ko payment ke liye pehle karigar chunna
// ===========================================================================

class KarigarPickerScreen extends StatelessWidget {
  const KarigarPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final list = [...store.karigars]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Scaffold(
        appBar: AppBar(title: const Text('Karigar Chuno')),
        body: list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Abhi koi karigar nahi hai.\nPehle karigar jodo, phir payment karo.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () =>
                            push(context, const KarigarFormScreen()),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Naya Karigar'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final k = list[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kNavy,
                        child: Text(
                          k.name.isNotEmpty ? k.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: kAmber,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        k.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(k.phone.isNotEmpty ? k.phone : 'Karigar'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            rs(store.karigarTotalPaid(k.id)),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Text(
                            'Kul diya',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => EntryPartyPickerScreen(
                            kind: 'karigarKharcha',
                            karigarId: k.id,
                          ),
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
// Customers — parties ki list
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
      final list =
          store.parties.where((p) {
            final q = _q.toLowerCase();
            return q.isEmpty ||
                p.name.toLowerCase().contains(q) ||
                p.siteName.toLowerCase().contains(q) ||
                p.phone.contains(q);
          }).toList()..sort(
            (a, b) => store
                .partyBaqi(b.id)
                .abs()
                .compareTo(store.partyBaqi(a.id).abs()),
          );

      return Scaffold(
        appBar: AppBar(title: const Text('Customers')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => push(context, const PartyFormScreen()),
          icon: const Icon(Icons.person_add),
          label: const Text('Naya Customer'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Customer, site ya number dhundo…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text(
                        'Koi customer nahi. "Naya Customer" se jodo.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 84),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final p = list[i];
                        final adv = store.partyAdvanceTotal(p.id);
                        final kh = store.partyKharchaTotal(p.id);
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: kNavy,
                              child: Text(
                                p.name.isNotEmpty
                                    ? p.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: kAmber,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              [
                                [
                                  if (p.siteName.isNotEmpty)
                                    'Site: ${p.siteName}',
                                  p.isSupplier ? 'Supplier' : 'Customer',
                                ].join(' · '),
                                'Advance ${rs(adv)} · Kharcha ${rs(kh)}',
                              ].join('\n'),
                            ),
                            trailing: baqiChip(store.partyBaqi(p.id)),
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
// Party (customer) banana / edit karna
// ===========================================================================

class PartyFormScreen extends StatefulWidget {
  final Party? existing;
  const PartyFormScreen({super.key, this.existing});

  @override
  State<PartyFormScreen> createState() => _PartyFormScreenState();
}

class _PartyFormScreenState extends State<PartyFormScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.existing?.phone ?? '',
  );
  late final TextEditingController _site = TextEditingController(
    text: widget.existing?.siteName ?? '',
  );
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
      await store.addParty(
        Party(
          id: newId(),
          name: name,
          phone: _phone.text.trim(),
          siteName: _site.text.trim(),
          isSupplier: _isSupplier,
        ),
      );
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
        title: Text(
          widget.existing == null ? 'Naya Customer' : 'Customer Edit Karo',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Naam *',
              hintText: 'Masalan: Ahmed Raza',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (WhatsApp)',
              hintText: '03xx-xxxxxxx',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _site,
            decoration: const InputDecoration(
              labelText: 'Site / Jagah ka naam',
              hintText: 'Masalan: Gulberg House',
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Customer'),
                icon: Icon(Icons.person),
              ),
              ButtonSegment(
                value: true,
                label: Text('Supplier'),
                icon: Icon(Icons.store),
              ),
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
// Customer detail — advance / kharcha ka pura hisaab, running baqi ke sath
// ===========================================================================

class PartyDetailScreen extends StatelessWidget {
  final String partyId;
  const PartyDetailScreen({super.key, required this.partyId});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final party = store.partyById(partyId);
      if (party == null) {
        return const Scaffold(body: Center(child: Text('Customer nahi mila')));
      }
      final entries = store.partyEntries(partyId);
      final baqi = store.partyBaqi(partyId);
      final advTotal = store.partyAdvanceTotal(partyId);
      final khTotal = store.partyKharchaTotal(partyId);

      // Running baqi har entry ke baad (purani se nayi ki taraf jama karke)
      double run = 0;
      final rows = <(LedgerEntry, double)>[];
      for (final e in entries) {
        run += e.baqiEffect;
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
              onPressed: () => push(context, PartyFormScreen(existing: party)),
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
                color: kNavy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party.isSupplier ? 'Supplier' : 'Customer',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  if (party.siteName.isNotEmpty)
                    Text(
                      'Site: ${party.siteName}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  if (party.phone.isNotEmpty)
                    Text(
                      party.phone,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    baqi < 0
                        ? 'Aur lena hai: ${rs(-baqi)}'
                        : 'Baqi Paisa: ${rs(baqi)}',
                    style: const TextStyle(
                      color: kAmber,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Kul Advance: ${rs(advTotal)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      Text(
                        'Kul Kharcha: ${rs(khTotal)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
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
                      onPressed: () =>
                          push(context, AdvanceFormScreen(party: party)),
                      icon: const Icon(Icons.payments, size: 19),
                      label: const Text('Advance Liya'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: kRed),
                      onPressed: () =>
                          push(context, KharchaFormScreen(party: party)),
                      icon: const Icon(Icons.money_off, size: 19),
                      label: const Text('Kharcha Karo'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => printCustomerKhata(store, party),
                  icon: const Icon(Icons.print, size: 19),
                  label: const Text('Khata Print Karo'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAmber,
                    foregroundColor: kNavy,
                  ),
                  onPressed: () async {
                    try {
                      await shareCustomerKhata(store, party);
                    } catch (_) {
                      if (context.mounted) {
                        toast(context, 'PDF share nahi ho saka');
                      }
                    }
                  },
                  icon: const Icon(Icons.share, size: 19),
                  label: const Text('PDF Share Karo'),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 2),
              child: Text(
                'Pura Hisaab',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            if (display.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Abhi koi entry nahi hai.'),
              ),
            ...display.map((row) {
              final e = row.$1;
              final baqiAfter = row.$2;
              final pos = e.baqiEffect >= 0;
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text(
                    entryLabel(e),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${fmtDate(e.date)}${e.note.isNotEmpty ? ' · ${e.note}' : ''}\nBaqi: ${rs(baqiAfter)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${pos ? '+' : '-'}${rs(e.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: pos ? kGreen : kRed,
                        ),
                      ),
                      if (e.type == 'advance' || e.type == 'kharcha')
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          tooltip: 'Edit',
                          onPressed: () {
                            if (e.type == 'advance') {
                              push(
                                context,
                                AdvanceFormScreen(party: party, existing: e),
                              );
                            } else {
                              push(
                                context,
                                KharchaFormScreen(party: party, existing: e),
                              );
                            }
                          },
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
        title: const Text('Customer delete karein?'),
        content: Text(
          '${party.name} aur us ka saara hisaab delete ho jayega. Ye wapas nahi aayega.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nahi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: kRed)),
          ),
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
// Advance form — customer se paisa liya
// ===========================================================================

class AdvanceFormScreen extends StatefulWidget {
  final Party party;

  /// Edit mode: mojooda advance entry badalni ho to ye pass hota hai.
  final LedgerEntry? existing;
  const AdvanceFormScreen({super.key, required this.party, this.existing});

  @override
  State<AdvanceFormScreen> createState() => _AdvanceFormScreenState();
}

class _AdvanceFormScreenState extends State<AdvanceFormScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _alsoCash = true;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      // Edit mode: purani entry ki values pehle se bhari hui, aur cash
      // toggle asal halat se shuru (purani cash posting hai to ON).
      _amount.text = amtFieldText(ex.amount);
      _note.text = ex.note;
      _date = ex.date;
      _alsoCash = store.hasLinkedCashEntry(ex);
    }
  }

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
    final ex = widget.existing;
    if (ex != null) {
      // Edit: wohi id, nayi values; store purani cash posting hata kar
      // toggle ke hisaab se nayi kar deta hai.
      await store.updateLedgerEntry(
        LedgerEntry(
          id: ex.id,
          partyId: ex.partyId,
          type: 'advance',
          amount: amt,
          note: _note.text.trim(),
          date: _date,
        ),
        postCash: _alsoCash,
      );
      if (mounted) {
        toast(context, 'Advance edit ho gaya');
        Navigator.pop(context);
      }
      return;
    }
    await store.addLedgerEntry(
      LedgerEntry(
        id: newId(),
        partyId: widget.party.id,
        type: 'advance',
        amount: amt,
        note: _note.text.trim(),
        date: _date,
      ),
      alsoCash: _alsoCash,
    );
    if (mounted) {
      toast(context, 'Advance save ho gaya');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null
              ? 'Advance Edit — ${widget.party.name}'
              : 'Advance Liya — ${widget.party.name}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Raqam (Rs) *',
              hintText: 'Masalan: 50000',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Masalan: Pehla advance',
            ),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cash (galla) mein jama karo'),
            subtitle: const Text('Advance cash ki shakal mein aaya hai'),
            value: _alsoCash,
            onChanged: (v) => setState(() => _alsoCash = v),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save Karo'),
            style: ElevatedButton.styleFrom(backgroundColor: kGreen),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Kharcha form — customer ke advance mein se kharcha
// Category: Material | Karigar | Custom
// ===========================================================================

class KharchaFormScreen extends StatefulWidget {
  /// Customer pehle se tay ho (customer detail / picker se aao) to ye hota
  /// hai. Home se direct kharcha me null rehta hai — phir customer form ke
  /// andar hi dropdown se chuna jata hai.
  final Party? party;

  /// Karigar tab / detail se aao to karigar pehle se chuna hota hai.
  final Karigar? initialKarigar;

  /// Edit mode: mojooda kharcha entry badalni ho to ye pass hota hai.
  final LedgerEntry? existing;
  const KharchaFormScreen({
    super.key,
    this.party,
    this.initialKarigar,
    this.existing,
  });

  @override
  State<KharchaFormScreen> createState() => _KharchaFormScreenState();
}

class _KharchaFormScreenState extends State<KharchaFormScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _custom = TextEditingController();
  DateTime _date = DateTime.now();
  bool _alsoCash = true;
  String _category = 'Material'; // Material | Karigar | Custom
  String? _karigarId;

  /// Direct mode (Home se, party preset nahi) me form ke andar chuna gaya
  /// customer. Edit / preset mode me ye entry/party se pehle se bhara hota hai.
  String? _partyId;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _partyId = ex?.partyId ?? widget.party?.id;
    if (ex != null) {
      // Edit mode: purani entry ki values pehle se bhari hui, aur cash
      // toggle asal halat se shuru (purani cash posting hai to ON).
      _amount.text = amtFieldText(ex.amount);
      _note.text = ex.note;
      _date = ex.date;
      _alsoCash = store.hasLinkedCashEntry(ex);
      if (ex.karigarId != null) {
        _category = 'Karigar';
        _karigarId = ex.karigarId;
      } else if (ex.kharchaLabel == 'Material') {
        _category = 'Material';
      } else {
        // 'Doosra' samet har doosra label Custom me khulta hai — purana
        // naam field me pehle se likha hua ata hai.
        _category = 'Custom';
        _custom.text = ex.kharchaLabel ?? '';
      }
    } else if (widget.initialKarigar != null) {
      _category = 'Karigar';
      _karigarId = widget.initialKarigar!.id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _custom.dispose();
    super.dispose();
  }

  /// AppBar ke liye customer ka naam — preset party se, warna edit mode
  /// me entry ke partyId se.
  String get _partyName =>
      widget.party?.name ??
      (widget.existing != null
          ? store.partyById(widget.existing!.partyId)?.name ?? ''
          : '');

  /// Direct mode ke dropdown ke liye naam ke hisaab se sorted customers.
  List<Party> _sortedParties() =>
      [...store.parties]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<void> _save() async {
    // Entry kis customer par lagegi: edit me entry ki apni party, preset
    // mode me wohi party, direct mode me form me chuna gaya customer.
    // Direct mode me customer na chuna ho to save ruk jata hai.
    final String partyId;
    final ex0 = widget.existing;
    if (ex0 != null) {
      partyId = ex0.partyId;
    } else if (widget.party != null) {
      partyId = widget.party!.id;
    } else if (_partyId != null) {
      partyId = _partyId!;
    } else {
      toast(context, 'Pehle customer chuno');
      return;
    }
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) {
      toast(context, 'Sahi raqam likho');
      return;
    }
    if (_category == 'Karigar' && _karigarId == null) {
      toast(context, 'Pehle karigar chuno ya naya karigar jodo');
      return;
    }
    if (_category == 'Custom' && _custom.text.trim().isEmpty) {
      toast(context, 'Custom kharcha ka naam likho');
      return;
    }
    String? kharchaLabel;
    String? karigarId;
    if (_category == 'Karigar') {
      karigarId = _karigarId;
    } else if (_category == 'Material') {
      kharchaLabel = 'Material';
    } else {
      // Custom: user ka apna likha naam hi label hai.
      kharchaLabel = _custom.text.trim();
    }
    final ex = widget.existing;
    if (ex != null) {
      // Edit: wohi id, nayi values; store purani cash posting hata kar
      // toggle ke hisaab se nayi kar deta hai.
      await store.updateLedgerEntry(
        LedgerEntry(
          id: ex.id,
          partyId: ex.partyId,
          type: 'kharcha',
          amount: amt,
          note: _note.text.trim(),
          date: _date,
          karigarId: karigarId,
          kharchaLabel: kharchaLabel,
        ),
        postCash: _alsoCash,
      );
      if (mounted) {
        toast(context, 'Kharcha edit ho gaya');
        Navigator.pop(context);
      }
      return;
    }
    await store.addLedgerEntry(
      LedgerEntry(
        id: newId(),
        partyId: partyId,
        type: 'kharcha',
        amount: amt,
        note: _note.text.trim(),
        date: _date,
        karigarId: karigarId,
        kharchaLabel: kharchaLabel,
      ),
      alsoCash: _alsoCash,
    );
    if (mounted) {
      toast(context, 'Kharcha save ho gaya');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null
              ? 'Kharcha Edit — $_partyName'
              : (widget.party != null
                    ? 'Kharcha — $_partyName'
                    : 'Kharcha Karo'),
        ),
      ),
      body: storeBuilder((context) {
        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Direct mode (Home se, koi party preset nahi aur edit bhi
            // nahi): customer form ke andar hi dropdown se chuna jata hai.
            if (widget.existing == null && widget.party == null) ...[
              if (store.parties.isEmpty)
                const Text('Pehle Customers mein ja kar customer add karo')
              else
                DropdownButtonFormField<String>(
                  initialValue: _partyId,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: _sortedParties()
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(
                            p.siteName.isNotEmpty
                                ? '${p.name} — ${p.siteName}'
                                : p.name,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _partyId = v),
                ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Raqam (Rs) *',
                hintText: 'Masalan: 5000',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Kharcha kis par?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Material',
                  label: Text('Material'),
                  icon: Icon(Icons.layers),
                ),
                ButtonSegment(
                  value: 'Karigar',
                  label: Text('Karigar'),
                  icon: Icon(Icons.engineering),
                ),
                ButtonSegment(
                  value: 'Custom',
                  label: Text('Custom'),
                  icon: Icon(Icons.edit_note),
                ),
              ],
              selected: {_category},
              onSelectionChanged: (s) => setState(() => _category = s.first),
            ),
            if (_category == 'Karigar') ...[
              const SizedBox(height: 12),
              const Text(
                'Karigar chuno',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              if (store.karigars.isEmpty)
                const Text('Abhi koi karigar nahi hai — pehle naya jodo.'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ...store.karigars.map(
                    (k) => ChoiceChip(
                      label: Text(k.name),
                      selected: _karigarId == k.id,
                      onSelected: (_) => setState(() => _karigarId = k.id),
                    ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Naya Karigar'),
                    onPressed: () async {
                      final k = await showQuickKarigarDialog(context);
                      if (k != null && mounted) {
                        setState(() => _karigarId = k.id);
                      }
                    },
                  ),
                ],
              ),
            ],
            if (_category == 'Custom') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _custom,
                decoration: const InputDecoration(
                  labelText: 'Custom kharcha ka naam *',
                  hintText: 'Masalan: Petrol, Khana, Gaari bhara',
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Masalan: Gypsum sheets',
              ),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cash (galla) se kata'),
              subtitle: const Text('Kharcha galle ke cash se hua hai'),
              value: _alsoCash,
              onChanged: (v) => setState(() => _alsoCash = v),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save Karo'),
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
            ),
          ],
        );
      }),
    );
  }
}

/// Chhota dialog: naam + phone se foran naya karigar jodo.
/// Cancel / khali naam par null wapas ata hai.
Future<Karigar?> showQuickKarigarDialog(BuildContext context) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Naya Karigar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Naam *',
              hintText: 'Masalan: Ustad Rafiq',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              hintText: '03xx-xxxxxxx',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Jodo'),
        ),
      ],
    ),
  );
  final n = name.text.trim();
  final p = phone.text.trim();
  name.dispose();
  phone.dispose();
  if (ok != true) return null;
  if (n.isEmpty) {
    if (context.mounted) toast(context, 'Karigar ka naam likhna zaroori hai');
    return null;
  }
  final k = Karigar(id: newId(), name: n, phone: p, createdAt: DateTime.now());
  await store.addKarigar(k);
  return k;
}

// ===========================================================================
// Karigar tab — saare karigaron ki list, kul diya ke sath
// ===========================================================================

class KarigarListScreen extends StatelessWidget {
  const KarigarListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final list = [...store.karigars]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Scaffold(
        appBar: AppBar(title: const Text('Karigar')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => push(context, const KarigarFormScreen()),
          icon: const Icon(Icons.person_add),
          label: const Text('Naya Karigar'),
        ),
        body: list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Koi karigar nahi.\n"Naya Karigar" se pehla karigar jodo.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 84),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final k = list[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: kNavy,
                        child: Text(
                          k.name.isNotEmpty ? k.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: kAmber,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        k.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(k.phone.isNotEmpty ? k.phone : 'Karigar'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            rs(store.karigarTotalPaid(k.id)),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const Text(
                            'Kul diya',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      onTap: () =>
                          push(context, KarigarDetailScreen(karigarId: k.id)),
                    ),
                  );
                },
              ),
      );
    });
  }
}

// ===========================================================================
// Karigar detail — kul diya + is karigar ki saari payments (kis customer se)
// ===========================================================================

class KarigarDetailScreen extends StatelessWidget {
  final String karigarId;
  const KarigarDetailScreen({super.key, required this.karigarId});

  @override
  Widget build(BuildContext context) {
    return storeBuilder((context) {
      final karigar = store.karigarById(karigarId);
      if (karigar == null) {
        return const Scaffold(body: Center(child: Text('Karigar nahi mila')));
      }
      final total = store.karigarTotalPaid(karigarId);
      final entries = store.entriesForKarigar(karigarId);

      return Scaffold(
        appBar: AppBar(
          title: Text(karigar.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () =>
                  push(context, KarigarFormScreen(existing: karigar)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmDeleteKarigar(context, karigar),
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
                color: kNavy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Karigar',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    karigar.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (karigar.phone.isNotEmpty)
                    Text(
                      karigar.phone,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  if (karigar.note.isNotEmpty)
                    Text(
                      karigar.note,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kul Diya',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    rs(total),
                    style: const TextStyle(
                      color: kAmber,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAmber,
                  foregroundColor: kNavy,
                ),
                onPressed: () => push(
                  context,
                  EntryPartyPickerScreen(
                    kind: 'karigarKharcha',
                    karigarId: karigar.id,
                  ),
                ),
                icon: const Icon(Icons.payments, size: 19),
                label: const Text('Payment Do'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 2),
              child: Text(
                'Payment History',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Abhi is karigar ko koi payment nahi gayi.'),
              ),
            ...entries.map((e) {
              final p = store.partyById(e.partyId);
              return Card(
                child: ListTile(
                  dense: true,
                  title: Text(
                    p?.name ?? 'Purana customer',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      if (p != null && p.siteName.isNotEmpty)
                        'Site: ${p.siteName}',
                      fmtDate(e.date),
                      if (e.note.isNotEmpty) e.note,
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rs(e.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (p != null)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          tooltip: 'Edit',
                          onPressed: () {
                            final pp = store.partyById(e.partyId);
                            if (pp != null) {
                              push(
                                context,
                                KharchaFormScreen(party: pp, existing: e),
                              );
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

  Future<void> _confirmDeleteKarigar(
    BuildContext context,
    Karigar karigar,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Karigar delete karein?'),
        content: Text(
          '${karigar.name} list se hat jayega. Us ki purani payment entries customers ke hisaab mein waisi hi rahengi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nahi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await store.deleteKarigar(karigar.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ===========================================================================
// Karigar banana / edit karna
// ===========================================================================

class KarigarFormScreen extends StatefulWidget {
  final Karigar? existing;
  const KarigarFormScreen({super.key, this.existing});

  @override
  State<KarigarFormScreen> createState() => _KarigarFormScreenState();
}

class _KarigarFormScreenState extends State<KarigarFormScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.existing?.phone ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Naam likhna zaroori hai');
      return;
    }
    if (widget.existing == null) {
      await store.addKarigar(
        Karigar(
          id: newId(),
          name: name,
          phone: _phone.text.trim(),
          note: _note.text.trim(),
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) toast(context, 'Karigar ban gaya');
    } else {
      final k = widget.existing!;
      k.name = name;
      k.phone = _phone.text.trim();
      k.note = _note.text.trim();
      await store.updateKarigar(k);
      if (mounted) toast(context, 'Karigar update ho gaya');
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Naya Karigar' : 'Karigar Edit Karo',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Naam *',
              hintText: 'Masalan: Ustad Rafiq',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              hintText: '03xx-xxxxxxx',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note',
              hintText: 'Masalan: Ceiling wala karigar',
            ),
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
// Settings — business name, backup / restore
// ===========================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _biz = TextEditingController(
    text: store.businessName,
  );
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
      toast(
        context,
        'Backup copy ho gaya — isay kahin safe jagah (WhatsApp/Notes) save kar lo',
      );
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
          'Maujooda saara data is backup se badal jayega. Yaqeen hai?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nahi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore Karo'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await store.importJson(raw);
    if (mounted) {
      toast(
        context,
        done ? 'Data restore ho gaya' : 'Ye backup text sahi nahi hai',
      );
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
            const Text(
              'Business ka naam',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
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
                    decoration: const InputDecoration(
                      labelText: 'Business Name',
                    ),
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
            const Text(
              'Backup (Data mehfooz rakho)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
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
                backgroundColor: kAmber,
                foregroundColor: kNavy,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Restore (Backup wapas lao)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
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
              child: Text(
                'Khata Book — koi subscription nahi, data aap ke phone par',
                style: TextStyle(fontSize: 11.5, color: Colors.black45),
              ),
            ),
          ],
        ),
      );
    });
  }
}
