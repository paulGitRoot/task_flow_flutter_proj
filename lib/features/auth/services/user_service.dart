import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save user profile on register
  Future<void> createUserProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'createdAt': DateTime.now(),
      'streakCount': 0,
      'lastCompletionDate': null,
    });
  }

  // Fetch user name
  Future<String?> getUserName(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return doc.data()?['name'] as String?;
    }
    return null;
  }

  // Update user name (also creates doc if it doesn't exist yet — fixes old accounts)
  Future<void> updateUserName({
    required String uid,
    required String name,
    required String email,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
    }, SetOptions(merge: true));
  }

  // Fetch full streak data: {streakCount, lastCompletionDate}
  Future<Map<String, dynamic>> getStreakData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return {'streakCount': 0, 'lastCompletionDate': null};
    final data = doc.data()!;
    return {
      'streakCount': data['streakCount'] ?? 0,
      'lastCompletionDate': data['lastCompletionDate'],
    };
  }

  // Called whenever a task is marked as done
  // Logic:
  //   - If last completion was today → do nothing (already counted)
  //   - If last completion was yesterday → increment streak
  //   - If last completion was older or null → reset streak to 1
  Future<int> updateStreak(String uid) async {
    final streakData = await getStreakData(uid);
    final int currentStreak = streakData['streakCount'] ?? 0;
    final lastCompletionTs = streakData['lastCompletionDate'];

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (lastCompletionTs != null) {
      final lastDate = (lastCompletionTs as dynamic).toDate() as DateTime;
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = todayDate.difference(lastDay).inDays;

      if (diff == 0) {
        // Already completed a task today — streak unchanged
        return currentStreak;
      } else if (diff == 1) {
        // Completed yesterday — continue streak
        final newStreak = currentStreak + 1;
        await _firestore.collection('users').doc(uid).set({
          'streakCount': newStreak,
          'lastCompletionDate': today,
        }, SetOptions(merge: true));
        return newStreak;
      }
    }

    // No previous completion or gap > 1 day — reset to 1
    await _firestore.collection('users').doc(uid).set({
      'streakCount': 1,
      'lastCompletionDate': today,
    }, SetOptions(merge: true));
    return 1;
  }
}

