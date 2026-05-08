import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  File? _newImageFile;         // newly picked image file
  String? _existingImageUrl;   // presigned URL from server for existing image
  bool _isSaving = false;

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
      _existingImageUrl = widget.car!.imageUrl; // presigned URL from server
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

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1000,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _newImageFile = File(picked.path));
    }
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (_) => SafeArea(
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
      ),
    );
  }


  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the errors in red')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = Provider.of<CarProvider>(context, listen: false);
    final userProvider = Provider.of<AuthProvider>(context, listen: false);
    final isEditing = widget.car != null;

    final name = _nameCtrl.text.trim();
    final make = _makeCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final year = int.parse(_yearCtrl.text.trim());
    final vin = _vinCtrl.text.trim();
    final mileage = int.parse(_mileageCtrl.text.trim());
    final license = _licenseCtrl.text.trim();

    try {
      if (isEditing) {
        final updated = widget.car!.copyWith(
          name: name,
          make: make,
          model: model,
          year: year,
          vin: vin,
          mileage: mileage,
          licensePlate: license,
        );
        // Pass new image file if picked, otherwise keeps existing imageKey
        await provider.updateCar(updated, imageFile: _newImageFile);
      } else {
        if (userProvider.userId == null) throw Exception("User not logged in");
        final car = Car(
          userId: userProvider.userId,
          name: name,
          make: make,
          model: model,
          year: year,
          vin: vin,
          mileage: mileage,
          licensePlate: license,
        );
        await provider.addCar(car, imageFile: _newImageFile);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildImageAvatar() {
    if (_newImageFile != null) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: FileImage(_newImageFile!),
      );
    }
    // Existing image from server
    if (_existingImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: _existingImageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 50,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => const CircleAvatar(
          radius: 50,
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => const CircleAvatar(
          radius: 50,
          child: Icon(Icons.add_a_photo, size: 30),
        ),
      );
    }
    return const CircleAvatar(
      radius: 50,
      child: Icon(Icons.add_a_photo, size: 30),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.car != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Car' : 'Add Car'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _showImageSourceSheet(context),
                child: _buildImageAvatar(),
              ),
              const SizedBox(height: 4),
              const Text("Tap to select image"),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter the name for the car'
                    : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _makeCtrl,
                decoration: const InputDecoration(labelText: 'Make'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter the make of the car'
                    : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _modelCtrl,
                decoration: const InputDecoration(labelText: 'Model'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter the model of the car'
                    : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _yearCtrl,
                decoration: const InputDecoration(labelText: 'Year'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter the year';
                  }
                  final year = int.tryParse(v);
                  if (year == null ||
                      year < 1886 ||
                      year > DateTime.now().year) {
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
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter the VIN of the car'
                    : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mileageCtrl,
                decoration:
                const InputDecoration(labelText: 'Mileage (in kilometers)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter the mileage';
                  }
                  final mileage = int.tryParse(v);
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
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter the license plate'
                    : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
                : const Text('Save'),
          ),
        ),
      ),
    );
  }
}