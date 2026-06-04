import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddProjectPage extends StatefulWidget {
  @override
  _AddProjectPageState createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _sourceBatchController = TextEditingController();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _estimatedDaysController = TextEditingController();
  double _progress = 0.0;
  String _selectedProductType = 'Furniture';

  @override
  void dispose() {
    _sourceBatchController.dispose();
    _productNameController.dispose();
    _quantityController.dispose();
    _estimatedDaysController.dispose();
    super.dispose();
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login needed')));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('projects')
          .add({
        'sourceBatchId': _sourceBatchController.text.trim(),
        'productType': _selectedProductType,
        'productName': _productNameController.text.trim(),
        'quantity': int.parse(_quantityController.text.trim()),
        'estimatedDays': int.parse(_estimatedDaysController.text.trim()),
        'progress': _progress,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Project added')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Project'),
        backgroundColor: Colors.orange[700],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _sourceBatchController,
                decoration: InputDecoration(labelText: 'Source Batch ID', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedProductType,
                decoration: InputDecoration(labelText: 'Product Type', border: OutlineInputBorder()),
                items: ['Furniture', 'Decorative', 'Utility', 'Custom']
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedProductType = v!),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _productNameController,
                decoration: InputDecoration(labelText: 'Product Name', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Enter number';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _estimatedDaysController,
                decoration: InputDecoration(labelText: 'Estimated Completion Time (days)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Enter number';
                  return null;
                },
              ),
              SizedBox(height: 20),
              Text('Initial Progress: ${(_progress * 100).toInt()}%', style: TextStyle(fontSize: 16)),
              Slider(
                value: _progress,
                onChanged: (value) => setState(() => _progress = value),
                min: 0,
                max: 1,
                divisions: 10,
                label: '${(_progress * 100).toInt()}%',
              ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveProject,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
                  child: Text('Add Project', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
