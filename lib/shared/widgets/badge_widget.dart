import 'package:flutter/material.dart';

class BadgeWidget extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;

  const BadgeWidget({
    super.key,
    required this.label,
    this.color,
    this.textColor,
  });

  factory BadgeWidget.pending() => const BadgeWidget(
    label: 'Pending',
    color: Color(0x33FFD166),
    textColor: Color(0xFFFFD166),
  );

  factory BadgeWidget.settled() => const BadgeWidget(
    label: 'Settled',
    color: Color(0x3334D399),
    textColor: Color(0xFF34D399),
  );

  factory BadgeWidget.settlementRequested() => const BadgeWidget(
    label: 'Requested',
    color: Color(0x33126CDE),
    textColor: Color(0xFF126CDE),
  );

  factory BadgeWidget.youOwe() => const BadgeWidget(
    label: 'You owe',
    color: Color(0x33EF4444),
    textColor: Color(0xFFEF4444),
  );

  factory BadgeWidget.theyOwe() => const BadgeWidget(
    label: 'They owe',
    color: Color(0x3306D6A0),
    textColor: Color(0xFF06D6A0),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF2E2E42) : Colors.grey.shade200;
    final defaultText = isDark ? const Color(0xFF9E9EB8) : Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? defaultBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor ?? defaultText,
        ),
      ),
    );
  }
}
