class MaintenanceTask {
  final String? taskUuid;
  final String carUuid;
  final String title;
  final String category;
  final int? mileage;
  final double? cost;
  final DateTime? scheduledDate;
  final DateTime? completedDate;
  final String? notes;
  final int isSynced;
  final int isDeleted;

  MaintenanceTask({
    this.taskUuid,
    required this.carUuid,
    required this.title,
    required this.category,
    this.mileage,
    this.cost,
    this.scheduledDate,
    this.completedDate,
    this.notes,
    this.isSynced = 0,
    this.isDeleted = 0,
  });

  MaintenanceTask copyWith({
    String? taskUuid,
    String? carUuid,
    String? title,
    String? category,
    int? priority,
    int? mileage,
    double? cost,
    DateTime? scheduledDate,
    DateTime? completedDate,
    String? notes,
    int? isSynced,
    int? isDeleted,
  }) {
    return MaintenanceTask(
      taskUuid: taskUuid ?? this.taskUuid,
      carUuid: carUuid ?? this.carUuid,
      title: title ?? this.title,
      category: category ?? this.category,
      mileage: mileage ?? this.mileage,
      cost: cost ?? this.cost,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (taskUuid != null) "task_uuid": taskUuid,
      "car_uuid": carUuid,
      "title": title,
      "category": category,
      "mileage": mileage,
      "cost": cost,
      "scheduled_date": scheduledDate?.millisecondsSinceEpoch,
      "completed_date": completedDate?.millisecondsSinceEpoch,
      "notes": notes,
      "is_synced": isSynced,
      "is_deleted": isDeleted,
    };
  }

  factory MaintenanceTask.fromMap(Map<String, Object?> map) {
    return MaintenanceTask(
      taskUuid: map["task_uuid"] != null ? map["task_uuid"] as String : "0",
      carUuid: map["car_uuid"] as String,
      title: map["title"] as String,
      category: map["category"] as String,
      mileage: map["mileage"] == null ? null : (map["mileage"] as num).toInt(),
      cost: map["cost"] == null ? null : double.parse(map["cost"].toString()),
      scheduledDate: map["scheduled_date"] == null ? null : DateTime.fromMillisecondsSinceEpoch((map["scheduled_date"] as num).toInt()),
      completedDate: map["completed_date"] == null ? null : DateTime.fromMillisecondsSinceEpoch((map["completed_date"] as num).toInt()),
      notes: map["notes"] as String?,
      isSynced: map['is_synced'] != null ? (map['is_synced'] as num).toInt() : 1,
      isDeleted: map['is_deleted'] != null ? (map['is_deleted'] as num).toInt() : 0,
    );
  }
}
