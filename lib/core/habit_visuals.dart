import 'dart:convert';

import 'package:flutter/material.dart';

class HabitVisuals {
  // Custom symbols are persisted as ASCII hex so emoji/surrogate pairs can
  // never break JSON/Hive persistence on older Android runtimes.
  static String encodeCustom(String value) {
    final normalized = value.trim();
    return 'customcp:${normalized.runes.map((r) => r.toRadixString(16)).join('-')}';
  }

  static String decodeCustom(String value) {
    if (value.startsWith('emoji:')) return value.substring(6);
    if (value.startsWith('customcp:')) {
      try {
        return String.fromCharCodes(
          value.substring(9).split('-').where((e) => e.isNotEmpty).map((e) => int.parse(e, radix: 16)),
        );
      } catch (_) {
        return '★';
      }
    }
    if (value.startsWith('custom64:')) {
      try {
        return utf8.decode(base64Url.decode(value.substring(9)));
      } catch (_) {
        return '★';
      }
    }
    if (!value.startsWith('custom:')) return value;
    // Backwards compatibility with the earlier hex representation.
    try {
      return String.fromCharCodes(
        value.substring(7).split('-').where((e) => e.isNotEmpty)
            .map((e) => int.parse(e, radix: 16)),
      );
    } catch (_) {
      return '★';
    }
  }

  static bool isCustom(String value) =>
      value.startsWith('custom:') || value.startsWith('custom64:') || value.startsWith('customcp:') || value.startsWith('emoji:');

  static const Map<String, IconData> icons = {
    'check': Icons.check_circle_rounded,
    'water': Icons.water_drop_rounded,
    'book': Icons.menu_book_rounded,
    'fitness': Icons.fitness_center_rounded,
    'meditate': Icons.self_improvement_rounded,
    'sleep': Icons.bedtime_rounded,
    'work': Icons.work_outline_rounded,
    'heart': Icons.favorite_rounded,
    'walk': Icons.directions_walk_rounded,
    'run': Icons.directions_run_rounded,
    'music': Icons.music_note_rounded,
    'code': Icons.code_rounded,
    'school': Icons.school_rounded,
    'food': Icons.restaurant_rounded,
    'coffee': Icons.local_cafe_rounded,
    'sun': Icons.wb_sunny_rounded,
    'star': Icons.star_rounded,
    'bolt': Icons.bolt_rounded,
    'selfcare': Icons.spa_rounded,
    'journal': Icons.edit_note_rounded,
    'phone': Icons.phone_android_rounded,
    'money': Icons.savings_rounded,
    'language': Icons.language_rounded,
    'brush': Icons.brush_rounded,
    'camera': Icons.camera_alt_rounded,
    'pets': Icons.pets_rounded,
    'garden': Icons.local_florist_rounded,
    'home': Icons.home_rounded,
    'directions': Icons.directions_rounded,
    'timer': Icons.timer_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'sports': Icons.sports_rounded,
    'pool': Icons.pool_rounded,
    'bike': Icons.directions_bike_rounded,
    'laptop': Icons.laptop_mac_rounded,
    'email': Icons.email_rounded,
    'group': Icons.groups_rounded,
    'checklist': Icons.checklist_rounded,
  };

  static const List<int> palette = [
    0xFF27E7FF, 0xFFFF4FD8, 0xFFB6FF3B, 0xFFFF9F43,
    0xFF7CFFCB, 0xFFFF6B9A, 0xFFB86BFF, 0xFF4DA6FF,
    0xFFFFD166, 0xFF00F5A0, 0xFF00BBF9, 0xFFF15BB5,
    0xFF9BFF00, 0xFFFF7A00, 0xFF00E5FF, 0xFFFF3CAC,
  ];

  static Widget icon(
    String value, {
    double size = 24,
    Color? color,
  }) {
    if (value.startsWith('custom:') || value.startsWith('custom64:') || value.startsWith('customcp:')) {
      return Text(
        decodeCustom(value),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size * .9, height: 1),
      );
    }
    if (value.startsWith('emoji:')) {
      return Text(
        value.substring(6),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size * .9, height: 1),
      );
    }
    return Icon(
      icons[value] ?? Icons.check_circle_rounded,
      size: size,
      color: color,
    );
  }

  static Widget picker({
    required BuildContext context,
    required String selectedIcon,
    required ValueChanged<String> onIconChanged,
    required VoidCallback onCustom,
    required int selectedColor,
    required ValueChanged<int> onColorChanged,
  }) {
    final theme = Theme.of(context);
    const featured = [
      ('check', 'Done'),
      ('water', 'Water'),
      ('fitness', 'Fitness'),
      ('book', 'Read'),
      ('meditate', 'Mind'),
      ('sleep', 'Sleep'),
      ('walk', 'Walk'),
      ('heart', 'Health'),
      ('work', 'Work'),
      ('music', 'Music'),
      ('food', 'Food'),
      ('sun', 'Morning'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Style your habit',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Pick a simple visual identity you will recognize at a glance.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(selectedColor).withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: icon(selectedIcon, size: 25, color: Color(selectedColor)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isCustom(selectedIcon) ? 'Custom icon' : 'Selected icon',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCustom,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Custom'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Popular', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: featured.map((item) {
                  final key = item.$1;
                  final selected = selectedIcon == key;
                  return Tooltip(
                    message: item.$2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onIconChanged(key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selected
                              ? Color(selectedColor)
                              : theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? Color(selectedColor)
                                : theme.colorScheme.outlineVariant,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: icon(
                          key,
                          size: 22,
                          color: selected
                              ? Colors.white
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text('Color', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  final picked = await showDialog<int>(
                    context: context,
                    builder: (_) => _ColorGridDialog(selectedColor: selectedColor),
                  );
                  if (picked != null) onColorChanged(picked);
                },
                child: Container(
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [
                        Colors.red, Colors.orange, Colors.yellow,
                        Colors.green, Colors.cyan, Colors.blue,
                        Colors.indigo, Colors.purple, Colors.pink,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .35),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Open full color panel',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: Color(selectedColor),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Selected color',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class _ColorGridDialog extends StatefulWidget {
  final int selectedColor;
  const _ColorGridDialog({required this.selectedColor});

  @override
  State<_ColorGridDialog> createState() => _ColorGridDialogState();
}

class _ColorGridDialogState extends State<_ColorGridDialog> {
  late HSVColor hsv;

  @override
  void initState() {
    super.initState();
    hsv = HSVColor.fromColor(Color(widget.selectedColor));
  }

  void _selectAt(Offset local, Size size) {
    final saturation = (local.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - local.dy / size.height).clamp(0.0, 1.0);
    setState(() {
      hsv = hsv.withSaturation(saturation).withValue(value);
    });
  }

  void _selectHue(Offset local, Size size) {
    final hue = (local.dx / size.width * 360).clamp(0.0, 360.0);
    setState(() => hsv = hsv.withHue(hue));
  }

  @override
  Widget build(BuildContext context) {
    final selected = hsv.toColor();
    return AlertDialog(
      title: const Text('Choose a color'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (_, constraints) {
                final size = Size(constraints.maxWidth, 190);
                return GestureDetector(
                  onPanDown: (d) => _selectAt(d.localPosition, size),
                  onPanUpdate: (d) => _selectAt(d.localPosition, size),
                  child: CustomPaint(
                    size: size,
                    painter: _ColorFieldPainter(hsv.hue),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (_, constraints) {
                final size = Size(constraints.maxWidth, 28);
                return GestureDetector(
                  onPanDown: (d) => _selectHue(d.localPosition, size),
                  onPanUpdate: (d) => _selectHue(d.localPosition, size),
                  child: CustomPaint(
                    size: size,
                    painter: _HuePainter(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '#${selected.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selected.toARGB32()),
          child: const Text('Use color'),
        ),
      ],
    );
  }
}

class _ColorFieldPainter extends CustomPainter {
  final double hue;
  _ColorFieldPainter(this.hue);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    canvas.drawRect(Offset.zero & size, base);

    final horizontal = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.white, Colors.transparent],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, horizontal);

    final vertical = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vertical);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black12;
    canvas.drawRect(Offset.zero & size, border);
  }

  @override
  bool shouldRepaint(covariant _ColorFieldPainter oldDelegate) =>
      oldDelegate.hue != hue;
}

class _HuePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shader = const LinearGradient(
      colors: [
        Colors.red,
        Colors.yellow,
        Colors.green,
        Colors.cyan,
        Colors.blue,
        Colors.purple,
        Colors.red,
      ],
    ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(10),
      ),
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _HuePainter oldDelegate) => false;
}
