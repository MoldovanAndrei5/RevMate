import 'package:car_maintenance_tracker/screens/task/task_details_screen.dart';
import 'package:car_maintenance_tracker/widgets/bottom_navbar_widget.dart';
import 'package:car_maintenance_tracker/widgets/sync_indicator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/task_item.dart';
import '../../models/maintenance_task.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final tasks = taskProvider.tasks;
    final colorScheme = Theme.of(context).colorScheme;

    final overdue = tasks.where((t) => t.completedDate == null && t.scheduledDate != null && t.scheduledDate!.isBefore(DateTime.now())).toList();
    final scheduled = tasks.where((t) => t.completedDate == null && (t.scheduledDate == null || !t.scheduledDate!.isBefore(DateTime.now()))).toList();
    final completed = tasks.where((t) => t.completedDate != null).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Maintenance Tasks"),
        centerTitle: true,
        elevation: 0,
        actions: const [SyncIndicator()],
      ),
      body: tasks.isEmpty
          ? _buildEmptyState(context, colorScheme)
          : RefreshIndicator(
        onRefresh: () => context.read<TaskProvider>().fetchTasks(),
        color: colorScheme.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            if (tasks.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _summaryChip(
                      context,
                      label: "${tasks.length} Total",
                      color: colorScheme.primary,
                      icon: Icons.list_rounded,
                    ),
                    const SizedBox(width: 8),
                    _summaryChip(
                      context,
                      label: "${completed.length} Done",
                      color: Colors.green,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    const SizedBox(width: 8),
                    _summaryChip(
                      context,
                      label: "${scheduled.length} Scheduled",
                      color: Colors.orange,
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(width: 8),
                    _summaryChip(
                      context,
                      label: "${overdue.length} Overdue",
                      color: Colors.red,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (overdue.isNotEmpty) ...[
              _sectionHeader(
                  context, "Overdue", Colors.red, overdue.length),
              const SizedBox(height: 8),
              ...overdue.map((task) => _taskTile(context, task)),
              const SizedBox(height: 16),
            ],

            if (scheduled.isNotEmpty) ...[
              _sectionHeader(context, "Scheduled", Colors.orange,
                  scheduled.length),
              const SizedBox(height: 8),
              ...scheduled.map((task) => _taskTile(context, task)),
              const SizedBox(height: 16),
            ],

            if (completed.isNotEmpty) ...[
              _sectionHeader(context, "Completed", Colors.green,
                  completed.length),
              const SizedBox(height: 8),
              ...completed.map((task) => _taskTile(context, task)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const SafeArea(
        child: BottomNavbarWidget(),
      ),
    );
  }

  Widget _taskTile(BuildContext context, MaintenanceTask task) {
    return TaskItem(
      task: task,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TaskDetailsScreen(
            carUuid: task.carUuid,
            taskUuid: task.taskUuid!,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "$count",
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(BuildContext context, {
        required String label,
        required Color color,
        required IconData icon,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.build_outlined,
                size: 52,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "No maintenance tasks",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Go to a vehicle and tap + to add your first maintenance task",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}