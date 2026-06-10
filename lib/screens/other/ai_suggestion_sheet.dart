import 'package:car_maintenance_tracker/models/car.dart';
import 'package:car_maintenance_tracker/models/maintenance_task.dart';
import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/services/api_ai_service.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:car_maintenance_tracker/utils/snack_bar_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AISuggestionsSheet extends StatefulWidget {
  final Car car;

  const AISuggestionsSheet({super.key, required this.car});

  @override
  State<AISuggestionsSheet> createState() => _AISuggestionsSheetState();
}

class _AISuggestionsSheetState extends State<AISuggestionsSheet> {
  final ApiAiService _aiService = ApiAiService();
  final _lastOilChangeCtrl = TextEditingController();
  final _knownIssuesCtrl = TextEditingController();
  final _scrollController = ScrollController();

  String _fuelType = "petrol";
  String _transmissionType = "manual";
  bool _isLoading = false;
  List<MaintenanceTask>? _suggestions;
  String? _error;
  final Set<int> _selectedIndices = {};

  @override
  void dispose() {
    _lastOilChangeCtrl.dispose();
    _knownIssuesCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _generateSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final tasks = await _aiService.getSuggestions(
        carUuid: widget.car.carUuid!,
        make: widget.car.make,
        model: widget.car.model,
        year: widget.car.year,
        mileage: widget.car.mileage,
        fuelType: _fuelType,
        transmissionType: _transmissionType,
        lastOilChangeKm: int.tryParse(_lastOilChangeCtrl.text.trim()),
        knownIssues: _knownIssuesCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _suggestions = tasks;
          _selectedIndices.addAll(List.generate(tasks.length, (i) => i));
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmSuggestions() async {
    final taskProvider = context.read<TaskProvider>();
    final selectedTasks = _selectedIndices.map((i) => _suggestions![i]).toList();
    for (final task in selectedTasks) {
      await taskProvider.addTask(task);
    }
    if (mounted) {
      Navigator.pop(context);
      showTopSnackBar(context, "${selectedTasks.length} task${selectedTasks.length == 1 ? "" : "s"} added successfully!");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _suggestions == null
                                  ? "AI Maintenance Suggestions"
                                  : "Suggested Tasks",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _suggestions == null
                                  ? "Tell us about your ${widget.car.name}"
                                  : "Select the tasks you want to add",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),

                // Content
                Expanded(
                  child: _isLoading
                      ? _buildLoading(colorScheme)
                      : _error != null
                      ? _buildError(colorScheme)
                      : _suggestions == null
                      ? _buildForm(
                      scrollController, colorScheme, isDark)
                      : _buildSuggestions(
                      scrollController, colorScheme, isDark),
                ),

                if (!_isLoading)
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: _suggestions == null ? SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _generateSuggestions,
                          icon: const Icon(
                              Icons.auto_awesome_rounded,
                              size: 18),
                          label: const Text(
                            "Generate Suggestions",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ) : SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _selectedIndices.isEmpty
                              ? null
                              : _confirmSuggestions,
                          icon: const Icon(Icons.check_rounded,
                              size: 18),
                          label: Text(
                            _selectedIndices.isEmpty
                                ? "Select tasks to add"
                                : "Add ${_selectedIndices.length} Task${_selectedIndices.length == 1 ? "" : "s"}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: colorScheme.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Analyzing your ${widget.car.name}...",
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "This may take a few seconds",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => setState(() => _error = null),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Try Again"),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
      ScrollController scrollController,
      ColorScheme colorScheme,
      bool isDark,
      ) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      children: [
        _fieldLabel("Fuel Type"),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: "petrol", label: Text("Petrol")),
            ButtonSegment(value: "diesel", label: Text("Diesel")),
            ButtonSegment(value: "electric", label: Text("Electric")),
            ButtonSegment(value: "hybrid", label: Text("Hybrid")),
          ],
          selected: {_fuelType},
          onSelectionChanged: (v) => setState(() => _fuelType = v.first),
          style: ButtonStyle(
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _fieldLabel("Transmission"),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: "manual", label: Text("Manual")),
            ButtonSegment(value: "automatic", label: Text("Automatic")),
          ],
          selected: {_transmissionType},
          onSelectionChanged: (v) => setState(() => _transmissionType = v.first),
          style: ButtonStyle(
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _fieldLabel("Last Oil Change"),
        const SizedBox(height: 8),
        TextField(
          controller: _lastOilChangeCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Mileage at last oil change (km) — optional",
            prefixIcon: const Icon(Icons.oil_barrel_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 20),

        _fieldLabel("Known Issues"),
        const SizedBox(height: 8),
        TextField(
          controller: _knownIssuesCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: "Describe any known issues — optional",
            hintText: "e.g. brakes feel soft, AC not cold...",
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 60),
              child: Icon(Icons.warning_amber_outlined),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor:
            isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSuggestions(
      ScrollController scrollController,
      ColorScheme colorScheme,
      bool isDark,
      ) {
    if (_suggestions!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              "No suggestions for this car.",
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              "Your car appears to be in good shape!",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Select all / deselect all
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${_suggestions!.length} suggestion${_suggestions!.length == 1 ? "" : "s"}",
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (_selectedIndices.length == _suggestions!.length) {
                      _selectedIndices.clear();
                    } else {
                      _selectedIndices.addAll(List.generate(_suggestions!.length, (i) => i));
                    }
                  });
                },
                child: Text(
                  _selectedIndices.length == _suggestions!.length
                      ? "Deselect all"
                      : "Select all",
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            itemCount: _suggestions!.length,
            itemBuilder: (context, index) {
              final task = _suggestions![index];
              final isSelected = _selectedIndices.contains(index);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected
                      ? BorderSide(color: colorScheme.primary, width: 1.5)
                      : BorderSide.none,
                ),
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.05)
                    : null,
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIndices.add(index);
                      } else {
                        _selectedIndices.remove(index);
                      }
                    });
                  },
                  title: Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          task.category,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (task.mileage != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.speed_outlined,
                                size: 12,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(
                              "Due at ${task.mileage} km",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (task.notes != null && task.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.notes!,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  isThreeLine: false,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }
}