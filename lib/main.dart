import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final store = AppStore(prefs);
  final trip = TripState(store, prefs);
  runApp(MicrobusApp(store, trip));
}

class MicrobusApp extends StatelessWidget {
  final AppStore store;
  final TripState trip;
  const MicrobusApp(this.store, this.trip, {super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
          darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.indigo,
              brightness: Brightness.dark),
          builder: (c, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: TripScreen(store, trip),
        ),
      );
}

class TripScreen extends StatefulWidget {
  final AppStore store;
  final TripState trip;
  const TripScreen(this.store, this.trip, {super.key});
  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  TripState get s => widget.trip;
  bool get dark => Theme.of(context).brightness == Brightness.dark;

  Color _color(int seat) {
    if (s.arrived(seat)) return Colors.red.shade500; // whole square turns red
    switch (s.status(seat)) {
      case SeatStatus.empty:
        return dark ? Colors.grey.shade800 : Colors.grey.shade300;
      case SeatStatus.boarded:
        return Colors.blue.shade400;
      case SeatStatus.awaitingChange:
        return Colors.amber.shade600;
      case SeatStatus.settled:
        return Colors.green.shade500;
    }
  }

  void _onSeat(int n) {
    if (!s.running) {
      s.toggleLoading(n);
      return;
    }
    switch (s.status(n)) {
      case SeatStatus.empty:
        s.board(n);
      case SeatStatus.boarded:
        s.toggleSelect(n);
      default:
        _seatActions(n);
    }
  }

  void _seatActions(int n) {
    if (s.status(n) == SeatStatus.empty) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (s.status(n) == SeatStatus.awaitingChange)
            ListTile(
              leading: const Icon(Icons.check_circle),
              title: const Text('تم تسليم الباقي'),
              onTap: () {
                s.deliverChange(n);
                Navigator.pop(ctx);
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('نزّل الراكب (يفضّي الكرسي)'),
            onTap: () {
              s.alight(n);
              Navigator.pop(ctx);
            },
          ),
        ]),
      ),
    );
  }

  Widget _seat(int n) {
    final r = s.active(n);
    final empty = s.status(n) == SeatStatus.empty;
    final fg = (empty && dark) ? Colors.white : Colors.black87;
    final badge = s.changeBadge(n);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: _color(n),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onSeat(n),
          onLongPress: s.running ? () => _seatActions(n) : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: s.selected.contains(n)
                      ? (dark ? Colors.white : Colors.black)
                      : Colors.transparent,
                  width: 4),
            ),
            alignment: Alignment.center,
            child: DefaultTextStyle(
              style: TextStyle(color: fg),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('$n', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (r?.dest != null)
                  Text(r!.dest!,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center),
                if (s.arrived(n))
                  const Text('وصل',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(badge,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.black)),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cabin() => Directionality(
        textDirection: TextDirection.ltr, // keep the driver on the left
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade600, width: 3),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(children: [
            for (final row in kHiace)
              Expanded(
                child: Row(children: [
                  for (final n in row)
                    Expanded(
                      flex: n == 0 ? 1 : 2,
                      child: n == 0
                          ? const SizedBox()
                          : n == -1
                              ? const Center(
                                  child: Icon(Icons.sports_motorsports,
                                      size: 36, color: Colors.grey))
                              : _seat(n),
                    ),
                ]),
              ),
          ]),
        ),
      );

  Widget _stat(String label, int v, Color c) => Expanded(
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: c.withAlpha(45), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text('$v',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  Widget _summary() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(children: [
          Text(
            s.running
                ? 'المحطة الحالية: ${s.stations[s.current]}'
                : 'وضع التحميل',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Row(children: [
            _stat('الإجمالي', s.expected, Colors.indigo),
            _stat('اتحصّل (معاك)', s.cashInHand, Colors.green),
            _stat('المتبقي', s.remaining, Colors.red),
          ]),
          if (s.pendingChange > 0)
            Text('باقي للركاب: ${s.pendingChange}',
                style: const TextStyle(fontSize: 13)),
          Text('إجمالي اليوم: ${s.dayTotal + s.paidFares}',
              style: const TextStyle(fontSize: 12)),
        ]),
      );

  Future<void> _pickStation() async {
    final i = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('اختر المحطة'),
        children: [
          for (var i = 0; i < s.stations.length; i++)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, i),
                child: Text(s.stations[i])),
        ],
      ),
    );
    if (i != null) s.goTo(i);
  }

  void _openSettings() {
    if (s.rides.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('أنهِ الرحلة الأول (رحلة جديدة) قبل تعديل الإعدادات')));
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => SettingsScreen(widget.store, s)));
  }

  Widget _controls() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: s.running
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                if (s.selected.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.payments),
                      label: Text('دفع / تحديد وجهة (${s.selected.length})'),
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => PaySheet(s),
                      ),
                    ),
                  ),
                Row(children: [
                  OutlinedButton(
                      onPressed:
                          s.current > 0 ? () => s.goTo(s.current - 1) : null,
                      child: const Text('السابقة')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: s.current < s.stations.length - 1
                          ? () => s.goTo(s.current + 1)
                          : null,
                      onLongPress: _pickStation,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('المحطة الجاية',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                ]),
              ])
            : Row(children: [
                OutlinedButton(
                    onPressed: () => s.fillAll(kHiace),
                    child: const Text('العربية مليانة')),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: s.occupied > 0 ? s.depart : null,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('تحرّك', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ]),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([s, widget.store]),
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: Text('${s.stations.first} إلى ${s.stations.last}'),
            actions: [
              IconButton(
                tooltip: 'الوضع الداكن',
                icon: Icon(widget.store.dark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => widget.store.setDark(!widget.store.dark),
              ),
              IconButton(
                  tooltip: 'الإعدادات',
                  icon: const Icon(Icons.settings),
                  onPressed: _openSettings),
              PopupMenuButton<String>(
                onSelected: (v) => s.newTrip(reverse: v == 'rev'),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'new', child: Text('رحلة جديدة')),
                  PopupMenuItem(
                      value: 'rev', child: Text('رحلة جديدة (اقلب الاتجاه)')),
                ],
              ),
            ],
          ),
          body: Column(children: [
            _summary(),
            Expanded(child: _cabin()),
            _controls(),
          ]),
        ),
      );
}

// Payment / destination sheet for the currently selected seats.
class PaySheet extends StatefulWidget {
  final TripState s;
  const PaySheet(this.s, {super.key});
  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  late final List<int> seats;
  late final Map<int, String?> dests;
  final ctrl = TextEditingController();

  TripState get s => widget.s;

  @override
  void initState() {
    super.initState();
    seats = s.selected.toList()..sort();
    dests = {for (final n in seats) n: s.active(n)!.dest};
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  int get due => dests.entries
      .where((e) => e.value != null)
      .fold(0, (t, e) => t + s.fareBetween(s.active(e.key)!.from, e.value!));

  @override
  Widget build(BuildContext context) {
    final given = int.tryParse(ctrl.text) ?? 0;
    final allSet = dests.values.every((d) => d != null);
    final canPay = allSet && due > 0 && given >= due;
    final stations = s.stations;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final n in seats)
            Row(children: [
              Text('كرسي $n  ', style: const TextStyle(fontSize: 16)),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: dests[n],
                  hint: const Text('الوجهة'),
                  items: [
                    for (final st in stations
                        .skip(stations.indexOf(s.active(n)!.from) + 1))
                      DropdownMenuItem(
                        value: st,
                        child: Text(
                            '$st  (${s.fareBetween(s.active(n)!.from, st)})'),
                      ),
                  ],
                  onChanged: (v) => setState(() => dests[n] = v),
                ),
              ),
            ]),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'المبلغ المستلم', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          Wrap(spacing: 6, children: [
            for (final v in [5, 10, 20, 50, 100])
              ActionChip(
                  label: Text('$v'),
                  onPressed: () => setState(() => ctrl.text = '$v')),
            ActionChip(
                label: const Text('بالظبط'),
                onPressed: () => setState(() => ctrl.text = '$due')),
          ]),
          const SizedBox(height: 8),
          Text('المطلوب: $due',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (given > 0 && given < due)
            Text('ناقص ${due - given}',
                style: const TextStyle(color: Colors.red, fontSize: 16)),
          if (given >= due && due > 0)
            Text('الباقي: ${given - due}',
                style: const TextStyle(color: Colors.green, fontSize: 16)),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton(
              onPressed: allSet
                  ? () {
                      s.saveDests(
                          {for (final e in dests.entries) e.key: e.value!});
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('حفظ الوجهة بدون دفع'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: canPay
                    ? () {
                        s.pay({for (final e in dests.entries) e.key: e.value!},
                            given);
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('تأكيد الدفع'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
