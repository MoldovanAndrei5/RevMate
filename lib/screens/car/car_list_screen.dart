import 'package:car_maintenance_tracker/screens/car/car_details_screen.dart';
import 'package:car_maintenance_tracker/widgets/bottom_navbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/car_provider.dart';
import '../../widgets/car_list_widget.dart';
import 'car_form_screen.dart';

class CarListScreen extends StatefulWidget {
  const CarListScreen({super.key});

  @override
  State<CarListScreen> createState() => CarListScreenState();
}

class CarListScreenState extends State<CarListScreen> {
  late TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    final carProvider = context.read<CarProvider>();
    searchController = TextEditingController(text: carProvider.getSearchQuery());
  }

  @override
  Widget build(BuildContext context) {
    final carProvider = context.watch<CarProvider>();
    final cars = carProvider.getFilteredCars();

    return Scaffold(
      appBar: AppBar(title: const Text('My Cars'), centerTitle: true,),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SearchBar(
              controller: searchController,
              hintText: 'Search cars...',
              leading: const Icon(Icons.search),
              onChanged: (value) => carProvider.updateSearchQuery(value),
              elevation: WidgetStatePropertyAll(1),
              //backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primaryContainer),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: cars.isEmpty
              ? carProvider.getSearchQuery() == ''
                  ? const Center(child: Text('No cars yet. Tap + to add one.'))
                  : const Center(child: Text('No results for your search'))
              : ListView.builder(
                itemCount: cars.length,
                itemBuilder: (context, index) {
                  final car = cars[index];
                  return CarListWidget(
                    car: car,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CarDetailsScreen(carUuid: car.carUuid!)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CarFormScreen()),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: const BottomNavbarWidget(),
      ),
    );
  }
}
