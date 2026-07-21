import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../shared/utils/currency_formatter.dart';

class CategoryPieChart extends StatelessWidget {
  final Map<String, double> categoryData;

  const CategoryPieChart({
    super.key,
    required this.categoryData,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryData.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No data')),
      );
    }

    final total = categoryData.values.fold(0.0, (a, b) => a + b);
    final colors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      const Color(0xFFFFD166),
      const Color(0xFFEF4444),
      const Color(0xFF34D399),
      const Color(0xFF42A5F5),
      const Color(0xFFFF7043),
      const Color(0xFF78909C),
    ];

    final entries = categoryData.entries.toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: List.generate(entries.length, (idx) {
                final entry = entries[idx];
                return PieChartSectionData(
                  value: entry.value,
                  color: colors[idx % colors.length],
                  radius: 60,
                  title: '${(entry.value / total * 100).toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(entries.length, (idx) {
          final entry = entries[idx];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[idx % colors.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  formatAmount(entry.value),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
