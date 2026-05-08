import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:car_maintenance_tracker/models/invoice.dart';
import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/screens/task/task_form_screen.dart';
import 'package:car_maintenance_tracker/services/api_invoice_service.dart';
import 'package:car_maintenance_tracker/widgets/task_info_tile_widget.dart';
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
  }

  Future<void> _loadInvoices() async {
    if (mounted) setState(() => _loadingInvoices = true);
    try {
      final response = await _invoiceService.getTaskInvoices(widget.taskUuid);
      if (response.statusCode == 200 && response.data != null) {
        if (mounted) setState(() => _invoices = response.data!);
      }
    } catch (e) {
      // offline
    } finally {
      if (mounted) setState(() => _loadingInvoices = false);
    }
  }

  // Add invoice directly from task details
  Future<void> _addInvoices() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null) return;

    final files = result.paths.whereType<String>().map((p) => File(p)).toList();
    for (final file in files) {
      final fileName = file.path.split('/').last;
      final ext = fileName.split('.').last.toLowerCase();
      final fileType = ext == 'pdf'
          ? 'application/pdf'
          : ext == 'png'
          ? 'image/png'
          : 'image/jpeg';

      final invoice = await _invoiceService.uploadInvoice(
        taskUuid: widget.taskUuid,
        file: file,
        fileName: fileName,
        fileType: fileType,
      );
      if (invoice != null && mounted) {
        setState(() => _invoices.add(invoice));
      }
    }
  }

  Future<void> _downloadInvoice(Invoice invoice) async {
    setState(() => _downloadingInvoiceUuid = invoice.invoiceUuid);
    try {
      final urlResponse =
      await _invoiceService.getInvoiceDownloadLink(invoice.invoiceUuid);
      if (urlResponse.statusCode != 200 || urlResponse.data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get download link')),
          );
        }
        return;
      }

      final s3Response = await http.get(Uri.parse(urlResponse.data!));
      if (s3Response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to download file')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${invoice.fileName}');
      await file.writeAsBytes(s3Response.bodyBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: invoice.fileType)],
        subject: invoice.fileName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingInvoiceUuid = null);
    }
  }

  Future<void> _deleteInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete invoice'),
        content: Text('Are you sure you want to delete ${invoice.fileName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _invoiceService.deleteInvoice(invoice.invoiceUuid);
    if (success) {
      setState(() =>
          _invoices.removeWhere((i) => i.invoiceUuid == invoice.invoiceUuid));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete invoice')),
        );
      }
    }
  }

  Future<void> _showMarkCompleteSheet(
      BuildContext context, MaintenanceTask task) async {
    final List<File> selectedFiles = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Mark as Completed',
                        style:
                        Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Optionally attach invoices or receipts',
                        style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.pickFiles(
                          allowMultiple: true,
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
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
                      label: const Text('Add Invoices'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedFiles.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: selectedFiles.length,
                        itemBuilder: (context, index) {
                          final file = selectedFiles[index];
                          final fileName = file.path.split('/').last;
                          final ext = fileName.split('.').last.toLowerCase();
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              ext == 'pdf'
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
                              onPressed: () => setSheetState(
                                      () => selectedFiles.removeAt(index)),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirm'),
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
            );
          },
        );
      },
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_task == null || _car == null) {
      return const Scaffold(body: Center(child: Text("Not found")));
    }

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final task = _task!;
    final car = _car!;

    bool isTaskCompleted = task.completedDate != null;
    bool isTaskOverdue = isTaskCompleted
        ? false
        : task.scheduledDate!.compareTo(DateTime.now()) < 0;

    String statusText;
    IconData statusIcon;
    Color statusIconColor;

    if (isTaskCompleted) {
      statusText = "Completed";
      statusIcon = Icons.check_circle;
      statusIconColor = Colors.green;
    } else if (isTaskOverdue) {
      statusText = "Overdue";
      statusIcon = Icons.cancel;
      statusIconColor = Colors.red;
    } else {
      statusText = "Scheduled";
      statusIcon = Icons.schedule;
      statusIconColor = Colors.yellow;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Task details"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ListTile(
              title: Text(
                task.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                "For ${car.name}",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
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
                          TaskInfoTileWidget(
                              label: "Status", text: statusText),
                          Icon(statusIcon, size: 36, color: statusIconColor),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TaskInfoTileWidget(
                            label: "Date",
                            text: isTaskCompleted
                                ? formatDate(task.completedDate!)
                                : formatDate(task.scheduledDate!),
                          ),
                          Icon(Icons.event,
                              size: 36,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TaskInfoTileWidget(
                            label: "Cost",
                            text: task.cost == null
                                ? "No cost provided"
                                : task.cost.toString(),
                          ),
                          Icon(Icons.paid,
                              size: 36,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TaskInfoTileWidget(
                            label: "Mileage",
                            text: task.mileage == null
                                ? "No mileage provided"
                                : task.mileage.toString(),
                          ),
                          Icon(Icons.speed,
                              size: 36,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                      const Divider(),
                      TaskInfoTileWidget(
                        label: "Notes",
                        text: task.notes == null || task.notes == ""
                            ? "There are no notes for this task"
                            : task.notes!,
                      ),
                      const Divider(),

                      if (!isTaskCompleted)
                        Row(
                          children: [
                            const Text("Mark as completed"),
                            IconButton(
                              onPressed: () =>
                                  _showMarkCompleteSheet(context, task),
                              icon: const Icon(Icons.radio_button_unchecked),
                            ),
                          ],
                        ),

                      //Invoices section
                      if (isTaskCompleted) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Invoices & Attachments",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_loadingInvoices)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                TextButton.icon(
                                  icon: const Icon(Icons.attach_file),
                                  label: const Text('Add'),
                                  onPressed: _addInvoices,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!_loadingInvoices && _invoices.isEmpty)
                          Text(
                            "No invoices attached",
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _invoices.length,
                            itemBuilder: (context, index) {
                              final invoice = _invoices[index];
                              final ext = invoice.fileName
                                  .split('.')
                                  .last
                                  .toLowerCase();
                              final isDownloading =
                                  _downloadingInvoiceUuid ==
                                      invoice.invoiceUuid;

                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  ext == 'pdf'
                                      ? Icons.picture_as_pdf
                                      : Icons.image,
                                  color:
                                  Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  invoice.fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle:
                                Text(_formatFileSize(invoice.fileSize)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    isDownloading
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                        : IconButton(
                                      icon: const Icon(Icons.download),
                                      onPressed: () =>
                                          _downloadInvoice(invoice),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _deleteInvoice(invoice),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
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
                        builder: (_) => TaskFormScreen(
                            carUuid: widget.carUuid, task: task)),
                  ),
                  child: const Text("Edit"),
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
                    await taskProvider.deleteTask(widget.taskUuid);
                    if (navigator.canPop()) navigator.pop();
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
}