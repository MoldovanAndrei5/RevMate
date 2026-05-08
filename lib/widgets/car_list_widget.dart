import 'package:flutter/material.dart';
import '../models/car.dart';

class CarListWidget extends StatelessWidget {
  final Car car;
  final VoidCallback onTap;

  const CarListWidget({
    super.key,
    required this.car,
    required this.onTap,
  });

  ImageProvider get _imageProvider {
    if (car.imageUrl != null) return NetworkImage(car.imageUrl!);
    return const AssetImage(
        "assets/P90203628-bmw-m4-coup-with-bmw-m-performance-parts-side-view-11-2015-2002px.jpg");
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          backgroundImage: _imageProvider,
        ),
        title: Text(
          car.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${car.year} ${car.make} ${car.model}',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        onTap: onTap,
        trailing: const Icon(Icons.arrow_forward_ios),
      ),
    );
  }
}