import 'dart:io';

import 'package:car_maintenance_tracker/models/car.dart';
import 'package:car_maintenance_tracker/models/maintenance_task.dart';
import 'package:car_maintenance_tracker/providers/car_provider.dart';
import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/screens/car/car_form_screen.dart';
import 'package:car_maintenance_tracker/screens/task/task_form_screen.dart';
import 'package:car_maintenance_tracker/utils/sort_filter_enums.dart';
import 'package:car_maintenance_tracker/widgets/bottom_navbar_widget.dart';
import 'package:car_maintenance_tracker/widgets/task_item.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../task/task_details_screen.dart';

class CarDetailsScreen extends StatelessWidget {
  final String carUuid;
  const CarDetailsScreen({super.key, required this.carUuid});

  @override
  Widget build(BuildContext context) {
    final carProvider = Provider.of<CarProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final currentFilterBy = taskProvider.filterBy;
    final currentSortBy = taskProvider.sortBy;
    final currentSortOrder = taskProvider.sortOrder;

    return FutureBuilder(
        future: Future.wait([
          carProvider.getById(carUuid),
          taskProvider.getTasksForCar(carUuid),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState ==  ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData && snapshot.data![0] == null) {
            return const Scaffold(body: Center(child: Text("Deleting...")));
          }
          Car car = snapshot.data![0];
          List<MaintenanceTask> tasks = snapshot.data![1];

          return Scaffold(
            appBar: AppBar(title: Text("Car details"), centerTitle: true,),
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 90,
                    backgroundImage: car.imagePath != null ? FileImage(
                        File(car.imagePath!)) : AssetImage(
                        "assets/P90203628-bmw-m4-coup-with-bmw-m-performance-parts-side-view-11-2015-2002px.jpg"),
                  ),
                  ListTile(
                    title: Text(
                      '${car.year} ${car.make} ${car.model}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: DefaultTextStyle(
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme
                            .of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                      child: Column(
                        children: [
                          Text('VIN: ${car.vin}'),
                          Text('${car.mileage} kilometers'),
                          Text('Plate: ${car.licensePlate}'),
                        ],
                      ),
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
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
                                MaterialPageRoute(
                                    builder: (_) => CarFormScreen(car: car)),
                              ),
                          child: const Text("Edit car"),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(width: 3.0, color: Theme
                                .of(context)
                                .colorScheme
                                .primary),
                          ),
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            await carProvider.deleteCar(carUuid);
                            await taskProvider.fetchTasks();
                            if (navigator.canPop()) {
                              navigator.pop();
                            }
                          },
                          child: const Text("Delete car"),
                        ),
                      ),
                    ],
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Maintenance tasks",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text("Filter Tasks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      ),
                                      ListTile(
                                        title: const Text("All tasks"),
                                        selected: currentFilterBy == TaskFilterOption.all,
                                        trailing: currentFilterBy == TaskFilterOption.all ? Icon(Icons.check) : null,
                                        onTap: () {
                                          taskProvider.setFilterBy(TaskFilterOption.all);
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ListTile(
                                        title: const Text("Completed tasks"),
                                        selected: currentFilterBy == TaskFilterOption.completed,
                                        trailing: currentFilterBy == TaskFilterOption.completed ? Icon(Icons.check) : null,
                                        onTap: () {
                                          taskProvider.setFilterBy(TaskFilterOption.completed);
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ListTile(
                                        title: const Text("Scheduled tasks"),
                                        selected: currentFilterBy == TaskFilterOption.scheduled,
                                        trailing: currentFilterBy == TaskFilterOption.scheduled ? Icon(Icons.check) : null,
                                        onTap: () {
                                          taskProvider.setFilterBy(TaskFilterOption.scheduled);
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ListTile(
                                        title: const Text("Overdue tasks"),
                                        selected: currentFilterBy == TaskFilterOption.overdue,
                                        trailing: currentFilterBy == TaskFilterOption.overdue ? Icon(Icons.check) : null,
                                        onTap: () {
                                          taskProvider.setFilterBy(TaskFilterOption.overdue);
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: Icon(Icons.filter_list),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) {
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: EdgeInsetsGeometry.all(16),
                                        child: const Text("Sort tasks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      ),
                                      ListTile(
                                        title: const Text("Sort ascending by date"),
                                        selected: currentSortBy == TaskSortOption.date && currentSortOrder == SortOrder.ascending,
                                        trailing: currentSortBy == TaskSortOption.date && currentSortOrder == SortOrder.ascending ? Icon(Icons.check) : null,
                                        onTap: () {
                                          taskProvider.setSortBy(TaskSortOption.date);
                                          taskProvider.setSortOrder(SortOrder.ascending);
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ListTile(
                                        title: const Text("Sort descending by date"),
                                        selected: currentSortBy == TaskSortOption.date && currentSortOrder == SortOrder.descending,
                                        trailing: currentSortBy == TaskSortOption.date && currentSortOrder == SortOrder.descending ? Icon(Icons.check) : null,
                                        onTap: () {
                                          taskProvider.setSortBy(TaskSortOption.date);
                                          taskProvider.setSortOrder(SortOrder.descending);
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ListTile(
                                        title: const Text("Sort ascending by cost"),
                                        selected: currentSortBy == TaskSortOption.cost && currentSortOrder == SortOrder.ascending,
                                        trailing: currentSortBy == TaskSortOption.cost && currentSortOrder == SortOrder.ascending ? Icon(Icons.check) : null,
                                        onTap: () {
                                          taskProvider.setSortBy(TaskSortOption.cost);
                                          taskProvider.setSortOrder(SortOrder.ascending);
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ListTile(
                                        title: const Text("Sort descending by cost"),
                                        selected: currentSortBy == TaskSortOption.cost && currentSortOrder == SortOrder.descending,
                                        trailing: currentSortBy == TaskSortOption.cost && currentSortOrder == SortOrder.descending ? Icon(Icons.check) : null,
                                        onTap: () {
                                          taskProvider.setSortBy(TaskSortOption.cost);
                                          taskProvider.setSortOrder(SortOrder.descending);
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ListTile(
                                        title: const Text("Sort ascending by mileage"),
                                        selected: currentSortBy == TaskSortOption.mileage && currentSortOrder == SortOrder.ascending,
                                        trailing: currentSortBy == TaskSortOption.mileage && currentSortOrder == SortOrder.ascending ? Icon(Icons.check) : null,
                                        onTap: () {
                                          taskProvider.setSortBy(TaskSortOption.mileage);
                                          taskProvider.setSortOrder(SortOrder.ascending);
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ListTile(
                                        title: const Text("Sort descending by mileage"),
                                        selected: currentSortBy == TaskSortOption.mileage && currentSortOrder == SortOrder.descending,
                                        trailing: currentSortBy == TaskSortOption.mileage && currentSortOrder == SortOrder.descending ? Icon(Icons.check) : null,
                                        onTap: () {
                                          taskProvider.setSortBy(TaskSortOption.mileage);
                                          taskProvider.setSortOrder(SortOrder.descending);
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: Icon(Icons.sort),
                        ),
                      ],
                    ),
                  ),

                  Expanded(child: tasks.isEmpty
                      ? const Center(child: Text(
                      "No maintenance tasks available. Tap + to add one"))
                      : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final MaintenanceTask task = tasks[index];
                      return TaskItem(
                        task: task,
                        onTap: () =>
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) =>
                                  TaskDetailsScreen(
                                      carUuid: car.carUuid!, taskUuid: task.taskUuid!),
                            ),
                            ),
                      );
                    },
                  ),
                  ),
                ],
              ),
            ),

            floatingActionButton: FloatingActionButton(
              heroTag: null,
              child: const Icon(Icons.add),
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(
                  builder: (_) => TaskFormScreen(carUuid: car.carUuid!))),
            ),
            bottomNavigationBar: SafeArea(
              child: const BottomNavbarWidget(),
            ),
          );
        }
    );
  }
}