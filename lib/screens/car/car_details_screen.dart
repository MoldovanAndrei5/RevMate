import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:car_maintenance_tracker/models/car.dart';
import 'package:car_maintenance_tracker/models/maintenance_task.dart';
import 'package:car_maintenance_tracker/providers/car_provider.dart';
import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/screens/car/car_form_screen.dart';
import 'package:car_maintenance_tracker/screens/task/task_form_screen.dart';
import 'package:car_maintenance_tracker/services/api_car_service.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:car_maintenance_tracker/widgets/top_snack_bar.dart';
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
  final ApiTransferService _transferService = ApiTransferService();
  final ApiCarService _carService = ApiCarService();
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

  Widget _buildCarImage(Car car) {
    final colorScheme = Theme.of(context).colorScheme;
    if (car.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: car.imageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 60,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: 60,
          backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.15),
          child: CircularProgressIndicator(
            color: colorScheme.onPrimary,
            strokeWidth: 2,
          ),
        ),
        errorWidget: (context, url, error) => _defaultCarAvatar(),
      );
    }
    return _defaultCarAvatar();
  }

  Widget _defaultCarAvatar() {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 60,
      backgroundColor: colorScheme.onPrimary.withValues(alpha: 0.15),
      child: Icon(
        Icons.directions_car_rounded,
        size: 52,
        color: colorScheme.onPrimary.withValues(alpha: 0.7),
      ),
    );
  }

  Future<void> _downloadAndShareReport(Car car) async {
    setState(() => _isGeneratingReport = true);
    try {
      final bytes = await _carService.getCarReport(car.carUuid!);
      final dir = await getTemporaryDirectory();
      final fileName = "revmate_${car.make}_${car.model}_${car.year}_report.pdf".replaceAll(" ", "_");
      final file = File("${dir.path}/$fileName");
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: "application/pdf")],
        subject: "Service history report for ${car.name}",
      );
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  Future<void> _deleteCar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete vehicle"),
        content: Text("Are you sure you want to delete ${_car!.name}? This will also delete all associated tasks and invoices."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final carName = _car!.name;
    try {
      await context.read<CarProvider>().deleteCar(widget.carUuid);
      await context.read<TaskProvider>().fetchTasks();
      if (mounted) {
        showTopSnackBar(context, "$carName deleted successfully");
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (mounted) showTopSnackBar(context, e.message, type: SnackBarType.error);
    }
  }

  void _showTransferSheet(Car car) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TransferSheet(
        car: car,
        transferService: _transferService,
        onSuccess: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
      ),
    );
  }

  void _showFilterSheet(
      BuildContext context, TaskProvider taskProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Filter Tasks",
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ...[
                ("All tasks", TaskFilterOption.all),
                ("Completed", TaskFilterOption.completed),
                ("Scheduled", TaskFilterOption.scheduled),
                ("Overdue", TaskFilterOption.overdue),
              ].map((e) => ListTile(
                title: Text(e.$1),
                selected: taskProvider.filterBy == e.$2,
                trailing: taskProvider.filterBy == e.$2
                    ? Icon(Icons.check_rounded,
                    color:
                    Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  taskProvider.setFilterBy(e.$2);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortSheet(
      BuildContext context, TaskProvider taskProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Sort Tasks",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Sort field
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        Text("Sort by",
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ("Date", TaskSortOption.date),
                        ("Cost", TaskSortOption.cost),
                        ("Mileage", TaskSortOption.mileage),
                      ].map((e) {
                        final selected = taskProvider.sortBy == e.$2;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.$1),
                            selected: selected,
                            onSelected: (_) {
                              taskProvider.setSortBy(e.$2);
                              setSheetState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sort order
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        Text("Order",
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ("Ascending", SortOrder.ascending,
                        Icons.arrow_upward_rounded),
                        ("Descending", SortOrder.descending,
                        Icons.arrow_downward_rounded),
                      ].map((e) {
                        final selected = taskProvider.sortOrder == e.$2;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(e.$3, size: 14),
                                const SizedBox(width: 4),
                                Text(e.$1),
                              ],
                            ),
                            selected: selected,
                            onSelected: (_) {
                              taskProvider.setSortOrder(e.$2);
                              setSheetState(() {});
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text("Done"),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCar) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_car == null) {
      return const Scaffold(
          body: Center(child: Text("Car not found")));
    }

    final car = _car!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Car Details"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildCarImage(car),
                  const SizedBox(height: 12),
                  Text(
                    car.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${car.year} ${car.make} ${car.model}",
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _detailRow(
                      "Mileage",
                      "${car.mileage} km",
                    ),
                    _divider(),
                    _detailRow(
                      "License Plate",
                      car.licensePlate,
                    ),
                    _divider(),
                    _detailRow(
                      "VIN",
                      car.vin,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CarFormScreen(car: car)),
                      ).then((_) => _loadCar()),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text("Edit"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _deleteCar,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text("Delete"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Consumer<TaskProvider>(
              builder: (context, taskProvider, _) {
                return Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Maintenance Tasks",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.filter_list_rounded,
                            color: taskProvider.filterBy !=
                                TaskFilterOption.all
                                ? colorScheme.primary
                                : null,
                          ),
                          tooltip: "Filter",
                          onPressed: () =>
                              _showFilterSheet(context, taskProvider),
                        ),
                        IconButton(
                          icon: const Icon(Icons.sort_rounded),
                          tooltip: "Sort",
                          onPressed: () =>
                              _showSortSheet(context, taskProvider),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<MaintenanceTask>>(
                      future:
                      taskProvider.getTasksForCar(widget.carUuid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final tasks = snapshot.data ?? [];
                        if (tasks.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.build_outlined,
                                  size: 36,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  taskProvider.filterBy !=
                                      TaskFilterOption.all
                                      ? "No tasks match this filter"
                                      : "No tasks yet",
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          physics:
                          const NeverScrollableScrollPhysics(),
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
                                    taskUuid: task.taskUuid!,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                );
              },
            ),
          ],
        ),
      ),

      floatingActionButton: SpeedDial(
        icon: Icons.add_rounded,
        activeIcon: Icons.close_rounded,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        overlayColor: Colors.black,
        overlayOpacity: 0.3,
        spacing: 12,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.add_task_rounded),
            label: "Add Task",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      TaskFormScreen(carUuid: car.carUuid!)),
            ),
          ),
          SpeedDialChild(
            child: _isGeneratingReport ? const SizedBox(
              width: 20,
              height: 20,
              child:
              CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.picture_as_pdf_rounded),
            label: "Export Report",
            onTap: _isGeneratingReport
                ? null
                : () => _downloadAndShareReport(car),
          ),
          SpeedDialChild(
            child: const Icon(Icons.swap_horiz_rounded),
            label: "Transfer Car",
            onTap: () => _showTransferSheet(car),
          ),
        ],
      ),

      bottomNavigationBar: const SafeArea(
        child: BottomNavbarWidget(),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 16, endIndent: 16);
}

class _TransferSheet extends StatefulWidget {
  final Car car;
  final ApiTransferService transferService;
  final VoidCallback onSuccess;

  const _TransferSheet({
    required this.car,
    required this.transferService,
    required this.onSuccess,
  });

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await widget.transferService.initiateTransfer(
        carUuid: widget.car.carUuid!,
        receiverEmail: _emailCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        showTopSnackBar(context, "Transfer request sent for ${widget.car.name}");
        widget.onSuccess();
      }
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.swap_horiz_rounded,
                      color: colorScheme.primary, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  "Transfer Vehicle",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Enter the email of the person you want to transfer '${widget.car.name}' to",
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Receiver email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade900
                        : Colors.grey.shade50,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return "Please enter an email";
                    }
                    if (!v.contains("@")) {
                      return "Please enter a valid email";
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                        : const Text(
                      "Send Transfer Request",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
