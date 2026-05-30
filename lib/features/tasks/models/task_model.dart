class TaskModel {
  final String id;
  final String title;
  final String description;
  final String priority;
  final int priorityScore;
  final bool isDone;
  final DateTime createdAt;
  final DateTime? deadline;
  final String userId;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.priorityScore,
    required this.isDone,
    required this.createdAt,
    this.deadline,
    required this.userId,
  });

  bool get isOverdue {
    if (deadline == null) return false;
    return !isDone && deadline!.isBefore(DateTime.now());
  }

  // Useful for edit screen — copy with changed fields
  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? priority,
    int? priorityScore,
    bool? isDone,
    DateTime? createdAt,
    DateTime? deadline,
    bool clearDeadline = false,
    String? userId,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      priorityScore: priorityScore ?? this.priorityScore,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'priority': priority,
      'priorityScore': priorityScore,
      'isDone': isDone,
      'createdAt': createdAt,
      'deadline': deadline,
      'userId': userId,
    };
  }

  factory TaskModel.fromMap(String id, Map<String, dynamic> map) {
    return TaskModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      priority: map['priority'] ?? 'Low',
      priorityScore: map['priorityScore'] ?? 0,
      isDone: map['isDone'] ?? false,
      createdAt: map['createdAt'].toDate(),
      deadline: map['deadline'] != null ? map['deadline'].toDate() : null,
      userId: map['userId'] ?? '',
    );
  }
}

