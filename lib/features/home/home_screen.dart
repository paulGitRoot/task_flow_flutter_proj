import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/theme_provider.dart';
import '../tasks/models/task_model.dart';
import '../tasks/screens/add_task_screen.dart';
import '../tasks/screens/edit_task_screen.dart';
import '../tasks/services/task_service.dart';
import '../auth/services/user_service.dart';
import '../auth/screens/profile_screen.dart';
import '../analytics/screens/insights_screen.dart';
import 'widgets/suggestions_card.dart';

enum SortOption { priority, deadlineSoonest, recentlyAdded }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TaskService taskService = TaskService();
  final UserService userService = UserService();

  String activeFilter = 'All';
  SortOption activeSortOption = SortOption.priority;
  String? userName;
  int streakCount = 0;

  // Reminder settings
  String reminderType = 'hours_before';
  int reminderHours = 1;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadReminderSettings();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final results = await Future.wait([
      userService.getUserName(uid),
      userService.getStreakData(uid),
    ]);
    if (mounted) {
      setState(() {
        userName = results[0] as String?;
        streakCount = (results[1] as Map<String, dynamic>)['streakCount'] ?? 0;
      });
    }
  }

  Future<void> _loadUserName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final name = await userService.getUserName(uid);
    if (mounted) setState(() => userName = name);
  }

  Future<void> _loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        reminderType = prefs.getString('reminderType') ?? 'hours_before';
        reminderHours = prefs.getInt('reminderHours') ?? 1;
      });
    }
  }

  Future<void> _saveReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminderType', reminderType);
    await prefs.setInt('reminderHours', reminderHours);
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _onToggleTask(TaskModel task, bool value) async {
    await taskService.toggleTask(task.id, value);
    if (value) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final newStreak = await userService.updateStreak(uid);
        if (mounted) setState(() => streakCount = newStreak);
      }
    }
  }

  List<TaskModel> _applyFilter(List<TaskModel> tasks) {
    final now = DateTime.now();
    switch (activeFilter) {
      case 'Today':
        return tasks.where((t) {
          if (t.deadline == null) return false;
          final d = t.deadline!;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();
      case 'Pending':
        return tasks.where((t) => !t.isDone).toList();
      case 'Completed':
        return tasks.where((t) => t.isDone).toList();
      default:
        return tasks;
    }
  }

  List<TaskModel> _applySort(List<TaskModel> tasks) {
    final sorted = List<TaskModel>.from(tasks);
    switch (activeSortOption) {
      case SortOption.priority:
        sorted.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
        break;
      case SortOption.deadlineSoonest:
        sorted.sort((a, b) {
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          return a.deadline!.compareTo(b.deadline!);
        });
        break;
      case SortOption.recentlyAdded:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return sorted;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const ListTile(
              title: Text(
                'Sort By',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            _SortOptionTile(
              label: 'Priority',
              icon: Icons.flag_outlined,
              selected: activeSortOption == SortOption.priority,
              onTap: () {
                setState(() => activeSortOption = SortOption.priority);
                Navigator.pop(context);
              },
            ),
            _SortOptionTile(
              label: 'Deadline (soonest first)',
              icon: Icons.schedule_outlined,
              selected: activeSortOption == SortOption.deadlineSoonest,
              onTap: () {
                setState(() => activeSortOption = SortOption.deadlineSoonest);
                Navigator.pop(context);
              },
            ),
            _SortOptionTile(
              label: 'Recently Added',
              icon: Icons.access_time_outlined,
              selected: activeSortOption == SortOption.recentlyAdded,
              onTap: () {
                setState(() => activeSortOption = SortOption.recentlyAdded);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Reminder settings bottom sheet
  void _showReminderSettings() {
    // Local copies for the sheet's setState
    String tempType = reminderType;
    int tempHours = reminderHours;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reminder Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Type selector
                const Text(
                  'Notify me:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                _ReminderOptionTile(
                  label: 'X hours before deadline',
                  selected: tempType == 'hours_before',
                  onTap: () => setSheetState(() => tempType = 'hours_before'),
                ),
                _ReminderOptionTile(
                  label: 'Morning of the deadline (8:00 AM)',
                  selected: tempType == 'morning_of',
                  onTap: () => setSheetState(() => tempType = 'morning_of'),
                ),

                // Hours selector (only shown when hours_before selected)
                if (tempType == 'hours_before') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'How many hours before?',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [1, 2, 3, 6, 12, 24].map((h) {
                      final selected = tempHours == h;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setSheetState(() => tempHours = h),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey.shade400,
                              ),
                            ),
                            child: Text(
                              '${h}h',
                              style: TextStyle(
                                color: selected ? Colors.white : null,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        reminderType = tempType;
                        reminderHours = tempHours;
                      });
                      await _saveReminderSettings();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Reminder settings saved'),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  String _formatDeadline(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $hour:$minute';
  }

  String get _sortLabel {
    switch (activeSortOption) {
      case SortOption.priority:
        return 'Priority';
      case SortOption.deadlineSoonest:
        return 'Deadline';
      case SortOption.recentlyAdded:
        return 'Recent';
    }
  }

  void _showTaskOptions(BuildContext context, TaskModel task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Task'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditTaskScreen(task: task)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Delete Task',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteWithUndo(task);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _deleteWithUndo(TaskModel task) {
    taskService.deleteTask(task.id);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${task.title}" deleted'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () => taskService.addTask(task),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskFlow+'),
        actions: [
          // Sort button
          TextButton.icon(
            onPressed: _showSortOptions,
            icon: const Icon(Icons.sort, size: 18),
            label: Text(_sortLabel, style: const TextStyle(fontSize: 12)),
          ),
          // Insights button
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: 'Insights',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InsightsScreen()),
            ),
          ),
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),

      // ── Drawer ──────────────────────────────────────────────────────
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // Tappable profile header
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProfileScreen(onNameUpdated: _loadUserName),
                    ),
                  );
                },
                child: UserAccountsDrawerHeader(
                  margin: EdgeInsets.zero,
                  accountName: Row(
                    children: [
                      Text(
                        userName ?? 'Tap to set your name',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 14, color: Colors.white70),
                    ],
                  ),
                  accountEmail: Text(user?.email ?? ''),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      (userName != null && userName!.isNotEmpty)
                          ? userName![0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),

              // 🔥 Streak
              ListTile(
                leading: const Text('🔥', style: TextStyle(fontSize: 22)),
                title: Text(
                  streakCount == 0
                      ? 'No streak yet'
                      : '$streakCount day streak!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  streakCount == 0
                      ? 'Complete a task to start your streak'
                      : 'Keep it up — complete a task today!',
                  style: const TextStyle(fontSize: 12),
                ),
              ),

              const Divider(),

              // Insights
              ListTile(
                leading: const Icon(Icons.insights),
                title: const Text('Productivity Insights'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => InsightsScreen()),
                  );
                },
              ),

              // Reminder settings
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Reminder Settings'),
                subtitle: Text(
                  reminderType == 'morning_of'
                      ? 'Morning of deadline'
                      : '${reminderHours}h before deadline',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReminderSettings();
                },
              ),

              // Dark mode
              SwitchListTile(
                secondary: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                ),
                title: const Text('Dark Mode'),
                subtitle: Text(themeProvider.isDarkMode ? 'On' : 'Off'),
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
              ),

              const Divider(),

              // About
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About TaskFlow+'),
                onTap: () {
                  Navigator.pop(context);
                  showAboutDialog(
                    context: context,
                    applicationName: 'TaskFlow+',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.task_alt, size: 40),
                    children: const [
                      Text(
                        'A smart task manager with priority sorting, '
                        'deadline tracking, reminders, and productivity insights.',
                      ),
                    ],
                  );
                },
              ),

              const Spacer(),
              const Divider(),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: logout,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTaskScreen()),
        ),
        child: const Icon(Icons.add),
      ),

      body: StreamBuilder<List<TaskModel>>(
        stream: taskService.getTasks(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTasks = snapshot.data!;
          final filtered = _applySort(_applyFilter(allTasks));

          final total = allTasks.length;
          final completed = allTasks.where((t) => t.isDone).length;
          final pending = allTasks.where((t) => !t.isDone).length;
          final overdue = allTasks.where((t) => t.isOverdue).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'Hello, ${userName ?? user?.email ?? ''}! 👋',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Dashboard cards
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _DashCard(label: 'Total', value: total, color: Colors.blue),
                    const SizedBox(width: 8),
                    _DashCard(
                      label: 'Done',
                      value: completed,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _DashCard(
                      label: 'Pending',
                      value: pending,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _DashCard(
                      label: 'Overdue',
                      value: overdue,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: ['All', 'Today', 'Pending', 'Completed']
                      .map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(f),
                            selected: activeFilter == f,
                            onSelected: (_) => setState(() => activeFilter = f),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              const SizedBox(height: 10),

              // Smart suggestions card
              SuggestionsCard(tasks: allTasks),

              // Task list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          activeFilter == 'All'
                              ? 'No tasks yet. Add one!'
                              : 'No $activeFilter tasks.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemBuilder: (context, index) {
                          final task = filtered[index];
                          return Dismissible(
                            key: ValueKey(task.id),
                            background: _SwipeBackground(
                              alignment: Alignment.centerLeft,
                              color: Colors.green,
                              icon: Icons.check_circle_outline,
                              label: task.isDone ? 'Undo' : 'Complete',
                            ),
                            secondaryBackground: _SwipeBackground(
                              alignment: Alignment.centerRight,
                              color: Colors.red,
                              icon: Icons.delete_outline,
                              label: 'Delete',
                            ),
                            dismissThresholds: const {
                              DismissDirection.startToEnd: 0.4,
                              DismissDirection.endToStart: 0.4,
                            },
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                await _onToggleTask(task, !task.isDone);
                                return false;
                              }
                              return true;
                            },
                            onDismissed: (_) => _deleteWithUndo(task),
                            child: _TaskTile(
                              task: task,
                              priorityColor: _priorityColor(task.priority),
                              formatDeadline: _formatDeadline,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditTaskScreen(task: task),
                                ),
                              ),
                              onLongPress: () =>
                                  _showTaskOptions(context, task),
                              onToggle: (value) =>
                                  _onToggleTask(task, value ?? false),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Reminder Option Tile ───────────────────────────────────────────────────

class _ReminderOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReminderOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Theme.of(context).primaryColor : null,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ── Swipe Background ───────────────────────────────────────────────────────

class _SwipeBackground extends StatelessWidget {
  final AlignmentGeometry alignment;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            : [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }
}

// ── Sort Option Tile ───────────────────────────────────────────────────────

class _SortOptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: selected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Theme.of(context).primaryColor : null,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check, color: Theme.of(context).primaryColor)
          : null,
      onTap: onTap,
    );
  }
}

// ── Dashboard Card ─────────────────────────────────────────────────────────

class _DashCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _DashCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Task Tile ──────────────────────────────────────────────────────────────

class _TaskTile extends StatelessWidget {
  final TaskModel task;
  final Color priorityColor;
  final String Function(DateTime) formatDeadline;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool?> onToggle;

  const _TaskTile({
    required this.task,
    required this.priorityColor,
    required this.formatDeadline,
    required this.onTap,
    required this.onLongPress,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: priorityColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: task.isDone ? TextDecoration.lineThrough : null,
                  color: task.isDone ? Colors.grey : null,
                ),
              ),
            ),
            if (isOverdue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Overdue',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(
                task.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            if (task.deadline != null)
              Text(
                '⏰ ${formatDeadline(task.deadline!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isOverdue ? Colors.red : Colors.grey.shade600,
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
          ],
        ),
        trailing: Checkbox(
          value: task.isDone,
          activeColor: Colors.green,
          onChanged: onToggle,
        ),
      ),
    );
  }
}
