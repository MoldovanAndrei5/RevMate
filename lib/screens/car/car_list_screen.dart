import 'package:cached_network_image/cached_network_image.dart';
import 'package:car_maintenance_tracker/screens/car/car_details_screen.dart';
import 'package:car_maintenance_tracker/widgets/bottom_navbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/car.dart';
import '../../providers/car_provider.dart';
import '../../widgets/sync_indicator.dart';
import 'car_form_screen.dart';

class CarListScreen extends StatefulWidget {
  const CarListScreen({super.key});

  @override
  State<CarListScreen> createState() => CarListScreenState();
}

class CarListScreenState extends State<CarListScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final carProvider = context.read<CarProvider>();
    _searchController = TextEditingController(text: carProvider.getSearchQuery());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await context.read<CarProvider>().fetchCars();
  }

  @override
  Widget build(BuildContext context) {
    final carProvider = context.watch<CarProvider>();
    final cars = carProvider.getFilteredCars();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSearching = carProvider.getSearchQuery().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Cars"),
        centerTitle: true,
        elevation: 0,
        actions: const [SyncIndicator()],
      ),
      body: Column(
        children: [
          // search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              controller: _searchController,
              hintText: "Search by name, make or model...",
              leading: const Icon(Icons.search_rounded),
              trailing: isSearching ? [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    carProvider.updateSearchQuery("");
                  },
                )
              ] : null,
              onChanged: (value) => carProvider.updateSearchQuery(value),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                isDark ? Colors.grey.shade900 : Colors.grey.shade50,
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),

          if (cars.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  Text(
                    isSearching
                        ? "${cars.length} result${cars.length == 1 ? "" : "s"}"
                        : "${cars.length} vehicle${cars.length == 1 ? "" : "s"}",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: cars.isEmpty
                ? _buildEmptyState(
                context, colorScheme, isSearching)
                : RefreshIndicator(
              onRefresh: _refresh,
              color: colorScheme.primary,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: cars.length,
                itemBuilder: (context, index) {
                  final car = cars[index];
                  return CarListWidget(
                    car: car,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CarDetailsScreen(carUuid: car.carUuid!),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "add_car",
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CarFormScreen()),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: const SafeArea(
        child: BottomNavbarWidget(),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context,
      ColorScheme colorScheme,
      bool isSearching,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching
                    ? Icons.search_off_rounded
                    : Icons.directions_car_rounded,
                size: 52,
                color: colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching ? "No results found" : "No vehicles yet",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? "Try a different name, make or model"
                  : "Tap the + button to add your first vehicle",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CarListWidget extends StatelessWidget {
  final Car car;
  final VoidCallback onTap;

  const CarListWidget({
    super.key,
    required this.car,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _buildAvatar(colorScheme),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${car.year} ${car.make} ${car.model}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.speed_outlined,
                          size: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${car.mileage} km',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    if (car.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: car.imageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 28,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: 28,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
        errorWidget: (context, url, error) => _defaultAvatar(colorScheme),
      );
    }
    return _defaultAvatar(colorScheme);
  }

  Widget _defaultAvatar(ColorScheme colorScheme) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
      child: Icon(
        Icons.directions_car_rounded,
        size: 26,
        color: colorScheme.primary.withValues(alpha: 0.7),
      ),
    );
  }
}