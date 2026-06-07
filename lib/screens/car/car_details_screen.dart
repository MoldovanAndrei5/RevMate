import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:car_maintenance_tracker/models/car.dart';
import 'package:car_maintenance_tracker/models/maintenance_task.dart';
import 'package:car_maintenance_tracker/providers/car_provider.dart';
import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/screens/car/car_form_screen.dart';
import 'package:car_maintenance_tracker/screens/task/task_form_screen.dart';
import 'package:car_maintenance_tracker/services/api_report_service.dart';
import 'package:car_maintenance_tracker/utils/sort_filter_enums.dart';
import 'package:car_maintenance_tracker/widgets/bottom_navbar_widget.dart';
import 'package:car_maintenance_tracker/widgets/task_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_transfer_service.dart';
import '../other/settings_screen.dart';
import '../task/task_details_screen.dart';

class CarDetailsScreen extends StatefulWidget {
  final String carUuid;
  const CarDetailsScreen({super.key, required this.carUuid});

  @override
  State<CarDetailsScreen> createState() => _CarDetailsScreenState();
}

class _CarDetailsScreenState extends State<CarDetailsScreen> {
  final ApiReportService _reportService = ApiReportService();
  final ApiTransferService _transferService = ApiTransferService();
  bool _isGeneratingReport = false;

  Car? _car;
  bool _loadingCar = true;

  @override
  void initState() {
    super.initState();
    _loadCar();
  }

  Future<void> _loadCar() async {
    final car = await context.read<CarProvider>().getById(widget.carUuid);
    if (mounted) {
      setState(() {
        _car = car;
        _loadingCar = false;
      });
    }
  }

  Widget _buildImage(Car car) {
    if (car.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: car.imageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 90,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => const CircleAvatar(
          radius: 90,
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 90,
          backgroundImage: const AssetImage(
              "assets/P90203628-bmw-m4-coup-with-bmw-m-performance-parts-side-view-11-2015-2002px.jpg"),
        ),
      );
    }
    return CircleAvatar(
      radius: 90,
      backgroundImage: const AssetImage(
          "assets/P90203628-bmw-m4-coup-with-bmw-m-performance-parts-side-view-11-2015-2002px.jpg"),
    );
  }

  Future<void> _downloadAndShareReport(Car car) async {
    setState(() => _isGeneratingReport = true);
    try {
      final bytes = await _reportService.getCarReport(car.carUuid!);
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate report')),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final fileName =
      'revmate_${car.make}_${car.model}_${car.year}_report.pdf'
          .replaceAll(' ', '_');
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Service History Report — ${car.name}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong generating the report')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  void _showTransferSheet(Car car) {
    final emailCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 24,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom +
                MediaQuery.of(sheetContext).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Transfer Car',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Enter the email of the person you want to transfer "${car.name}" to',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Receiver email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final email = emailCtrl.text.trim();
                  if (email.isEmpty) return;

                  final response = await _transferService.initiateTransfer(
                    carUuid: car.carUuid!,
                    receiverEmail: email,
                  );

                  if (mounted) {
                    if (response.statusCode == 200 || response.statusCode == 201) {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Transfer request sent to $email')),
                      );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to initiate transfer')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Send Transfer Request'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCar) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_car == null) {
      return const Scaffold(body: Center(child: Text("Car not found")));
    }

    final car = _car!;
    final carProvider = context.read<CarProvider>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Car details"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildImage(car),
            ListTile(
              title: Text(
                '${car.year} ${car.make} ${car.model}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700),
              ),
              subtitle: DefaultTextStyle(
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
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

            // Edit / Delete buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CarFormScreen(car: car)),
                    ).then((_) => _loadCar()),
                    child: const Text("Edit car"),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(
                          width: 3.0,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await carProvider.deleteCar(widget.carUuid);
                      await context.read<TaskProvider>().fetchTasks();
                      if (navigator.canPop()) navigator.pop();
                    },
                    child: const Text("Delete car"),
                  ),
                ),
              ],
            ),

            // Tasks section
            Consumer<TaskProvider>(
              builder: (context, taskProvider, _) {
                final currentFilterBy = taskProvider.filterBy;
                final currentSortBy = taskProvider.sortBy;
                final currentSortOrder = taskProvider.sortOrder;

                return Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                "Maintenance tasks",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text("Filter Tasks",
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      _filterTile(context, taskProvider,
                                          "All tasks",
                                          TaskFilterOption.all,
                                          currentFilterBy),
                                      _filterTile(context, taskProvider,
                                          "Completed tasks",
                                          TaskFilterOption.completed,
                                          currentFilterBy),
                                      _filterTile(context, taskProvider,
                                          "Scheduled tasks",
                                          TaskFilterOption.scheduled,
                                          currentFilterBy),
                                      _filterTile(context, taskProvider,
                                          "Overdue tasks",
                                          TaskFilterOption.overdue,
                                          currentFilterBy),
                                    ],
                                  ),
                                ),
                              ),
                              child: const Icon(Icons.filter_list),
                            ),
                            ElevatedButton(
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text("Sort tasks",
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      _sortTile(context, taskProvider,
                                          "Sort ascending by date",
                                          TaskSortOption.date,
                                          SortOrder.ascending,
                                          currentSortBy, currentSortOrder),
                                      _sortTile(context, taskProvider,
                                          "Sort descending by date",
                                          TaskSortOption.date,
                                          SortOrder.descending,
                                          currentSortBy, currentSortOrder),
                                      _sortTile(context, taskProvider,
                                          "Sort ascending by cost",
                                          TaskSortOption.cost,
                                          SortOrder.ascending,
                                          currentSortBy, currentSortOrder),
                                      _sortTile(context, taskProvider,
                                          "Sort descending by cost",
                                          TaskSortOption.cost,
                                          SortOrder.descending,
                                          currentSortBy, currentSortOrder),
                                      _sortTile(context, taskProvider,
                                          "Sort ascending by mileage",
                                          TaskSortOption.mileage,
                                          SortOrder.ascending,
                                          currentSortBy, currentSortOrder),
                                      _sortTile(context, taskProvider,
                                          "Sort descending by mileage",
                                          TaskSortOption.mileage,
                                          SortOrder.descending,
                                          currentSortBy, currentSortOrder),
                                    ],
                                  ),
                                ),
                              ),
                              child: const Icon(Icons.sort),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: FutureBuilder<List<MaintenanceTask>>(
                          future: taskProvider.getTasksForCar(widget.carUuid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            final tasks = snapshot.data ?? [];
                            return tasks.isEmpty
                                ? const Center(
                                child: Text(
                                    "No maintenance tasks available. Tap + to add one"))
                                : ListView.builder(
                              itemCount: tasks.length,
                              itemBuilder: (context, index) {
                                final task = tasks[index];
                                return TaskItem(
                                  task: task,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TaskDetailsScreen(
                                          carUuid: car.carUuid!,
                                          taskUuid: task.taskUuid!),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),

      // Speed Dial FAB
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        overlayColor: Colors.black,
        overlayOpacity: 0.3,
        spacing: 12,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.add_task),
            label: 'Add Task',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TaskFormScreen(carUuid: car.carUuid!)),
            ),
          ),
          SpeedDialChild(
            child: _isGeneratingReport
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.picture_as_pdf),
            label: 'Export Report',
            onTap: _isGeneratingReport
                ? null
                : () => _downloadAndShareReport(car),
          ),
          SpeedDialChild(
            child: const Icon(Icons.swap_horiz),
            label: 'Transfer Car',
            onTap: () => _showTransferSheet(car),
          ),
        ],
      ),

      bottomNavigationBar: const SafeArea(
        child: BottomNavbarWidget(),
      ),
    );
  }

  Widget _filterTile(
      BuildContext context,
      TaskProvider provider,
      String label,
      TaskFilterOption option,
      TaskFilterOption current,
      ) {
    return ListTile(
      title: Text(label),
      selected: current == option,
      trailing: current == option ? const Icon(Icons.check) : null,
      onTap: () {
        provider.setFilterBy(option);
        Navigator.pop(context);
      },
    );
  }

  Widget _sortTile(
      BuildContext context,
      TaskProvider provider,
      String label,
      TaskSortOption sortOption,
      SortOrder sortOrder,
      TaskSortOption currentSort,
      SortOrder currentOrder,
      ) {
    final isSelected = currentSort == sortOption && currentOrder == sortOrder;
    return ListTile(
      title: Text(label),
      selected: isSelected,
      trailing: isSelected ? const Icon(Icons.check) : null,
      onTap: () {
        provider.setSortBy(sortOption);
        provider.setSortOrder(sortOrder);
        Navigator.pop(context);
      },
    );
  }
}