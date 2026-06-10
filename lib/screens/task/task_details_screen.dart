import 'dart:io';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:car_maintenance_tracker/utils/snack_bar_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:car_maintenance_tracker/models/invoice.dart';
import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/screens/task/task_form_screen.dart';
import 'package:car_maintenance_tracker/services/api_invoice_service.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:car_maintenance_tracker/models/maintenance_task.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../../models/car.dart';
import '../../providers/car_provider.dart';
import '../../utils/date_utils.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String carUuid;
  final String taskUuid;

  const TaskDetailsScreen({
    super.key,
    required this.carUuid,
    required this.taskUuid,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final ApiInvoiceService _invoiceService = ApiInvoiceService();

  MaintenanceTask? _task;
  Car? _car;
  bool _loadingData = true;
  List<Invoice> _invoices = [];
  bool _loadingInvoices = false;
  String? _downloadingInvoiceUuid;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final taskProvider = context.read<TaskProvider>();
    final carProvider = context.read<CarProvider>();
    try {
      final results = await Future.wait([
        taskProvider.getById(widget.taskUuid),
        carProvider.getById(widget.carUuid),
      ]);
      if (mounted) {
        setState(() {
          _task = results[0] as MaintenanceTask?;
          _car = results[1] as Car?;
          _loadingData = false;
        });
      }
      if (_task?.completedDate != null) {
        await _loadInvoices();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _loadInvoices() async {
    if (mounted) setState(() => _loadingInvoices = true);
    try {
      final invoices = await _invoiceService.getTaskInvoices(widget.taskUuid);
      if (mounted) setState(() => _invoices = invoices);
    } on ApiException catch (e) {
      if (e.statusCode != 0 && mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _loadingInvoices = false);
    }
  }

  Future<void> _addInvoices() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ["pdf", "jpg", "jpeg", "png"],
    );
    if (result == null) return;
    final files = result.paths.whereType<String>().map((p) => File(p)).toList();
    for (final file in files) {
      final fileName = file.path.split("/").last;
      final ext = fileName.split(".").last.toLowerCase();
      final fileType = ext == "pdf"
          ? "application/pdf"
          : ext == "png"
          ? "image/png"
          : "image/jpeg";
      try {
        final invoice = await _invoiceService.uploadInvoice(
          taskUuid: widget.taskUuid,
          file: file,
          fileName: fileName,
          fileType: fileType,
        );
        if (mounted) setState(() => _invoices.add(invoice));
      } on ApiException catch (e) {
        if (mounted) {
          showTopSnackBar(context, e.message, type: SnackBarType.error);
        }
      }
    }
  }

  Future<void> _downloadInvoice(Invoice invoice) async {
    setState(() => _downloadingInvoiceUuid = invoice.invoiceUuid);
    try {
      final url = await _invoiceService.getInvoiceDownloadLink(invoice.invoiceUuid);
      final s3Response = await http.get(Uri.parse(url));
      if (s3Response.statusCode != 200) {
        if (mounted) {
          showTopSnackBar(context, "Failed to download file", type: SnackBarType.error);
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/${invoice.fileName}");
      await file.writeAsBytes(s3Response.bodyBytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: invoice.fileType)],
        subject: invoice.fileName,
      );
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _downloadingInvoiceUuid = null);
    }
  }

  Future<void> _deleteInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete invoice"),
        content: Text("Delete ${invoice.fileName}?"),
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
    try {
      await _invoiceService.deleteInvoice(invoice.invoiceUuid);
      if (mounted) {
        setState(() => _invoices.removeWhere((i) => i.invoiceUuid == invoice.invoiceUuid));
      }
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    }
  }

  Future<void> _showMarkCompleteSheet(MaintenanceTask task) async {
    final List<File> selectedFiles = [];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      "Mark as Completed",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Optionally attach invoices or receipts before confirming.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.pickFiles(
                          allowMultiple: true,
                          type: FileType.custom,
                          allowedExtensions: ["pdf", "jpg", "jpeg", "png"],
                        );
                        if (result != null) {
                          setSheetState(() {
                            selectedFiles.addAll(
                              result.paths
                                  .whereType<String>()
                                  .map((p) => File(p)),
                            );
                          });
                        }
                      },
                      icon: const Icon(Icons.attach_file),
                      label: const Text("Add Invoices"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    if (selectedFiles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: selectedFiles.length,
                        itemBuilder: (context, index) {
                          final file = selectedFiles[index];
                          final fileName = file.path.split("/").last;
                          final ext = fileName.split(".").last.toLowerCase();
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              ext == "pdf"
                                  ? Icons.picture_as_pdf
                                  : Icons.image,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: Colors.red),
                              onPressed: () => setSheetState(() => selectedFiles.removeAt(index)),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await context.read<TaskProvider>().markTaskCompleted(
                          task.taskUuid!,
                          invoices: selectedFiles,
                        );
                        await _loadData();
                        },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Confirm Completion",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text("Cancel"),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_task == null || _car == null) {
      return const Scaffold(body: Center(child: Text("Not found")));
    }

    final task = _task!;
    final car = _car!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isCompleted = task.completedDate != null;
    final isOverdue = !isCompleted &&
        task.scheduledDate != null &&
        task.scheduledDate!.isBefore(DateTime.now());

    final statusText = isCompleted
        ? "Completed"
        : isOverdue
        ? "Overdue"
        : "Scheduled";
    final statusColor = isCompleted
        ? Colors.green
        : isOverdue
        ? Colors.red
        : Colors.orange;
    final statusIcon = isCompleted
        ? Icons.check_circle_rounded
        : isOverdue
        ? Icons.cancel_rounded
        : Icons.schedule_rounded;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Task Details"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    task.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "For ${car.name}",
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    _detailRow(
                      context,
                      label: "Category",
                      value: task.category,
                    ),
                    _divider(),
                    _detailRow(
                      context,
                      label: isCompleted ? "Completed on" : "Scheduled for",
                      value: isCompleted
                          ? formatDate(task.completedDate!)
                          : task.scheduledDate != null
                          ? formatDate(task.scheduledDate!)
                          : "No date set",
                    ),
                    _divider(),
                    _detailRow(
                      context,
                      label: "Cost",
                      value: task.cost != null
                          ? "${task.cost} EUR"
                          : "Not specified",
                    ),
                    _divider(),
                    _detailRow(
                      context,
                      label: "Mileage",
                      value: task.mileage != null
                          ? "${task.mileage} km"
                          : "Not specified",
                    ),
                    if (task.notes != null && task.notes!.isNotEmpty) ...[
                      _divider(),
                      _detailRow(
                        context,
                        label: "Notes",
                        value: task.notes!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (!isCompleted)
              ElevatedButton.icon(
                onPressed: () => _showMarkCompleteSheet(task),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  "Mark as Completed",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),

            if (isCompleted) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Invoices & Attachments",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loadingInvoices)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.attach_file, size: 18),
                        label: const Text("Add"),
                        onPressed: _addInvoices,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!_loadingInvoices && _invoices.isEmpty)
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
                    "No invoices attached",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                )
              else
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _invoices.length,
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final invoice = _invoices[index];
                      final ext = invoice.fileName.split(".").last.toLowerCase();
                      final isDownloading = _downloadingInvoiceUuid == invoice.invoiceUuid;
                      return ListTile(
                        leading: Icon(
                          ext == "pdf"
                              ? Icons.picture_as_pdf
                              : Icons.image_outlined,
                          color: colorScheme.primary,
                        ),
                        title: Text(
                          invoice.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_formatFileSize(invoice.fileSize)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            isDownloading ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            ) : IconButton(
                              icon: const Icon(Icons.download_outlined),
                              onPressed: () => _downloadInvoice(invoice),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteInvoice(invoice),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskFormScreen(
                        carUuid: widget.carUuid,
                        task: task,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("Edit"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Delete task"),
                        content: const Text("Are you sure you want to delete this task?"),
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
                    if (confirmed == true && mounted) {
                      final navigator = Navigator.of(context);
                      await context.read<TaskProvider>().deleteTask(widget.taskUuid);
                      if (navigator.canPop()) {
                        showTopSnackBar(navigator.context, 'Task deleted successfully');
                        navigator.pop();
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text("Delete"),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
      BuildContext context, {
        required String label,
        required String value,
      }) {
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);
}