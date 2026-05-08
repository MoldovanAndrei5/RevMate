import 'dart:io';
import 'package:file_picker/file_picker.dart';
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
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedDate;
  bool _isTaskCompleted = false;
  bool _isSaving = false;

  //Invoice state
  final List<File> _selectedInvoices = [];

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
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickInvoices() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null) {
      setState(() {
        final newFiles = result.paths
            .whereType<String>()
            .map((path) => File(path))
            .toList();
        _selectedInvoices.addAll(newFiles);
      });
    }
  }

  void _removeInvoice(int index) {
    setState(() => _selectedInvoices.removeAt(index));
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _fileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return Icons.picture_as_pdf;
    return Icons.image;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in red')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final isEditing = widget.task != null;

    final title = _titleCtrl.text.trim();
    final category = _categoryCtrl.text.trim();
    final mileage = int.tryParse(_mileageCtrl.text.trim()) ?? 0;
    final cost = double.tryParse(_costCtrl.text.trim()) ?? 0;
    final notes = _notesCtrl.text.trim();
    final scheduledDate = _isTaskCompleted ? null : _selectedDate;
    final completedDate = _isTaskCompleted ? _selectedDate : null;

    try {
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
      } else {
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
        await taskProvider.addTask(newTask, invoices: _selectedInvoices);
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    final showInvoices = _isTaskCompleted && !isEditing;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'Add Task'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //Completed / Scheduled toggle
              if (!isEditing)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text("Scheduled")),
                    ButtonSegment(value: true, label: Text("Completed")),
                  ],
                  selected: <bool>{_isTaskCompleted},
                  onSelectionChanged: (Set<bool> value) {
                    setState(() {
                      _isTaskCompleted = value.first;
                      _selectedDate = null;
                    });
                  },
                ),
              if (!isEditing) const SizedBox(height: 8),

              // Form fields
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
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
                    child: Text(
                      _selectedDate == null
                          ? 'No date selected'
                          : formatDate(_selectedDate!),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDate,
                    child: const Text('Select Date'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mileageCtrl,
                decoration: const InputDecoration(labelText: 'Mileage'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
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
                  if (value == null || value.trim().isEmpty) return null;
                  final cost = double.tryParse(value);
                  if (cost == null || cost < 0) {
                    return 'Please enter a valid cost';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),

              //Invoice section (only for completed tasks)
              if (showInvoices) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invoices & Attachments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickInvoices,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                if (_selectedInvoices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No attachments added',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedInvoices.length,
                    itemBuilder: (context, index) {
                      final file = _selectedInvoices[index];
                      final fileName = file.path.split('/').last;
                      final fileSize = file.lengthSync();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(_fileIcon(fileName)),
                          title: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(_formatFileSize(fileSize)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _removeInvoice(index),
                          ),
                        ),
                      );
                    },
                  ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text('Save'),
          ),
        ),
      ),
    );
  }
}