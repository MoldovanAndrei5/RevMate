import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/screens/task/task_form_screen.dart';
import 'package:car_maintenance_tracker/widgets/task_info_tile_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:car_maintenance_tracker/models/maintenance_task.dart';

import '../../models/car.dart';
import '../../providers/car_provider.dart';
import '../../utils/date_utils.dart';

class TaskDetailsScreen extends StatelessWidget {
  final String carUuid;
  final String taskUuid;

  const TaskDetailsScreen({
    super.key,
    required this.carUuid,
    required this.taskUuid,
  });

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final carProvider = Provider.of<CarProvider>(context);
    
    return FutureBuilder(
      future: Future.wait([
        taskProvider.getById(taskUuid),
        carProvider.getById(carUuid),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && (snapshot.data == null || snapshot.data![0] == null)) {
          return const Scaffold(body: Center(child: Text("Deleting...")));
        }
        MaintenanceTask task = snapshot.data![0];
        Car car = snapshot.data![1];

        bool isTaskCompleted = task.completedDate != null ? true : false;
        bool isTaskOverdue = isTaskCompleted ? false : task.scheduledDate!.compareTo(DateTime.now()) < 0;
        String statusText;
        IconData statusIcon;
        Color statusIconColor;
        if (isTaskCompleted) {
          statusText = "Completed";
          statusIcon = Icons.check_circle;
          statusIconColor = Colors.green;
        }
        else {
          if (isTaskOverdue) {
            statusText = "Overdue";
            statusIcon = Icons.cancel;
            statusIconColor = Colors.red;
          }
          else {
            statusText = "Scheduled";
            statusIcon = Icons.schedule;
            statusIconColor = Colors.yellow;
          }
        }
        
        return Scaffold(
          appBar: AppBar(title: Text("Task details"), centerTitle: true,),
          body: Column(
            children: [
              ListTile(
                title: Text(
                  task.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  "For ${car.name}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme
                        .of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TaskInfoTileWidget(label: "Status", text: statusText),
                              Icon(statusIcon, size: 36, color: statusIconColor),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TaskInfoTileWidget(label: "Date",
                                  text: isTaskCompleted
                                      ? formatDate(task.completedDate!)
                                      : formatDate(task.scheduledDate!)),
                              Icon(Icons.event, size: 36, color: Theme
                                  .of(context)
                                  .colorScheme
                                  .primary),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TaskInfoTileWidget(label: "Cost",
                                  text: task.cost == null
                                      ? "No cost provided"
                                      : task.cost.toString()),
                              Icon(Icons.paid, size: 36, color: Theme
                                  .of(context)
                                  .colorScheme
                                  .primary),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TaskInfoTileWidget(label: "Mileage",
                                  text: task.mileage == null
                                      ? "No mileage provided"
                                      : task.mileage.toString()),
                              Icon(Icons.speed, size: 36, color: Theme
                                  .of(context)
                                  .colorScheme
                                  .primary),
                            ],
                          ),
                          const Divider(),
                          TaskInfoTileWidget(label: "Notes", text: task.notes ==
                              "" ? "There are no notes for this task" : task
                              .notes!),
                          const Divider(),
                          if (!isTaskCompleted)
                            Row(
                              children: [
                                const Text("Mark as completed"),
                                IconButton(
                                  onPressed: () { context.read<TaskProvider>().markTaskCompleted(task.taskUuid!); },
                                  icon: Icon(!isTaskCompleted ? Icons.radio_button_unchecked : Icons.check_circle, color: !isTaskCompleted ? null : Colors.green),
                                ),
                              ],
                            )
                        ],
                      ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar:
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius
                            .circular(10)),
                        backgroundColor: Theme
                            .of(context)
                            .colorScheme
                            .primary,
                        foregroundColor: Theme
                            .of(context)
                            .colorScheme
                            .onPrimary,
                      ),
                      onPressed: () =>
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) =>
                                TaskFormScreen(carUuid: carUuid, task: task)),
                          ),
                      child: const Text("Edit"),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius
                            .circular(10)),
                        side: BorderSide(width: 3.0, color: Theme
                            .of(context)
                            .colorScheme
                            .primary),
                      ),
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await taskProvider.deleteTask(taskUuid);
                        if (navigator.canPop()) {
                          navigator.pop();
                        }
                      },
                      child: const Text("Delete"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
}