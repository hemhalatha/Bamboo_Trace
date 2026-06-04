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
  final _locationController = TextEditingController();
  String _selectedType = 'Premium';

  final ApiService apiService = ApiService(baseUrl: 'https://your-backend-url/api'); // Replace with deployed backend URL

  @override
  void dispose() {
    _batchIdController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;

    final batchData = {
      'batchId': _batchIdController.text.trim(),
      'quantity': int.parse(_quantityController.text.trim()),
      'location': _locationController.text.trim(),
      'type': _selectedType,
    };

    var response = await apiService.addBatch(batchData);
    if (response != null && response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch added successfully')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add batch')));
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
                decoration: InputDecoration(labelText: 'Batch ID', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Batch ID is required' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: 'Quantity (kg)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Quantity is required';
                  if (int.tryParse(value) == null) return 'Enter a valid number';
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                items: ['Premium', 'Standard', 'Organic']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(labelText: 'Location', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Location is required' : null,
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveBatch,
                  child: Text('Add Batch'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
