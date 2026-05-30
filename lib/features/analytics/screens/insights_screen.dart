import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../tasks/models/task_model.dart';
import '../../tasks/services/task_service.dart';
import '../services/analytics_service.dart';

class InsightsScreen extends StatelessWidget {
  InsightsScreen({super.key});

  final TaskService taskService = TaskService();
  final AnalyticsService analyticsService = AnalyticsService();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text('Productivity Insights')),
      body: StreamBuilder<List<TaskModel>>(
        stream: taskService.getTasks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = analyticsService.compute(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary row ─────────────────────────────────────
                Row(
                  children: [
                    _StatCard(
                      label: 'Completion Rate',
                      value: '${data.completionRate.toStringAsFixed(0)}%',
                      icon: Icons.percent,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Best Day',
                      value: data.bestDay,
                      icon: Icons.star_outline,
                      color: Colors.amber,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    _StatCard(
                      label: 'Due This Week',
                      value: '${data.dueSoonCount}',
                      icon: Icons.upcoming_outlined,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _StatCard(
                      label: 'Overdue',
                      value: '${data.overdue}',
                      icon: Icons.warning_amber_outlined,
                      color: Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Weekly bar chart ─────────────────────────────────
                _SectionTitle('Tasks Completed — Last 7 Days'),
                const SizedBox(height: 12),
                _WeeklyBarChart(
                  completions: data.weeklyCompletions,
                  labels: data.weekDayLabels,
                ),

                const SizedBox(height: 24),

                // ── Priority breakdown ───────────────────────────────
                _SectionTitle('Priority Breakdown'),
                const SizedBox(height: 12),
                _PriorityBar(
                  label: 'High',
                  count: data.highPriority,
                  total: data.total,
                  color: Colors.red,
                ),
                const SizedBox(height: 8),
                _PriorityBar(
                  label: 'Medium',
                  count: data.medPriority,
                  total: data.total,
                  color: Colors.orange,
                ),
                const SizedBox(height: 8),
                _PriorityBar(
                  label: 'Low',
                  count: data.lowPriority,
                  total: data.total,
                  color: Colors.green,
                ),

                const SizedBox(height: 24),

                // ── Completion progress ──────────────────────────────
                _SectionTitle('Overall Progress'),
                const SizedBox(height: 12),
                _ProgressCard(completed: data.completed, total: data.total),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Section title ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }
}

// ── Stat card (top summary) ────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Weekly bar chart ───────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final List<int> completions;
  final List<String> labels;

  const _WeeklyBarChart({required this.completions, required this.labels});

  @override
  Widget build(BuildContext context) {
    final maxY = (completions.reduce((a, b) => a > b ? a : b)).toDouble();
    final chartMax = maxY < 1 ? 4.0 : (maxY + 1);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      height: 180,
      padding: const EdgeInsets.only(top: 12, right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: completions.every((c) => c == 0)
          ? Center(
              child: Text(
                'Complete tasks to see your chart',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          : BarChart(
              BarChartData(
                maxY: chartMax,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            labels[index],
                            style: TextStyle(fontSize: 10, color: labelColor),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 != 0) return const SizedBox();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 10, color: labelColor),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(completions.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: completions[i].toDouble(),
                        color: Theme.of(context).primaryColor,
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
    );
  }
}

// ── Priority bar ───────────────────────────────────────────────────────────

class _PriorityBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _PriorityBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : count / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Text(
              '$count task${count == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Overall progress card ──────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;

  const _ProgressCard({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed of $total tasks completed',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${(ratio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: Colors.green.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}
