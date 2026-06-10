import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/car.dart';
import '../../providers/auth_provider.dart';
import '../../providers/car_provider.dart';
import '../other/ai_suggestion_sheet.dart';
import 'package:car_maintenance_tracker/utils/api_exception.dart';
import 'package:car_maintenance_tracker/utils/snack_bar_helper.dart';

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

  File? _newImageFile;
  String? _existingImageUrl;
  bool _isSaving = false;

  bool get _isEditing => widget.car != null;

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
      _existingImageUrl = widget.car!.imageUrl;
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

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Choose photo source",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text("Take a photo"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text("Choose from gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_newImageFile != null || _existingImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("Remove photo", style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _newImageFile = null;
                      _existingImageUrl = null;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final provider = Provider.of<CarProvider>(context, listen: false);
    final userProvider = Provider.of<AuthProvider>(context, listen: false);

    final name = _nameCtrl.text.trim();
    final make = _makeCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final year = int.parse(_yearCtrl.text.trim());
    final vin = _vinCtrl.text.trim();
    final mileage = int.parse(_mileageCtrl.text.trim());
    final license = _licenseCtrl.text.trim();

    try {
      if (_isEditing) {
        final updated = widget.car!.copyWith(
          name: name,
          make: make,
          model: model,
          year: year,
          vin: vin,
          mileage: mileage,
          licensePlate: license,
          imageKey: widget.car!.imageKey,
        );
        await provider.updateCar(updated, imageFile: _newImageFile);
        if (mounted) {
          showTopSnackBar(context, "Vehicle updated successfully");
          Navigator.pop(context);
        }
      } else {
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
        final newCar = await provider.addCar(car, imageFile: _newImageFile);
        if (mounted) {
          final rootContext = Navigator.of(context).context;
          Navigator.pop(context);
          showTopSnackBar(rootContext, "${car.name} added successfully");
          WidgetsBinding.instance.addPostFrameCallback((_) {
              _showAISuggestionsDialog(rootContext, newCar);
          });
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        showTopSnackBar(context, e.message, type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAISuggestionsDialog(BuildContext context, Car car) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text("AI Suggestions"),
          ],
        ),
        content: Text("Would you like AI to suggest maintenance tasks for your ${car.name}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No thanks"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                isDismissible: false,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => AISuggestionsSheet(car: car),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Let's go!"),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(ColorScheme colorScheme) {
    Widget imageWidget;

    if (_newImageFile != null) {
      imageWidget = CircleAvatar(
        radius: 56,
        backgroundImage: FileImage(_newImageFile!),
      );
    } else if (_existingImageUrl != null) {
      imageWidget = CachedNetworkImage(
        imageUrl: _existingImageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 56,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: 56,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
          child: const CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => _defaultAvatar(colorScheme),
      );
    } else {
      imageWidget = _defaultAvatar(colorScheme);
    }

    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          imageWidget,
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.camera_alt_rounded,
              size: 16,
              color: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar(ColorScheme colorScheme) {
    return CircleAvatar(
      radius: 56,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
      child: Icon(
        Icons.directions_car_rounded,
        size: 48,
        color: colorScheme.primary.withValues(alpha: 0.7),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Vehicle" : "Add Vehicle"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _buildImagePicker(colorScheme)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  "Tap to change photo",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              _sectionLabel("Basic Information"),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration:
                _fieldDecoration("Name", isDark),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Please enter a name"
                    : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _makeCtrl,
                      decoration: _fieldDecoration(
                          "Make", isDark),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? "Required"
                          : null,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modelCtrl,
                      decoration: _fieldDecoration(
                          "Model", isDark),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? "Required"
                          : null,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(
                          "Year", isDark),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Required";
                        }
                        final year = int.tryParse(v);
                        if (year == null ||
                            year < 1886 ||
                            year > DateTime.now().year) {
                          return "Invalid year";
                        }
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _mileageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration("Mileage (km)", isDark),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Required";
                        }
                        final m = int.tryParse(v);
                        if (m == null || m < 0) return "Invalid";
                        return null;
                      },
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionLabel("Identification"),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vinCtrl,
                decoration:
                _fieldDecoration("VIN", isDark),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Please enter the VIN"
                    : null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseCtrl,
                decoration: _fieldDecoration("License Plate", isDark),
                validator: (v) => v == null || v.trim().isEmpty
                    ? "Please enter the license plate"
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSaving
                  ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimary,
                ),
              ) : Text(
                _isEditing ? "Save Changes" : "Add Vehicle",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade500,
        letterSpacing: 0.5,
      ),
    );
  }
}