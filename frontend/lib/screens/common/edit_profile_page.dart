import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/auth_user.dart';
import '../../services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.user});

  final AuthUser user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _addressLineController;
  late final TextEditingController _cityController;
  late final TextEditingController _districtController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _landmarkController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.user.phone ?? '');
    _addressLineController =
        TextEditingController(text: widget.user.addressLine ?? '');
    _cityController = TextEditingController(text: widget.user.city ?? '');
    _districtController = TextEditingController(text: widget.user.district ?? '');
    _stateController = TextEditingController(text: widget.user.state ?? '');
    _pincodeController = TextEditingController(text: widget.user.pincode ?? '');
    _landmarkController = TextEditingController(text: widget.user.landmark ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressLineController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  String get _locationLabel {
    if (widget.user.role == 'artisan') return 'Workshop/business location';
    if (widget.user.role == 'farmer') return 'Farm/pickup location';
    return 'Delivery/contact address';
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validatePhone(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    final phone = value!.trim();
    if (!RegExp(r'^[0-9+\-\s()]{7,30}$').hasMatch(phone)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validatePincode(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    final pincode = value!.trim();
    if (!RegExp(r'^[0-9A-Za-z\-\s]{3,20}$').hasMatch(pincode)) {
      return 'Enter a valid pincode';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await context.read<AuthService>().updateProfile({
      'phone': _phoneController.text.trim(),
      'addressLine': _addressLineController.text.trim(),
      'city': _cityController.text.trim(),
      'district': _districtController.text.trim(),
      'state': _stateController.text.trim(),
      'pincode': _pincodeController.text.trim(),
      'landmark': _landmarkController.text.trim(),
    });
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated')),
      );
      Navigator.pop(context);
    } else {
      final error = context.read<AuthService>().errorMessage ?? 'Save failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<AuthService>().isLoading;
    return Scaffold(
      appBar: AppBar(title: Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            Text(
              _locationLabel,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone *',
                border: OutlineInputBorder(),
              ),
              validator: _validatePhone,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _addressLineController,
              decoration: InputDecoration(
                labelText: 'Address line *',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'City *',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _districtController,
              decoration: InputDecoration(
                labelText: 'District *',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _stateController,
              decoration: InputDecoration(
                labelText: 'State *',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _pincodeController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Pincode *',
                border: OutlineInputBorder(),
              ),
              validator: _validatePincode,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _landmarkController,
              decoration: InputDecoration(
                labelText: 'Landmark (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: isSaving ? null : _save,
                child: isSaving
                    ? CircularProgressIndicator()
                    : Text('Save Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
