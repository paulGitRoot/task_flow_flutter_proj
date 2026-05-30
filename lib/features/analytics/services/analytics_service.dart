import '../../tasks/models/task_model.dart';

class AnalyticsService {
  // Takes a list of ALL user tasks and returns computed stats
  AnalyticsData compute(List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return AnalyticsData.empty();
    }

    final now = DateTime.now();
    final total = tasks.length;
    final completed = tasks.where((t) => t.isDone).length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    final completionRate = total == 0 ? 0.0 : (completed / total * 100);

    // ── Weekly completions (last 7 days) ──────────────────────────────
    // We don't store completedAt, so we approximate:
    // count tasks where isDone == true and createdAt is within last 7 days
    // For a real app you'd store completedAt — this is a good approximation
    final weekDays = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return DateTime(day.year, day.month, day.day);
    });

    final weeklyCompletions = weekDays.map((day) {
      return tasks.where((t) {
        if (!t.isDone) return false;
        final created = DateTime(
          t.createdAt.year,
          t.createdAt.month,
          t.createdAt.day,
        );
        return created == day;
      }).length;
    }).toList();

    // ── Best day of week (most completions) ──────────────────────────
    // Count completed tasks by weekday (1=Mon ... 7=Sun)
    final byWeekday = List.filled(8, 0); // index 1-7
    for (final task in tasks.where((t) => t.isDone)) {
      byWeekday[task.createdAt.weekday]++;
    }
    int bestWeekdayIndex = 1;
    for (int i = 2; i <= 7; i++) {
      if (byWeekday[i] > byWeekday[bestWeekdayIndex]) {
        bestWeekdayIndex = i;
      }
    }
    final weekdayNames = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final bestDay = byWeekday[bestWeekdayIndex] == 0
        ? 'Not enough data'
        : weekdayNames[bestWeekdayIndex];

    // ── Priority breakdown ────────────────────────────────────────────
    final highCount = tasks.where((t) => t.priority == 'High').length;
    final medCount = tasks.where((t) => t.priority == 'Medium').length;
    final lowCount = tasks.where((t) => t.priority == 'Low').length;

    // ── Tasks due this week ───────────────────────────────────────────
    final endOfWeek = now.add(const Duration(days: 7));
    final dueSoon = tasks.where((t) {
      if (t.isDone || t.deadline == null) return false;
      return t.deadline!.isAfter(now) && t.deadline!.isBefore(endOfWeek);
    }).length;

    return AnalyticsData(
      total: total,
      completed: completed,
      overdue: overdue,
      completionRate: completionRate,
      weeklyCompletions: weeklyCompletions,
      weekDayLabels: weekDays.map((d) => _shortDay(d.weekday)).toList(),
      bestDay: bestDay,
      highPriority: highCount,
      medPriority: medCount,
      lowPriority: lowCount,
      dueSoonCount: dueSoon,
    );
  }

  String _shortDay(int weekday) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday];
  }
}

class AnalyticsData {
  final int total;
  final int completed;
  final int overdue;
  final double completionRate;
  final List<int> weeklyCompletions;
  final List<String> weekDayLabels;
  final String bestDay;
  final int highPriority;
  final int medPriority;
  final int lowPriority;
  final int dueSoonCount;

  const AnalyticsData({
    required this.total,
    required this.completed,
    required this.overdue,
    required this.completionRate,
    required this.weeklyCompletions,
    required this.weekDayLabels,
    required this.bestDay,
    required this.highPriority,
    required this.medPriority,
    required this.lowPriority,
    required this.dueSoonCount,
  });

  factory AnalyticsData.empty() => const AnalyticsData(
    total: 0,
    completed: 0,
    overdue: 0,
    completionRate: 0,
    weeklyCompletions: [0, 0, 0, 0, 0, 0, 0],
    weekDayLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    bestDay: 'Not enough data',
    highPriority: 0,
    medPriority: 0,
    lowPriority: 0,
    dueSoonCount: 0,
  );
}
