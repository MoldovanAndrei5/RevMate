class MonthlyStats {
  final String month;
  final int completed;
  final int scheduled;

  MonthlyStats({
    required this.month,
    required this.completed,
    required this.scheduled,
  });

  factory MonthlyStats.fromMap(Map<String, dynamic> map) {
    return MonthlyStats(
      month: map["month"] as String,
      completed: map["completed"] as int,
      scheduled: map["scheduled"] as int,
    );
  }
}

class AccountStats {
  final double totalSpent;
  final int totalTasks;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final Map<String, double> spentByCategory;
  final List<MonthlyStats> tasksByMonth;

  AccountStats({
    required this.totalSpent,
    required this.totalTasks,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.spentByCategory,
    required this.tasksByMonth,
  });

  factory AccountStats.fromMap(Map<String, dynamic> map) {
    return AccountStats(
      totalSpent: (map["total_spent"] as num).toDouble(),
      totalTasks: map["total_tasks"] as int,
      completedTasks: map["completed_tasks"] as int,
      pendingTasks: map["pending_tasks"] as int,
      overdueTasks: map["overdue_tasks"] as int,
      spentByCategory: Map<String, double>.from(
        (map["spent_by_category"] as Map).map(
              (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ),
      ),
      tasksByMonth: (map["tasks_by_month"] as List)
          .map((e) => MonthlyStats.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}