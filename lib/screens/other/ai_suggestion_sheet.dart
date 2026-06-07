import 'package:car_maintenance_tracker/models/car.dart';
import 'package:car_maintenance_tracker/models/maintenance_task.dart';
import 'package:car_maintenance_tracker/providers/task_provider.dart';
import 'package:car_maintenance_tracker/services/api_ai_service.dart';
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

  String _fuelType = 'petrol';
  String _transmissionType = 'manual';

  bool _isLoading = false;
  List<MaintenanceTask>? _suggestions;
  String? _error;
  final Set<int> _selectedIndices = {};

  @override
  void dispose() {
    _lastOilChangeCtrl.dispose();
    _knownIssuesCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _aiService.getSuggestions(
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

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _suggestions = response.data;
          // Select all by default
          _selectedIndices.addAll(
            List.generate(response.data!.length, (i) => i),
          );
        });
      } else {
        setState(() => _error = 'Failed to get suggestions. Please try again.');
      }
    } catch (e) {
      setState(() => _error = 'AI service unavailable. Please try again later.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmSuggestions() async {
    final taskProvider = context.read<TaskProvider>();
    final selectedTasks = _selectedIndices
        .map((i) => _suggestions![i])
        .toList();

    for (final task in selectedTasks) {
      await taskProvider.addTask(task);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedTasks.length} task${selectedTasks.length == 1 ? '' : 's'} added successfully!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _suggestions == null
                      ? 'AI Maintenance Suggestions'
                      : 'Suggested Tasks',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _suggestions == null
                      ? 'Answer a few questions about your ${widget.car.name}'
                      : 'Select the tasks you want to add',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ),
              const Divider(height: 24),

              Expanded(
                child: _isLoading
                    ? _buildLoading()
                    : _error != null
                    ? _buildError()
                    : _suggestions == null
                    ? _buildForm(scrollController)
                    : _buildSuggestions(scrollController),
              ),

              if (!_isLoading)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _suggestions == null
                        ? ElevatedButton(
                      onPressed: _generateSuggestions,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor:
                        Theme.of(context).colorScheme.primary,
                        foregroundColor:
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text('Generate Suggestions'),
                    )
                        : ElevatedButton(
                      onPressed: _selectedIndices.isEmpty
                          ? null
                          : _confirmSuggestions,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Add ${_selectedIndices.length} Task${_selectedIndices.length == 1 ? '' : 's'}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analyzing your car...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _error = null),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Fuel type
        const Text('Fuel Type',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'petrol', label: Text('Petrol')),
            ButtonSegment(value: 'diesel', label: Text('Diesel')),
            ButtonSegment(value: 'electric', label: Text('Electric')),
            ButtonSegment(value: 'hybrid', label: Text('Hybrid')),
          ],
          selected: {_fuelType},
          onSelectionChanged: (v) => setState(() => _fuelType = v.first),
        ),
        const SizedBox(height: 16),

        // Transmission type
        const Text('Transmission',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'manual', label: Text('Manual')),
            ButtonSegment(value: 'automatic', label: Text('Automatic')),
          ],
          selected: {_transmissionType},
          onSelectionChanged: (v) =>
              setState(() => _transmissionType = v.first),
        ),
        const SizedBox(height: 16),

        // Last oil change
        TextField(
          controller: _lastOilChangeCtrl,
          decoration: const InputDecoration(
            labelText: 'Last oil change (km) — optional',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.oil_barrel),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),

        // Known issues
        TextField(
          controller: _knownIssuesCtrl,
          decoration: const InputDecoration(
            labelText: 'Known issues — optional',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.warning_amber),
            hintText: 'e.g. brakes feel soft, AC not cold',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuggestions(ScrollController scrollController) {
    if (_suggestions!.isEmpty) {
      return const Center(
        child: Text('No suggestions available for this car.'),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _suggestions!.length,
      itemBuilder: (context, index) {
        final task = _suggestions![index];
        final isSelected = _selectedIndices.contains(index);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.category),
                if (task.mileage != null)
                  Text('Due at: ${task.mileage} km'),
                if (task.notes != null)
                  Text(
                    task.notes!,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            isThreeLine: task.notes != null,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      },
    );
  }
}