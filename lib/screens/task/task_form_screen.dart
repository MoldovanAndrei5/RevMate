import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/maintenance_task.dart';
import '../../providers/task_provider.dart';
import '../../utils/date_utils.dart';
import '../../utils/snack_bar_helper.dart';
import '../../utils/api_exception.dart';

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
  final List<File> _selectedInvoices = [];

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleCtrl.text = widget.task!.title;
      _categoryCtrl.text = widget.task!.category;
      _selectedDate = widget.task!.completedDate ?? widget.task!.scheduledDate;
      _mileageCtrl.text = widget.task!.mileage?.toString() ?? "";
      _costCtrl.text = widget.task!.cost?.toString() ?? "";
      _notesCtrl.text = widget.task!.notes?.toString() ?? "";
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickInvoices() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ["pdf", "jpg", "jpeg", "png"],
    );
    if (result != null) {
      setState(() {
        _selectedInvoices.addAll(
          result.paths.whereType<String>().map((p) => File(p)),
        );
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  IconData _fileIcon(String fileName) {
    final ext = fileName.split(".").last.toLowerCase();
    return ext == "pdf" ? Icons.picture_as_pdf_outlined : Icons.image_outlined;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      showTopSnackBar(context, "Please select a date", type: SnackBarType.error);
      return;
    }

    setState(() => _isSaving = true);

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final mileage = int.tryParse(_mileageCtrl.text.trim());
    final cost = double.tryParse(_costCtrl.text.trim());
    final notes = _notesCtrl.text.trim();
    final scheduledDate = _isTaskCompleted ? null : _selectedDate;
    final completedDate = _isTaskCompleted ? _selectedDate : null;

    try {
      if (_isEditing) {
        final updatedTask = widget.task!.copyWith(
          title: _titleCtrl.text.trim(),
          category: _categoryCtrl.text.trim(),
          mileage: mileage,
          cost: cost,
          scheduledDate: scheduledDate,
          completedDate: completedDate,
          notes: notes.isEmpty ? null : notes,
        );
        await taskProvider.updateTask(updatedTask);
        if (mounted) {
          showTopSnackBar(context, "Task updated successfully");
          Navigator.pop(context);
        }
      } else {
        final newTask = MaintenanceTask(
          carUuid: widget.carUuid,
          title: _titleCtrl.text.trim(),
          category: _categoryCtrl.text.trim(),
          mileage: mileage,
          cost: cost,
          scheduledDate: scheduledDate,
          completedDate: completedDate,
          notes: notes.isEmpty ? null : notes,
        );
        await taskProvider.addTask(newTask, invoices: _selectedInvoices);
        if (mounted) {
          showTopSnackBar(context, "Task added successfully");
          Navigator.pop(context);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showInvoices = _isTaskCompleted && !_isEditing;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Task" : "Add Task"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isEditing) ...[
                _sectionLabel("Task Type"),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text("Scheduled"),
                      icon: Icon(Icons.schedule_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text("Completed"),
                      icon: Icon(Icons.check_circle_outline_rounded, size: 16),
                    ),
                  ],
                  selected: {_isTaskCompleted},
                  onSelectionChanged: (v) => setState(() {
                    _isTaskCompleted = v.first;
                    _selectedDate = null;
                  }),
                  style: ButtonStyle(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              _sectionLabel("Task Details"),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Please enter the task title"
                    : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryCtrl,
                decoration: InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Please enter a category"
                    : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 24),

              _sectionLabel(_isTaskCompleted ? "Completion Date" : "Scheduled Date"),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade400,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedDate == null
                              ? "Select a date"
                              : formatDate(_selectedDate!),
                          style: TextStyle(
                            fontSize: 16,
                            color: _selectedDate == null
                                ? Colors.grey.shade500
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _sectionLabel("Optional Details"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mileageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Mileage (km)",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade50,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final m = int.tryParse(v);
                        if (m == null || m < 0) return "Invalid";
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Cost (EUR)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark
                            ? Colors.grey.shade900
                            : Colors.grey.shade50,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final c = double.tryParse(v);
                        if (c == null || c < 0) return "Invalid";
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Notes",
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.notes_outlined),
                  ),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor:
                  isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                ),
              ),

              if (showInvoices) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionLabel("Invoices & Attachments"),
                    TextButton.icon(
                      onPressed: _pickInvoices,
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text("Add"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_selectedInvoices.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade900
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      "No attachments added",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                    ),
                  )
                else
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedInvoices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final file = _selectedInvoices[index];
                        final fileName = file.path.split("/").last;
                        return ListTile(
                          leading: Icon(
                            _fileIcon(fileName),
                            color: colorScheme.primary,
                          ),
                          title: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(_formatFileSize(file.lengthSync())),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                            onPressed: () => setState(() => _selectedInvoices.removeAt(index)),
                          ),
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isSaving
                ? SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.onPrimary,
              ),
            ) : Text(
              _isEditing ? "Save Changes" : "Add Task",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade500,
        letterSpacing: 0.5,
      ),
    );
  }
}