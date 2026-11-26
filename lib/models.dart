import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

String fareKey(String a, String b) => a.compareTo(b) < 0 ? '$a|$b' : '$b|$a';

String _today() => DateTime.now().toIso8601String().substring(0, 10);

// Vehicle layout as data: -1 = driver, 0 = spacer/aisle, 1..n = passenger seat.
const kHiace = <List<int>>[
  [-1, 0, 1, 2],
  [3, 4, 0, 5],
  [6, 7, 0, 8],
  [9, 10, 0, 11],
  [12, 13, 14],
];

// ---------------------------------------------------------------------------
// Lines + app settings
// ---------------------------------------------------------------------------
class Line {
  final String id;
  String name;
  List<String> stations;
  Map<String, int> fares; // key = fareKey(a, b), same fare both directions

  Line({
    required this.id,
    required this.name,
    required this.stations,
    Map<String, int>? fares,
  }) : fares = fares ?? {};

  int fare(String a, String b) => fares[fareKey(a, b)] ?? 0;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'stations': stations, 'fares': fares};

  factory Line.fromJson(Map<String, dynamic> j) => Line(
    id: j['id'] as String,
    name: j['name'] as String,
    stations: List<String>.from(j['stations'] as List),
    fares: Map<String, int>.from(j['fares'] as Map),
  );

  // DEMO values: edit them from the settings screen.
  static Line demo() {
    const list = <List<Object>>[
      ['بنها', 'طوخ', 10],
      ['بنها', 'قها', 15],
      ['بنها', 'القليوب', 18],
      ['بنها', 'القاهرة', 20],
      ['طوخ', 'قها', 5],
      ['طوخ', 'القليوب', 8],
      ['طوخ', 'القاهرة', 10],
      ['قها', 'القليوب', 5],
      ['قها', 'القاهرة', 10],
      ['القليوب', 'القاهرة', 7],
    ];
    return Line(
      id: 'demo',
      name: 'بنها – القاهرة',
      stations: ['بنها', 'طوخ', 'قها', 'القليوب', 'القاهرة'],
      fares: {
        for (final r in list) fareKey(r[0] as String, r[1] as String): r[2] as int,
      },
    );
  }
}

class AppStore extends ChangeNotifier {
  final SharedPreferences prefs;
  List<Line> lines = [];
  int selected = 0;
  bool dark = false;
  String driverName = '';
  String plateLetters = '';
  String plateDigits = '';
  String phone = '';
  String phone2 = '';
  String photoB64 = ''; // stored under its own key
  bool materialYou = false;

  AppStore(this.prefs) {
    photoB64 = prefs.getString('photo') ?? '';
    final raw = prefs.getString('settings');
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        lines = [
          for (final e in j['lines'] as List)
            Line.fromJson(e as Map<String, dynamic>)
        ];
        selected = (j['selected'] as int?) ?? 0;
        dark = (j['dark'] as bool?) ?? false;
        driverName = (j['driverName'] as String?) ?? '';
        plateLetters = (j['plateLetters'] as String?) ?? '';
        plateDigits = (j['plateDigits'] as String?) ?? '';
        phone = (j['phone'] as String?) ?? '';
        phone2 = (j['phone2'] as String?) ?? '';
        materialYou = (j['materialYou'] as bool?) ?? false;
      } catch (_) {
        lines = [];
      }
    }
    if (lines.isEmpty) lines = [Line.demo()];
    selected = selected.clamp(0, lines.length - 1).toInt();
  }

  Line get line => lines[selected];

  void setPhoto(String b64) {
    photoB64 = b64;
    prefs.setString('photo', b64);
    notifyListeners();
  }

  void setMaterialYou(bool v) {
    materialYou = v;
    notifyListeners();
  }

  void setDark(bool v) {
    dark = v;
    notifyListeners();
  }

  // Call after mutating a line, the lines list, or `selected`.
  void changed() => notifyListeners();

  @override
  void notifyListeners() {
    super.notifyListeners();
    prefs.setString(
      'settings',
      jsonEncode({
        'lines': [for (final l in lines) l.toJson()],
        'selected': selected,
        'dark': dark,
        'driverName': driverName,
        'plateLetters': plateLetters,
        'plateDigits': plateDigits,
        'phone': phone,
        'phone2': phone2,
        'materialYou': materialYou,
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Trip ledger
// ---------------------------------------------------------------------------
enum SeatStatus { empty, boarded, awaitingChange, settled }

class Ride {
  final int seat;
  final String from;
  String? dest;
  int? groupId;
  bool open = true;
  Ride(this.seat, this.from);
}

class PayGroup {
  final int id;
  final int given;
  final int due;
  bool changeDone = false;
  PayGroup(this.id, this.given, this.due);
  int get change => given - due;
}

class TripState extends ChangeNotifier {
  final AppStore store;
  final SharedPreferences prefs;

  String lineId = '';
  bool reversed = false;
  int current = 0;
  bool running = false;
  int dayTotal = 0;
  String dayKey = _today();
  final List<Ride> rides = []; // ledger: nothing is removed during a trip
  final Map<int, PayGroup> groups = {};
  final Set<int> selected = {};
  int _gid = 1;

  TripState(this.store, this.prefs) {
    lineId = store.line.id;
    _load();
  }

  Line get line =>
      store.lines.firstWhere((l) => l.id == lineId, orElse: () => store.line);

  List<String> get stations =>
      reversed ? line.stations.reversed.toList() : List.of(line.stations);

  int fareBetween(String a, String b) => line.fare(a, b);
  int fareOf(Ride r) => r.dest == null ? 0 : fareBetween(r.from, r.dest!);

  Ride? active(int seat) {
    for (final r in rides.reversed) {
      if (r.seat == seat && r.open) return r;
    }
    return null;
  }

  // ---- money -------------------------------------------------------------
  int get expected => rides.fold(0, (t, r) => t + fareOf(r));
  int get paidFares => rides
      .where((r) => r.groupId != null)
      .fold(0, (t, r) => t + fareOf(r));
  int get remaining => expected - paidFares;
  // Cash actually in hand: everything received minus change already handed back.
  int get cashInHand => groups.values
      .fold(0, (t, g) => t + g.given - (g.changeDone ? g.change : 0));
  int get pendingChange => groups.values
      .where((g) => g.change > 0 && !g.changeDone)
      .fold(0, (t, g) => t + g.change);
  int get occupied => rides.where((r) => r.open).length;

  // ---- seat state ----------------------------------------------------------
  SeatStatus status(int seat) {
    final r = active(seat);
    if (r == null) return SeatStatus.empty;
    if (r.groupId == null) return SeatStatus.boarded;
    final g = groups[r.groupId]!;
    return (g.change > 0 && !g.changeDone)
        ? SeatStatus.awaitingChange
        : SeatStatus.settled;
  }

  // Stop reached or passed and the passenger is still marked aboard.
  bool arrived(int seat) {
    final r = active(seat);
    return running &&
        r != null &&
        r.dest != null &&
        stations.indexOf(r.dest!) <= current;
  }

  // Change badge shown once per payment group, on its lowest open seat.
  String? changeBadge(int seat) {
    final r = active(seat);
    if (r == null || r.groupId == null) return null;
    final g = groups[r.groupId]!;
    if (g.change <= 0 || g.changeDone) return null;
    final seats = rides
        .where((x) => x.open && x.groupId == g.id)
        .map((x) => x.seat)
        .toList();
    if (seats.isEmpty || seats.reduce((a, b) => a < b ? a : b) != seat) {
      return null;
    }
    return 'باقي ${g.change}';
  }

  // Small tag on seats that paid together (only when 2+ passengers).
  String? groupLabel(int seat) {
    final r = active(seat);
    if (r == null || r.groupId == null) return null;
    final size = rides.where((x) => x.groupId == r.groupId).length;
    return size > 1 ? 'م${r.groupId}' : null;
  }

  // ---- actions -------------------------------------------------------------
  void toggleLoading(int seat) {
    final r = active(seat);
    if (r == null) {
      rides.add(Ride(seat, stations[current]));
    } else {
      r.open = false;
    }
    notifyListeners();
  }

  void fillAll(List<List<int>> layout) {
    for (final row in layout) {
      for (final n in row) {
        if (n > 0 && active(n) == null) rides.add(Ride(n, stations[current]));
      }
    }
    notifyListeners();
  }

  void depart() {
    running = true;
    notifyListeners();
  }

  void board(int seat) {
    if (active(seat) == null) {
      rides.add(Ride(seat, stations[current]));
      notifyListeners();
    }
  }

  void toggleSelect(int seat) {
    if (!selected.remove(seat)) selected.add(seat);
    notifyListeners();
  }

  bool pay(Map<int, String> dests, int given) {
    final due = dests.entries
        .fold(0, (t, e) => t + fareBetween(active(e.key)!.from, e.value));
    if (given < due) return false;
    final g = PayGroup(_gid++, given, due);
    groups[g.id] = g;
    dests.forEach((seat, d) {
      final r = active(seat)!;
      r.dest = d;
      r.groupId = g.id;
    });
    selected.clear();
    notifyListeners();
    return true;
  }

  void saveDests(Map<int, String> dests) {
    dests.forEach((seat, d) => active(seat)!.dest = d);
    selected.clear();
    notifyListeners();
  }

  void deliverChange(int seat) {
    final r = active(seat);
    if (r?.groupId != null) groups[r!.groupId!]!.changeDone = true;
    notifyListeners();
  }

  void alight(int seat) {
    active(seat)?.open = false;
    selected.remove(seat);
    notifyListeners();
  }

  void goTo(int i) {
    current = i.clamp(0, stations.length - 1).toInt();
    notifyListeners();
  }

  void _clear() {
    dayTotal += paidFares;
    rides.clear();
    groups.clear();
    selected.clear();
    running = false;
    current = 0;
  }

  void newTrip({bool reverse = false}) {
    _clear();
    if (reverse) reversed = !reversed;
    notifyListeners();
  }

  void setLine(Line l) {
    _clear();
    lineId = l.id;
    reversed = false;
    notifyListeners();
  }

  // ---- persistence ---------------------------------------------------------
  void _save() {
    prefs.setString(
      'trip',
      jsonEncode({
        'lineId': lineId,
        'reversed': reversed,
        'current': current,
        'running': running,
        'gid': _gid,
        'dayTotal': dayTotal,
        'dayKey': dayKey,
        'rides': [
          for (final r in rides)
            {
              'seat': r.seat,
              'from': r.from,
              'dest': r.dest,
              'groupId': r.groupId,
              'open': r.open,
            }
        ],
        'groups': [
          for (final g in groups.values)
            {
              'id': g.id,
              'given': g.given,
              'due': g.due,
              'changeDone': g.changeDone,
            }
        ],
      }),
    );
  }

  void _load() {
    final raw = prefs.getString('trip');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (!store.lines.any((l) => l.id == j['lineId'])) return;
      lineId = j['lineId'] as String;
      reversed = j['reversed'] as bool;
      running = j['running'] as bool;
      _gid = j['gid'] as int;
      final today = _today();
      dayTotal = (j['dayKey'] as String) == today ? j['dayTotal'] as int : 0;
      dayKey = today; // day total is kept for the current day only
      for (final r in j['rides'] as List) {
        final m = r as Map<String, dynamic>;
        rides.add(Ride(m['seat'] as int, m['from'] as String)
          ..dest = m['dest'] as String?
          ..groupId = m['groupId'] as int?
          ..open = m['open'] as bool);
      }
      for (final g in j['groups'] as List) {
        final m = g as Map<String, dynamic>;
        groups[m['id'] as int] =
        PayGroup(m['id'] as int, m['given'] as int, m['due'] as int)
          ..changeDone = m['changeDone'] as bool;
      }
      current = (j['current'] as int).clamp(0, stations.length - 1).toInt();
    } catch (_) {
      rides.clear();
      groups.clear();
      running = false;
      current = 0;
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    _save();
  }
}