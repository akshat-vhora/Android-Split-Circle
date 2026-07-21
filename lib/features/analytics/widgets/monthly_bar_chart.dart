import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../shared/utils/currency_formatter.dart';

class MonthlyBarChart extends StatelessWidget {
  final Map<DateTime, double> monthlyData;

  const MonthlyBarChart({
    super.key,
    required this.monthlyData,
  });

  @override
  Widget build(BuildContext context) {
    if (monthlyData.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No data')),
      );
    }

    final sortedKeys = monthlyData.keys.toList()..sort();
    final maxValue = monthlyData.values.reduce(
      (a, b) => a > b ? a : b,
    );

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                '${_formatMonth(sortedKeys[group.x])}\n${formatAmount(rod.toY)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= sortedKeys.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatMonth(sortedKeys[idx]),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, _) {
                  if (value == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      formatAmountCompact(value),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: sortedKeys.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: monthlyData[entry.value]!,
                  color: Theme.of(context).colorScheme.primary,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatMonth(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[date.month - 1];
  }
}
