import 'package:car_maintenance_tracker/screens/task/task_details_screen.dart';
import 'package:car_maintenance_tracker/widgets/bottom_navbar_widget.dart';
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
    final tasks = taskProvider.get();

    return Scaffold(
      appBar: AppBar(title: Text("Maintenance tasks"), centerTitle: true,),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: tasks.isEmpty
            ? const Center(child: Text('No maintenance tasks.\nGo to a car and create a new one to appear on this page.', textAlign: TextAlign.center,))
            : ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final MaintenanceTask task = tasks[index];
            return TaskItem(
              task: task,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskDetailsScreen(carUuid: task.carUuid, taskUuid: task.taskUuid!),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: const BottomNavbarWidget(),
      ),
    );
  }
}
