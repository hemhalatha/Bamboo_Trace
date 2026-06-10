import 'package:flutter/material.dart';

import '../../services/api_service.dart';

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
  String _selectedType = 'Premium';
  bool _availableNow = true;
  bool _isSaving = false;

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

    setState(() => _isSaving = true);
    try {
      await apiService.addBatch({
        'batchId': _batchIdController.text.trim(),
        'quantityAvailable': int.parse(_quantityController.text.trim()),
        'quantityUnit': _quantityUnitController.text.trim(),
        'location': _locationController.text.trim(),
        'type': _selectedType,
        'availableNow': _availableNow,
        'status': _availableNow ? 'available' : 'upcoming',
        if (_priceController.text.trim().isNotEmpty)
          'price': double.parse(_priceController.text.trim()),
        if (!_availableNow && _availableFromDateController.text.trim().isNotEmpty)
          'availableFromDate': _availableFromDateController.text.trim(),
        if (!_availableNow && _expectedHarvestDateController.text.trim().isNotEmpty)
          'expectedHarvestDate': _expectedHarvestDateController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Batch added successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add batch: $e')),
      );
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
                validator: (value) =>
                    value == null || value.isEmpty ? 'Batch ID is required' : null,
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
                  if (value == null || value.isEmpty) return 'Quantity is required';
                  if (int.tryParse(value) == null) return 'Enter a valid number';
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
                  if (double.tryParse(value) == null) return 'Enter a valid price';
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: ['Premium', 'Standard', 'Organic']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              SizedBox(height: 16),
              SwitchListTile(
                value: _availableNow,
                onChanged: (value) => setState(() => _availableNow = value),
                title: Text('Available now'),
                subtitle: Text(_availableNow
                    ? 'Artisans can buy immediately'
                    : 'List as upcoming material'),
              ),
              if (!_availableNow) ...[
                SizedBox(height: 16),
                TextFormField(
                  controller: _availableFromDateController,
                  decoration: InputDecoration(
                    labelText: 'Available from date (ISO, optional)',
                    hintText: '2026-07-15T00:00:00Z',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _expectedHarvestDateController,
                  decoration: InputDecoration(
                    labelText: 'Expected harvest date',
                    hintText: '2026-07-15T00:00:00Z',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_availableNow) return null;
                    if ((value == null || value.isEmpty) &&
                        _availableFromDateController.text.trim().isEmpty) {
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
                validator: (value) =>
                    value == null || value.isEmpty ? 'Location is required' : null,
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveBatch,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                  child: Text(_isSaving ? 'Adding...' : 'Add Batch'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
