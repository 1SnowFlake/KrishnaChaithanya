import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/models/report_models.dart';

/// Renders a responsive attendance trend chart over time using fl_chart.
class AttendanceTrendChart extends StatelessWidget {
  final List<DailyAttendanceTrend> trends;
  final double threshold;

  const AttendanceTrendChart({
    super.key,
    required this.trends,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (trends.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart_rounded, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 8),
            Text(
              'No attendance trends recorded for this range',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < trends.length; i++) {
      spots.add(FlSpot(i.toDouble(), trends[i].attendancePercentage));
    }

    // Interval calculation to keep date labels readable
    final double dateInterval = trends.length > 7 ? (trends.length / 5).ceilToDouble() : 1.0;

    return Container(
      height: 250,
      padding: const EdgeInsets.only(top: 20, right: 18, left: 8, bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (trends.length - 1).toDouble().clamp(0.0, double.infinity),
          minY: 0,
          maxY: 100,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: 25,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: dateInterval,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < trends.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        trends[index].formattedDate,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: threshold,
                color: Colors.amber.shade700,
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 6, bottom: 2),
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  labelResolver: (_) => 'Threshold: ${threshold.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < trends.length) {
                    final item = trends[index];
                    return LineTooltipItem(
                      '${item.formattedDate}\n',
                      TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      children: [
                        TextSpan(
                          text: '${spot.y.toStringAsFixed(1)}% Attendance\n',
                          style: TextStyle(
                            color: spot.y >= threshold ? Colors.lightGreenAccent : Colors.orangeAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: 'Present: ${item.presentCount} | Absent: ${item.absentCount}',
                          style: TextStyle(
                            color: theme.colorScheme.onInverseSurface.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: theme.colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: trends.length <= 15,
                getDotPainter: (spot, percent, barData, index) {
                  final isBelow = spot.y < threshold;
                  return FlDotCirclePainter(
                    radius: 4,
                    color: isBelow ? Colors.amber.shade700 : theme.colorScheme.primary,
                    strokeWidth: 2,
                    strokeColor: theme.colorScheme.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.25),
                    theme.colorScheme.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
