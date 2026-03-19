import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/maintenance_task.dart';
import '../../providers/task_provider.dart';
import '../../utils/date_utils.dart';

class TaskFormScreen extends StatefulWidget {
  final String carUuid;
  final MaintenanceTask? task;

  const TaskFormScreen({super.key, required this.carUuid, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _titleCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  DateTime? _selectedDate;
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isTaskCompleted = false;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleCtrl.text = widget.task!.title;
      _categoryCtrl.text = widget.task!.category;
      _selectedDate = widget.task!.completedDate ?? widget.task!.scheduledDate;
      _mileageCtrl.text = widget.task!.mileage?.toString() ?? '';
      _costCtrl.text = widget.task!.cost?.toString() ?? '';
      _notesCtrl.text = widget.task!.notes?.toString() ?? '';
      _isTaskCompleted = widget.task!.completedDate != null;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _categoryCtrl.dispose();
    _mileageCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _isTaskCompleted ? DateTime(1886) : now,
      lastDate: _isTaskCompleted ? now : DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final isEditing = widget.task != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Task' : 'Add Task'), centerTitle: true,),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (!isEditing)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text("Scheduled")),
                      ButtonSegment(value: true, label: Text("Completed")),
                    ],
                    selected: <bool>{_isTaskCompleted},
                    onSelectionChanged: (Set<bool>value) {
                      setState(() {
                        _isTaskCompleted = value.first;
                      });
                    },
                  ),
                if (!isEditing) const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'title'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the title of the task';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the category';
                    }
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(_selectedDate == null ? 'No date selected' : formatDate(_selectedDate!)),
                    ),
                    TextButton(onPressed: _pickDate, child: Text('Select Date')),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _mileageCtrl,
                  decoration: const InputDecoration(labelText: 'Mileage'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final mileage = int.tryParse(value);
                    if (mileage == null || mileage < 0) {
                      return 'Please enter a valid mileage';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _costCtrl,
                  decoration: const InputDecoration(labelText: 'Cost'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }
                    final cost = double.tryParse(value);
                    if (cost == null || cost < 0) {
                      return 'Please enter a valid cost';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final title = _titleCtrl.text.trim();
                final category = _categoryCtrl.text.trim();
                final mileage = int.tryParse(_mileageCtrl.text.trim()) ?? 0;
                final cost = double.tryParse(_costCtrl.text.trim()) ?? 0;
                final notes = _notesCtrl.text.trim();
                DateTime? scheduledDate;
                DateTime? completedDate;

                if (_isTaskCompleted) {
                  completedDate = _selectedDate;
                }
                else {
                  scheduledDate = _selectedDate;
                }

                if (isEditing) {
                  final updatedTask = widget.task!.copyWith(
                    title: title,
                    category: category.isEmpty ? null : category,
                    mileage: mileage,
                    cost: cost,
                    scheduledDate: scheduledDate,
                    completedDate: completedDate,
                    notes: notes,
                  );
                  await taskProvider.updateTask(updatedTask);
                }
                else {
                  final newTask = MaintenanceTask(
                    carUuid: widget.carUuid,
                    title: title,
                    category: category,
                    mileage: mileage,
                    cost: cost,
                    scheduledDate: scheduledDate,
                    completedDate: completedDate,
                    notes: notes,
                  );
                  await taskProvider.addTask(newTask);
                }
                if (mounted) {
                  Navigator.pop(context);
                }
              }
              else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fix the errors in red')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ),
      ),
    );
  }
}
