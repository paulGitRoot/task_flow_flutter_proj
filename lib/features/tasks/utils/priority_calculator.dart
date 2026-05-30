int calculatePriorityScore({required String priority, DateTime? deadline}) {
  int score = 0;

  switch (priority) {
    case 'High':
      score += 30;
      break;
    case 'Medium':
      score += 20;
      break;
    case 'Low':
      score += 10;
      break;
  }

  if (deadline != null) {
    final daysLeft = deadline.difference(DateTime.now()).inDays;

    if (daysLeft <= 0) {
      score += 50;
    } else if (daysLeft <= 1) {
      score += 30;
    } else if (daysLeft <= 3) {
      score += 15;
    }
  }

  return score;
}
