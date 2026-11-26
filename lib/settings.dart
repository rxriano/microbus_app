import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'plate.dart';

class SettingsScreen extends StatelessWidget {
  final AppStore store;
  final TripState trip;
  const SettingsScreen(this.store, this.trip, {super.key});

  void _select(int i) {
    store.selected = i;
    store.changed();
    trip.setLine(store.line);
  }

  Future<void> _delete(BuildContext context, int i) async {
    if (store.lines.length <= 1) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف خط "${store.lines[i].name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    final wasActive = i == store.selected;
    store.lines.removeAt(i);
    store.selected = wasActive
        ? 0
        : (store.selected > i ? store.selected - 1 : store.selected);
    store.changed();
    if (wasActive) trip.setLine(store.line);
  }

  void _add(BuildContext context) {
    final l = Line(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'خط جديد',
      stations: ['المحطة 1', 'المحطة 2'],
    );
    store.lines.add(l);
    store.changed();
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => LineEditor(store, l, trip)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(children: [
        SwitchListTile(
          title: const Text('الوضع الداكن'),
          value: store.dark,
          onChanged: store.setDark,
        ),
        SwitchListTile(
          title: const Text('ألوان Material You (من خلفية الموبايل)'),
          subtitle: const Text('بتغيّر ألوان الشريط والأزرار بس، مش الكراسي'),
          value: store.materialYou,
          onChanged: store.setMaterialYou,
        ),
        ListTile(
          leading: AvatarView(photoB64: store.photoB64, radius: 20),
          title: const Text('بروفايل السواق'),
          subtitle: Text(store.driverName.isEmpty
              ? 'اسم السواق ورقم اللوحة'
              : store.driverName),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ProfileScreen(store))),
        ),
        const Divider(),
        const ListTile(title: Text('الخطوط (اضغط لاختيار الخط الحالي)')),
        for (var i = 0; i < store.lines.length; i++)
          ListTile(
            leading: Icon(i == store.selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked),
            title: Text(store.lines[i].name),
            subtitle: Text('${store.lines[i].stations.length} محطات'),
            onTap: () => _select(i),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            LineEditor(store, store.lines[i], trip))),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _delete(context, i),
              ),
            ]),
          ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('إضافة خط'),
          onTap: () => _add(context),
        ),
      ]),
    ),
  );
}

class LineEditor extends StatefulWidget {
  final AppStore store;
  final Line line;
  final TripState trip;
  const LineEditor(this.store, this.line, this.trip, {super.key});
  @override
  State<LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<LineEditor> {
  late final TextEditingController name;
  Line get line => widget.line;
  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: line.name);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _changed() {
    store.changed();
    setState(() {});
  }

  Future<void> _addStation() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اسم المحطة'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('إضافة')),
        ],
      ),
    );
    if (v == null || v.isEmpty || line.stations.contains(v)) return;
    line.stations.add(v);
    _changed();
  }

  void _removeStation(String st) {
    if (line.stations.length <= 2) return;
    line.stations.remove(st);
    line.fares.removeWhere((k, _) => k.split('|').contains(st));
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final n = line.stations.length;
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الخط')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        TextField(
          controller: name,
          decoration: const InputDecoration(
              labelText: 'اسم الخط', border: OutlineInputBorder()),
          onChanged: (v) {
            line.name = v;
            store.changed();
          },
        ),
        const SizedBox(height: 12),
        const Text('المحطات بالترتيب (اسحب لإعادة الترتيب)'),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorder: (o, nw) {
            if (nw > o) nw--;
            line.stations.insert(nw, line.stations.removeAt(o));
            _changed();
          },
          children: [
            for (final st in line.stations)
              ListTile(
                key: ValueKey(st),
                title: Text(st),
                trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeStation(st)),
              ),
          ],
        ),
        OutlinedButton.icon(
            onPressed: _addStation,
            icon: const Icon(Icons.add),
            label: const Text('إضافة محطة')),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.table_chart),
          label: Text('جدول الأجرة (${n * (n - 1) ~/ 2} سعر)'),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => FareTablePage(store, line))).then(
                  (_) => setState(() {})),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('السعر بين أي محطتين، نفسه في الاتجاهين.',
              style: TextStyle(fontSize: 12)),
        ),
      ]),
    );
  }
}

class FareTablePage extends StatefulWidget {
  final AppStore store;
  final Line line;
  const FareTablePage(this.store, this.line, {super.key});
  @override
  State<FareTablePage> createState() => _FareTablePageState();
}

class _FareTablePageState extends State<FareTablePage> {
  final pairs = <List<String>>[];
  final ctrls = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final st = widget.line.stations;
    for (var i = 0; i < st.length; i++) {
      for (var j = i + 1; j < st.length; j++) {
        pairs.add([st[i], st[j]]);
        final f = widget.line.fare(st[i], st[j]);
        ctrls[fareKey(st[i], st[j])] =
            TextEditingController(text: f == 0 ? '' : '$f');
      }
    }
  }

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('أجرة: ${widget.line.name}')),
    body: ListView(children: [
      for (final p in pairs)
        ListTile(
          title: Text('${p[0]} ← ${p[1]}'),
          trailing: SizedBox(
            width: 90,
            child: TextField(
              controller: ctrls[fareKey(p[0], p[1])],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '0'),
              onChanged: (v) {
                widget.line.fares[fareKey(p[0], p[1])] =
                    int.tryParse(v) ?? 0;
                widget.store.changed();
              },
            ),
          ),
        ),
    ]),
  );
}

class ProfileScreen extends StatefulWidget {
  final AppStore store;
  const ProfileScreen(this.store, {super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppStore get store => widget.store;
  late final name = TextEditingController(text: store.driverName);
  late final phone = TextEditingController(text: store.phone);
  late final phone2 = TextEditingController(text: store.phone2);
  late final letters = TextEditingController(text: store.plateLetters);
  late final digits = TextEditingController(text: store.plateDigits);
  final _picker = ImagePicker();

  @override
  void dispose() {
    for (final c in [name, phone, phone2, letters, digits]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    store.driverName = name.text.trim();
    store.phone = toLatinDigits(phone.text.trim());
    store.phone2 = toLatinDigits(phone2.text.trim());
    store.plateLetters = letters.text.trim();
    store.plateDigits = toLatinDigits(digits.text.trim());
    store.changed();
    setState(() {});
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final f = await _picker.pickImage(
          source: src, maxWidth: 256, maxHeight: 256, imageQuality: 80);
      if (f == null) return;
      store.setPhoto(base64Encode(await f.readAsBytes()));
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذّر اختيار الصورة')));
    }
  }

  void _photoMenu() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('من المعرض'),
          onTap: () {
            Navigator.pop(ctx);
            _pick(ImageSource.gallery);
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_camera),
          title: const Text('من الكاميرا'),
          onTap: () {
            Navigator.pop(ctx);
            _pick(ImageSource.camera);
          },
        ),
        if (store.photoB64.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('حذف الصورة'),
            onTap: () {
              Navigator.pop(ctx);
              store.setPhoto('');
              setState(() {});
            },
          ),
      ]),
    ),
  );

  String? _phoneError(String v) {
    final t = toLatinDigits(v.trim());
    if (t.isEmpty) return null;
    return RegExp(r'^01\d{9}$').hasMatch(t)
        ? null
        : 'رقم غير صحيح (11 رقم يبدأ بـ 01)';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بروفايل السواق')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Center(
        child: Stack(children: [
          AvatarView(photoB64: store.photoB64, radius: 52),
          Positioned(
            bottom: 0,
            left: 0,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.photo_camera,
                    size: 18,
                    color: Theme.of(context).colorScheme.onPrimary),
                onPressed: _photoMenu,
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      TextField(
        controller: name,
        decoration: const InputDecoration(
            labelText: 'اسم السواق (الأول أو ثنائي)',
            border: OutlineInputBorder()),
        onChanged: (_) => _save(),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
            labelText: 'رقم التليفون (الأساسي)',
            errorText: _phoneError(phone.text),
            border: const OutlineInputBorder()),
        onChanged: (_) => _save(),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: phone2,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
            labelText: 'رقم احتياطي (اختياري)',
            errorText: _phoneError(phone2.text),
            border: const OutlineInputBorder()),
        onChanged: (_) => _save(),
      ),
      const SizedBox(height: 24),
      Center(
          child: PlateView(
              letters: letters.text, digits: digits.text, scale: 1.2)),
      const SizedBox(height: 16),
      TextField(
        controller: letters,
        maxLength: 3,
        decoration: const InputDecoration(
            labelText: 'حروف اللوحة (عربي)', border: OutlineInputBorder()),
        onChanged: (_) => _save(),
      ),
      const SizedBox(height: 4),
      TextField(
        controller: digits,
        maxLength: 4,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
            labelText: 'أرقام اللوحة', border: OutlineInputBorder()),
        onChanged: (_) => _save(),
      ),
    ]),
  );
}