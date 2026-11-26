import 'package:flutter/material.dart';

String toArabicDigits(String s) {
  const west = '0123456789';
  const east = '٠١٢٣٤٥٦٧٨٩';
  return s.split('').map((c) {
    final i = west.indexOf(c);
    return i < 0 ? c : east[i];
  }).join();
}

class PlateView extends StatelessWidget {
  final String letters;
  final String digits;
  final double scale;
  const PlateView({
    super.key,
    required this.letters,
    required this.digits,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final l = letters
        .split('')
        .where((c) => c.trim().isNotEmpty)
        .join(' ');
    final style = TextStyle(
        fontSize: 26 * scale, fontWeight: FontWeight.bold, color: Colors.black);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 4 * scale),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9800),
          border: Border.all(color: Colors.black, width: 2 * scale),
          borderRadius: BorderRadius.circular(8 * scale),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('مصر',
              style: TextStyle(
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          // RTL row: letters on the right, digits on the left.
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(l.isEmpty ? '- - -' : l, style: style),
            SizedBox(width: 14 * scale),
            Text(digits.isEmpty ? '----' : toArabicDigits(digits), style: style),
          ]),
        ]),
      ),
    );
  }
}
