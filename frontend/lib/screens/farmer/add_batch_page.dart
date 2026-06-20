import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/bamboo_types.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/profile_completion_guard.dart';
import '../../widgets/image_picker_field.dart';

class AddBatchPage extends StatefulWidget {
  @override
  _AddBatchPageState createState() => _AddBatchPageState();
}

class _AddBatchPageState extends State<AddBatchPage> {
  final _formKey = GlobalKey<FormState>();
  final _batchIdController = TextEditingController();
  final _quantityController = TextEditingController();
  final _quantityUnitController = TextEditingController(text: 'kg');
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final _availableFromDateController = TextEditingController();
  final _expectedHarvestDateController = TextEditingController();
  final ApiService apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  String _selectedType = 'Other / Unknown';
  bool _availableNow = true;
  bool _isSaving = false;
  DateTime? _availableFromDate;
  DateTime? _expectedHarvestDate;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  String _formatDisplayDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  String _formatApiDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDate({
    required DateTime? initialDate,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (selectedDate != null) {
      onPicked(selectedDate);
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
    });
  }

  @override
  void dispose() {
    _batchIdController.dispose();
    _quantityController.dispose();
    _quantityUnitController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _availableFromDateController.dispose();
    _expectedHarvestDateController.dispose();
    super.dispose();
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;
    final profileComplete = await ensureProfileComplete(
      context,
      message: 'Please complete your profile before listing batches.',
    );
    if (!profileComplete) return;

    setState(() => _isSaving = true);
    try {
      final imageUrl = _selectedImage == null
          ? null
          : await apiService.uploadImage(_selectedImage!);
      await apiService.addBatch({
        'batchId': _batchIdController.text.trim(),
        'quantityAvailable': int.parse(_quantityController.text.trim()),
        'quantityUnit': _quantityUnitController.text.trim(),
        'location': _locationController.text.trim(),
        'type': _selectedType,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'availableNow': _availableNow,
        'status': _availableNow ? 'available' : 'upcoming',
        if (_priceController.text.trim().isNotEmpty)
          'price': double.parse(_priceController.text.trim()),
        if (!_availableNow && _availableFromDate != null)
          'availableFromDate': _formatApiDate(_availableFromDate!),
        if (!_availableNow && _expectedHarvestDate != null)
          'expectedHarvestDate': _formatApiDate(_expectedHarvestDate!),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Batch added successfully')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      if (await handleProfileRequired(context, e)) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Batch'),
        backgroundColor: Colors.green[700],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _batchIdController,
                decoration: InputDecoration(
                  labelText: 'Batch ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Batch ID is required'
                    : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity available',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Quantity is required';
                  if (int.tryParse(value) == null)
                    return 'Enter a valid number';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _quantityUnitController,
                decoration: InputDecoration(
                  labelText: 'Quantity unit',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Unit is required' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price (optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  if (double.tryParse(value) == null)
                    return 'Enter a valid price';
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Bamboo type',
                  border: OutlineInputBorder(),
                ),
                items: bambooTypeOptions
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              SizedBox(height: 16),
              ImagePickerField(
                label: 'Batch image',
                imageBytes: _selectedImageBytes,
                isBusy: _isSaving,
                onPick: _pickImage,
                onClear: () => setState(() {
                  _selectedImage = null;
                  _selectedImageBytes = null;
                }),
              ),
              SizedBox(height: 16),
              SwitchListTile(
                value: _availableNow,
                onChanged: (value) => setState(() {
                  _availableNow = value;
                  if (value) {
                    _availableFromDate = null;
                    _expectedHarvestDate = null;
                    _availableFromDateController.clear();
                    _expectedHarvestDateController.clear();
                  }
                }),
                title: Text('Available now'),
                subtitle: Text(
                  _availableNow
                      ? 'Artisans can buy immediately'
                      : 'List as upcoming material',
                ),
              ),
              if (!_availableNow) ...[
                SizedBox(height: 16),
                TextFormField(
                  controller: _availableFromDateController,
                  decoration: InputDecoration(
                    labelText: 'Available from date (optional)',
                    hintText: 'dd-MM-yyyy',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: () => _pickDate(
                        initialDate: _availableFromDate,
                        onPicked: (date) => setState(() {
                          _availableFromDate = date;
                          _availableFromDateController.text =
                              _formatDisplayDate(date);
                        }),
                      ),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _pickDate(
                    initialDate: _availableFromDate,
                    onPicked: (date) => setState(() {
                      _availableFromDate = date;
                      _availableFromDateController.text = _formatDisplayDate(
                        date,
                      );
                    }),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _expectedHarvestDateController,
                  decoration: InputDecoration(
                    labelText: 'Expected harvest date',
                    hintText: 'dd-MM-yyyy',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: () => _pickDate(
                        initialDate: _expectedHarvestDate,
                        onPicked: (date) => setState(() {
                          _expectedHarvestDate = date;
                          _expectedHarvestDateController.text =
                              _formatDisplayDate(date);
                        }),
                      ),
                    ),
                  ),
                  readOnly: true,
                  onTap: () => _pickDate(
                    initialDate: _expectedHarvestDate,
                    onPicked: (date) => setState(() {
                      _expectedHarvestDate = date;
                      _expectedHarvestDateController.text = _formatDisplayDate(
                        date,
                      );
                    }),
                  ),
                  validator: (value) {
                    if (_availableNow) return null;
                    if (_expectedHarvestDate == null &&
                        _availableFromDate == null) {
                      return 'Provide harvest date or available from date';
                    }
                    return null;
                  },
                ),
              ],
              SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Location',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Location is required'
                    : null,
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveBatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                  ),
                  child: Text(_isSaving ? 'Adding...' : 'Add Batch'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
