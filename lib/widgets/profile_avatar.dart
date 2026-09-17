import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class ProfileAvatarData {
  final int skin;
  final int hair;
  final int shirt;
  final int eyes;
  final int accessory;
  const ProfileAvatarData({this.skin = 2, this.hair = 1, this.shirt = 0, this.eyes = 0, this.accessory = 0});

  static const skinsForUi = ['Light','Warm','Tan','Deep','Rich'];
  static const hairsForUi = ['Black','Brown','Golden','Blonde','Violet','Cyan'];
  static const shirtsForUi = ['Cyan','Pink','Lime','Orange','Purple','Mint'];

  static const presets = <ProfileAvatarPreset>[
    ProfileAvatarPreset('Cool', ProfileAvatarData(skin: 1, hair: 5, shirt: 0, eyes: 1, accessory: 0)),
    ProfileAvatarPreset('Neon', ProfileAvatarData(skin: 2, hair: 4, shirt: 1, eyes: 0, accessory: 1)),
    ProfileAvatarPreset('Pro', ProfileAvatarData(skin: 0, hair: 0, shirt: 2, eyes: 1, accessory: 2)),
    ProfileAvatarPreset('Cosmic', ProfileAvatarData(skin: 3, hair: 5, shirt: 4, eyes: 0, accessory: 1)),
    ProfileAvatarPreset('Chill', ProfileAvatarData(skin: 4, hair: 2, shirt: 5, eyes: 0, accessory: 0)),
    ProfileAvatarPreset('Bold', ProfileAvatarData(skin: 2, hair: 3, shirt: 3, eyes: 1, accessory: 2)),
  ];

  String encode() => 'avatar:v1:${jsonEncode({'s': skin, 'h': hair, 'c': shirt, 'e': eyes, 'a': accessory})}';
  static ProfileAvatarData? decode(String value) {
    if (!value.startsWith('avatar:v1:')) return null;
    try {
      final m = jsonDecode(value.substring(10)) as Map<String, dynamic>;
      return ProfileAvatarData(
        skin: (m['s'] as num?)?.toInt() ?? 2,
        hair: (m['h'] as num?)?.toInt() ?? 1,
        shirt: (m['c'] as num?)?.toInt() ?? 0,
        eyes: (m['e'] as num?)?.toInt() ?? 0,
        accessory: (m['a'] as num?)?.toInt() ?? 0,
      );
    } catch (_) { return null; }
  }
}

class ProfileAvatarPreset {
  final String name;
  final ProfileAvatarData value;
  const ProfileAvatarPreset(this.name, this.value);
}

class ProfileAvatar extends StatelessWidget {
  final String value;
  final double size;
  const ProfileAvatar({super.key, required this.value, this.size = 72});

  @override
  Widget build(BuildContext context) {
    if (value.startsWith('image:')) {
      final path = value.substring(6);
      return ClipOval(child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(context)));
    }
    final data = ProfileAvatarData.decode(value);
    if (data != null) {
      return CustomPaint(size: Size.square(size), painter: _AvatarPainter(data, Theme.of(context).colorScheme));
    }
    return Container(width: size, height: size, alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.secondaryContainer])),
      child: Text(value.isEmpty ? '✨' : value, style: TextStyle(fontSize: size * .48)));
  }

  Widget _fallback(BuildContext context) => Container(width: size, height: size, alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primaryContainer),
    child: Icon(Icons.person_rounded, size: size * .5));
}

class _AvatarPainter extends CustomPainter {
  final ProfileAvatarData data;
  final ColorScheme cs;
  _AvatarPainter(this.data, this.cs);

  static const skins = [Color(0xFFF6C7A8), Color(0xFFE7A97A), Color(0xFFC98252), Color(0xFF8F5638), Color(0xFF5F3729)];
  static const hairs = [Color(0xFF17131A), Color(0xFF4B2E20), Color(0xFF8C5A2B), Color(0xFFE0A53A), Color(0xFF7B4DFF), Color(0xFF00CFE8)];
  static const shirts = [Color(0xFF27E7FF), Color(0xFFFF4FD8), Color(0xFFB6FF3B), Color(0xFFFF9F43), Color(0xFF8B6CFF), Color(0xFF00F5A0)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = Offset(size.width / 2, size.height / 2);
    final bg = Paint()..color = cs.surfaceContainerHighest;
    canvas.drawCircle(c, s * .49, bg);

    final shirt = Paint()..color = shirts[data.shirt.clamp(0, shirts.length - 1).toInt()];
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s*.18, s*.62, s*.64, s*.40), Radius.circular(s*.18)), shirt);

    final skin = Paint()..color = skins[data.skin.clamp(0, skins.length - 1).toInt()];
    canvas.drawCircle(Offset(c.dx, s*.46), s*.25, skin);

    final hair = Paint()..color = hairs[data.hair.clamp(0, hairs.length - 1).toInt()];
    final hairPath = Path()
      ..moveTo(s*.25, s*.39)
      ..quadraticBezierTo(s*.28, s*.12, s*.50, s*.15)
      ..quadraticBezierTo(s*.75, s*.12, s*.78, s*.39)
      ..quadraticBezierTo(s*.67, s*.30, s*.50, s*.33)
      ..quadraticBezierTo(s*.34, s*.30, s*.25, s*.39)
      ..close();
    canvas.drawPath(hairPath, hair);

    final eye = Paint()..color = const Color(0xFF16151A);
    final eyeY = s*.46;
    canvas.drawCircle(Offset(s*.41, eyeY), s*.028, eye);
    canvas.drawCircle(Offset(s*.59, eyeY), s*.028, eye);
    final mouth = Paint()..color = const Color(0xFF6F3040)..style = PaintingStyle.stroke..strokeWidth = s*.018..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(s*.43, s*.49, s*.14, s*.10), .15, 2.8, false, mouth);

    if (data.eyes == 1) {
      final glasses = Paint()..color = const Color(0xFF20222B)..style = PaintingStyle.stroke..strokeWidth = s*.025;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s*.34, s*.42, s*.15, s*.10), Radius.circular(s*.03)), glasses);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s*.51, s*.42, s*.15, s*.10), Radius.circular(s*.03)), glasses);
      canvas.drawLine(Offset(s*.49,s*.47), Offset(s*.51,s*.47), glasses);
    }
    if (data.accessory == 1) {
      final star = Paint()..color = const Color(0xFFFFD166);
      canvas.drawCircle(Offset(s*.72, s*.24), s*.07, star);
    } else if (data.accessory == 2) {
      final cap = Paint()..color = const Color(0xFFFF4FD8);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s*.29,s*.11,s*.42,s*.12), Radius.circular(s*.06)), cap);
      canvas.drawRect(Rect.fromLTWH(s*.23,s*.20,s*.54,s*.035), cap);
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) => old.data != data || old.cs != cs;
}
