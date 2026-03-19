import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/maintenance_task.dart';
import '../utils/date_utils.dart';

class TaskItem extends StatelessWidget {
  final MaintenanceTask task;
  final VoidCallback onTap;

  const TaskItem({
    super.key,
    required this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isTaskCompleted = task.completedDate != null ? true : false;
    bool isTaskOverdue = isTaskCompleted ? false : task.scheduledDate!.compareTo(DateTime.now()) < 0;
    final dateStr = isTaskCompleted ? formatDate(task.completedDate!) : formatDate(task.scheduledDate!);
    IconData statusIcon;
    Color statusIconColor;
    if (isTaskCompleted) {
      statusIcon = Icons.check_circle;
      statusIconColor = Colors.green;
    }
    else {
      if (isTaskOverdue) {
        statusIcon = Icons.cancel;
        statusIconColor = Colors.red;
      }
      else {
        statusIcon = Icons.schedule;
        statusIconColor = Colors.yellow;
      }
    }
    return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          title: Text(
            task.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          subtitle: Text(
            '${task.category} ${dateStr.isNotEmpty ? "- $dateStr" : task.mileage ?? ""}',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          onTap: onTap,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusIconColor),
              Icon(Icons.arrow_forward_ios),
            ],
          ),
        )
    );
  }
}
