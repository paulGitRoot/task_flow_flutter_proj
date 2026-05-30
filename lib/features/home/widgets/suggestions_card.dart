import 'package:flutter/material.dart';
import '../../tasks/models/task_model.dart';

class SuggestionsCard extends StatelessWidget {
  final List<TaskModel> tasks;

  const SuggestionsCard({super.key, required this.tasks});

  // Generate smart suggestions from real task data
  List<_Suggestion> _buildSuggestions() {
    final suggestions = <_Suggestion>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pending = tasks.where((t) => !t.isDone).toList();
    final overdue = tasks.where((t) => t.isOverdue).toList();
    final dueToday = pending.where((t) {
      if (t.deadline == null) return false;
      final d = t.deadline!;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).toList();
    final highPending = pending.where((t) => t.priority == 'High').toList();
    final noDeadline = pending.where((t) => t.deadline == null).toList();
    final dueSoon = pending.where((t) {
      if (t.deadline == null) return false;
      final diff = t.deadline!.difference(now).inHours;
      return diff > 0 && diff <= 24;
    }).toList();

    // Overdue tasks
    if (overdue.isNotEmpty) {
      suggestions.add(
        _Suggestion(
          icon: Icons.warning_amber_rounded,
          color: Colors.red,
          text:
              'You have ${overdue.length} overdue task${overdue.length > 1 ? 's' : ''}. '
              'Consider rescheduling or completing ${overdue.length == 1 ? 'it' : 'them'} first.',
        ),
      );
    }

    // Due today
    if (dueToday.isNotEmpty) {
      suggestions.add(
        _Suggestion(
          icon: Icons.today,
          color: Colors.orange,
          text:
              '${dueToday.length} task${dueToday.length > 1 ? 's are' : ' is'} due today. '
              'Focus on ${dueToday.length == 1 ? '"${dueToday.first.title}"' : 'these first'} to stay on track.',
        ),
      );
    }

    // Due within 24 hours
    if (dueSoon.isNotEmpty && dueToday.isEmpty) {
      suggestions.add(
        _Suggestion(
          icon: Icons.schedule,
          color: Colors.deepOrange,
          text:
              '"${dueSoon.first.title}" is due within 24 hours. '
              'Make sure to set aside time for it.',
        ),
      );
    }

    // High priority backlog
    if (highPending.length >= 3) {
      suggestions.add(
        _Suggestion(
          icon: Icons.flag,
          color: Colors.red.shade700,
          text:
              'You have ${highPending.length} high-priority tasks pending. '
              'Try to complete at least one today.',
        ),
      );
    }

    // Tasks with no deadline
    if (noDeadline.length >= 3) {
      suggestions.add(
        _Suggestion(
          icon: Icons.calendar_today,
          color: Colors.purple,
          text:
              '${noDeadline.length} tasks have no deadline. '
              'Adding deadlines helps you plan better.',
        ),
      );
    }

    // All clear
    if (suggestions.isEmpty && pending.isEmpty) {
      suggestions.add(
        _Suggestion(
          icon: Icons.celebration,
          color: Colors.green,
          text:
              'All tasks completed! Great job. Add new tasks to keep your momentum going.',
        ),
      );
    } else if (suggestions.isEmpty) {
      suggestions.add(
        _Suggestion(
          icon: Icons.thumb_up_alt_outlined,
          color: Colors.blue,
          text:
              "You're on track! Keep working through your ${pending.length} pending task${pending.length > 1 ? 's' : ''}.",
        ),
      );
    }

    // Return only top 2 suggestions max to keep card compact
    return suggestions.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _buildSuggestions();
    if (suggestions.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade800
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: 6),
              const Text(
                'Smart Suggestions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...suggestions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(s.icon, size: 16, color: s.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.text,
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Suggestion {
  final IconData icon;
  final Color color;
  final String text;

  const _Suggestion({
    required this.icon,
    required this.color,
    required this.text,
  });
}
