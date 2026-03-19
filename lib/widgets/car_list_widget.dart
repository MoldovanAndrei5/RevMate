import 'dart:io';

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

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          backgroundImage: car.imagePath != null ? FileImage(File(car.imagePath!)) : AssetImage("assets/P90203628-bmw-m4-coup-with-bmw-m-performance-parts-side-view-11-2015-2002px.jpg"),
        ),
        title: Text(
            car.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${car.year} ${car.make} ${car.model}',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_forward_ios),
          ],
        ),
      ),
    );
  }
}
