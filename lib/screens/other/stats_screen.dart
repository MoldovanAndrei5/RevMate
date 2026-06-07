import 'package:car_maintenance_tracker/models/stats.dart';
import 'package:car_maintenance_tracker/services/api_account_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final ApiAccountService _accountService = ApiAccountService();
  AccountStats? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final stats = await _accountService.getStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
        if (stats == null) _error = 'Failed to load statistics';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStats,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(),
              const SizedBox(height: 24),
              _buildTaskStatusChart(),
              const SizedBox(height: 24),
              if (_stats!.spentByCategory.isNotEmpty) ...[
                _buildSpendByCategoryChart(),
                const SizedBox(height: 24),
              ],
              if (_stats!.tasksByMonth.isNotEmpty)
                _buildTasksByMonthChart(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final s = _stats!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.euro,
                label: 'Total Spent',
                value: '€${s.totalSpent.toStringAsFixed(2)}',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                icon: Icons.build,
                label: 'Total Tasks',
                value: '${s.totalTasks}',
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.check_circle,
                label: 'Completed',
                value: '${s.completedTasks}',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                icon: Icons.schedule,
                label: 'Pending',
                value: '${s.pendingTasks}',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                icon: Icons.warning,
                label: 'Overdue',
                value: '${s.overdueTasks}',
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskStatusChart() {
    final s = _stats!;
    if (s.totalTasks == 0) return const SizedBox.shrink();

    final sections = [
      if (s.completedTasks > 0)
        PieChartSectionData(
          value: s.completedTasks.toDouble(),
          color: Colors.green,
          title: '${s.completedTasks}',
          radius: 60,
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      if (s.pendingTasks > 0)
        PieChartSectionData(
          value: s.pendingTasks.toDouble(),
          color: Colors.orange,
          title: '${s.pendingTasks}',
          radius: 60,
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      if (s.overdueTasks > 0)
        PieChartSectionData(
          value: s.overdueTasks.toDouble(),
          color: Colors.red,
          title: '${s.overdueTasks}',
          radius: 60,
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
    ];

    return _chartCard(
      title: 'Task Status',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(sections: sections)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(Colors.green, 'Completed'),
              const SizedBox(width: 16),
              _legend(Colors.orange, 'Pending'),
              const SizedBox(width: 16),
              _legend(Colors.red, 'Overdue'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpendByCategoryChart() {
    final categories = _stats!.spentByCategory.entries.toList();
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
    ];

    final sections = categories.asMap().entries.map((entry) {
      final i = entry.key;
      final e = entry.value;
      return PieChartSectionData(
        value: e.value,
        color: colors[i % colors.length],
        title: '€${e.value.toStringAsFixed(0)}',
        radius: 60,
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      );
    }).toList();

    return _chartCard(
      title: 'Spend by Category',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(sections: sections)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: categories.asMap().entries.map((entry) {
              return _legend(
                  colors[entry.key % colors.length], entry.value.key);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksByMonthChart() {
    final months = _stats!.tasksByMonth;
    final maxY = months
        .map((m) => (m.completed + m.scheduled).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b);

    return _chartCard(
      title: 'Tasks by Month',
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY + 1,
                barGroups: months.asMap().entries.map((entry) {
                  final i = entry.key;
                  final m = entry.value;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: m.completed.toDouble(),
                        color: Colors.green,
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: m.scheduled.toDouble(),
                        color: Colors.orange,
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        final parts = months[i].month.split(' ');
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(parts[0],
                              style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: true),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(Colors.green, 'Completed'),
              const SizedBox(width: 16),
              _legend(Colors.orange, 'Scheduled'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartCard({required String title, required Widget child}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}