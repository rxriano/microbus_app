import 'dart:convert';
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

// Arabic-Indic / Persian digits -> Latin (for storage and validation).
String toLatinDigits(String s) {
  const east = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  return s.split('').map((c) {
    var i = east.indexOf(c);
    if (i < 0) i = persian.indexOf(c);
    return i < 0 ? c : '$i';
  }).join();
}

class AvatarView extends StatelessWidget {
  final String photoB64;
  final double radius;
  const AvatarView({super.key, required this.photoB64, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    ImageProvider? img;
    if (photoB64.isNotEmpty) {
      try {
        img = MemoryImage(base64Decode(photoB64));
      } catch (_) {
        img = null;
      }
    }
    return CircleAvatar(
      radius: radius,
      backgroundImage: img,
      child: img == null ? Icon(Icons.person, size: radius) : null,
    );
  }
}