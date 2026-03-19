import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../models/car.dart';
import '../../providers/auth_provider.dart';
import '../../providers/car_provider.dart';

class CarFormScreen extends StatefulWidget {
  final Car? car;
  const CarFormScreen({super.key, this.car});

  @override
  State<CarFormScreen> createState() => _CarFormScreenState();
}

class _CarFormScreenState extends State<CarFormScreen> {
  final _nameCtrl = TextEditingController();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  String? _selectedImagePath;
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.car != null) {
      _nameCtrl.text = widget.car!.name;
      _makeCtrl.text = widget.car!.make;
      _modelCtrl.text = widget.car!.model;
      _yearCtrl.text = widget.car!.year.toString();
      _vinCtrl.text = widget.car!.vin;
      _mileageCtrl.text = widget.car!.mileage.toString();
      _licenseCtrl.text = widget.car!.licensePlate;
      _selectedImagePath = widget.car!.imagePath;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _vinCtrl.dispose();
    _mileageCtrl.dispose();
    _licenseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource imageSource) async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: imageSource,
      maxWidth: 1000,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String fileName = path.basename(pickedFile.path);
      final File savedImage = await File(pickedFile.path).copy("${appDocDir.path}/$fileName");
      setState(() {
        _selectedImagePath = savedImage.path;
      });
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
        builder: (BuildContext context) {
          return SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  title: const Text('Camera'),
                  leading: const Icon(Icons.photo_camera),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  title: const Text('Gallery'),
                  leading: const Icon(Icons.add_photo_alternate),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          );
        },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CarProvider>(context, listen: false);
    final userProvider = Provider.of<AuthProvider>(context, listen: false);
    final isEditing = widget.car != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Car' : 'Add Car'), centerTitle: true,),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                  onTap: () => _showImageSourceActionSheet(context),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _selectedImagePath != null ? FileImage(File(_selectedImagePath!)) : null,
                    child: _selectedImagePath == null ? const Icon(Icons.add_a_photo, size: 30) : null,
                  )
              ),
              const Text("Tap to select image"),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the name for the car';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _makeCtrl,
                decoration: const InputDecoration(labelText: 'Make'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the make of the car';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(labelText: 'Model'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the model of the car';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _yearCtrl,
                decoration: const InputDecoration(labelText: 'Year'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the year the car was manufactured in';
                  }
                  final year = int.tryParse(value);
                  if (year == null || year < 1886 || year > DateTime.now().year) {
                    return 'Please enter a valid year';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _vinCtrl,
                decoration: const InputDecoration(labelText: 'VIN'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the VIN of the car';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mileageCtrl,
                decoration: const InputDecoration(labelText: 'Mileage (in kilometers)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the mileage of the car';
                  }
                  final mileage = int.tryParse(value);
                  if (mileage == null || mileage < 0) {
                    return 'Please enter a valid mileage';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _licenseCtrl,
                decoration: const InputDecoration(labelText: 'License Plate'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the license plate of the car';
                  }
                  return null;
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final name = _nameCtrl.text.trim();
                final make = _makeCtrl.text.trim();
                final model = _modelCtrl.text.trim();
                final year = int.parse(_yearCtrl.text.trim());
                final vin = _vinCtrl.text.trim();
                final mileage = int.parse(_mileageCtrl.text.trim());
                final license = _licenseCtrl.text.trim();

                if (isEditing) {
                  final updated = widget.car!.copyWith(
                    name: name,
                    make: make,
                    model: model,
                    year: year,
                    vin: vin,
                    mileage: mileage,
                    licensePlate: license,
                    imagePath: _selectedImagePath,
                  );
                  await provider.updateCar(updated);
                }
                else {
                  if (userProvider.userId == null) {
                    throw Exception("User not logged in");
                  }
                  final car = Car(
                    userId: userProvider.userId,
                    name: name,
                    make: make,
                    model: model,
                    year: year,
                    vin: vin,
                    mileage: mileage,
                    licensePlate: license,
                    imagePath: _selectedImagePath,
                  );
                  await provider.addCar(car);
                }
                if (mounted) {
                  Navigator.pop(context);
                }
              }
              else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fix the errors in red')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ),
      ),
    );
  }
}
