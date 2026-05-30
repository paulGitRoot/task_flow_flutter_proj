import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_model.dart';
import '../../../../services/notification_service.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notifications = NotificationService();

  String get uid => _auth.currentUser!.uid;

  // Read reminder settings from SharedPreferences
  Future<Map<String, dynamic>> _getReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'type': prefs.getString('reminderType') ?? 'hours_before',
      'hours': prefs.getInt('reminderHours') ?? 1,
    };
  }

  // CREATE
  Future<void> addTask(TaskModel task) async {
    final doc = await _firestore.collection('tasks').add(task.toMap());

    // Schedule notification if task has a deadline
    if (task.deadline != null) {
      final settings = await _getReminderSettings();
      await _notifications.scheduleTaskReminder(
        notificationId: NotificationService.idFromTaskId(doc.id),
        taskTitle: task.title,
        deadline: task.deadline!,
        reminderType: settings['type'],
        hoursBeforeDeadline: settings['hours'],
      );
    }
  }

  // READ — streamed, sorted by priorityScore descending
  Stream<List<TaskModel>> getTasks() {
    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: uid)
        .orderBy('priorityScore', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return TaskModel.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  // UPDATE — toggle done/undone
  Future<void> toggleTask(String id, bool value) async {
    await _firestore.collection('tasks').doc(id).update({'isDone': value});
  }

  // UPDATE — full edit (reschedules notification with new deadline)
  Future<void> updateTask(TaskModel task) async {
    await _firestore.collection('tasks').doc(task.id).update(task.toMap());

    // Cancel old notification and reschedule if deadline exists
    final notifId = NotificationService.idFromTaskId(task.id);
    await _notifications.cancelTaskReminder(notifId);

    if (task.deadline != null && !task.isDone) {
      final settings = await _getReminderSettings();
      await _notifications.scheduleTaskReminder(
        notificationId: notifId,
        taskTitle: task.title,
        deadline: task.deadline!,
        reminderType: settings['type'],
        hoursBeforeDeadline: settings['hours'],
      );
    }
  }

  // DELETE — also cancels notification
  Future<void> deleteTask(String id) async {
    await _firestore.collection('tasks').doc(id).delete();
    await _notifications.cancelTaskReminder(
      NotificationService.idFromTaskId(id),
    );
  }
}

