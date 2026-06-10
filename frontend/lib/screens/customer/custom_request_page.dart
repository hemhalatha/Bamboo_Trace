import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class CustomRequestPage extends StatefulWidget {
  const CustomRequestPage({super.key});

  @override
  State<CustomRequestPage> createState() => _CustomRequestPageState();
}

class _CustomRequestPageState extends State<CustomRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _budgetController = TextEditingController();
  final _deadlineController = TextEditingController();
  final _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _artisansFuture;
  String _targetType = 'specific_artisan';
  String? _selectedArtisanId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _artisansFuture = _apiService.getArtisans();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _budgetController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetType == 'specific_artisan' && _selectedArtisanId == null) return;
    setState(() => _isSubmitting = true);
    try {
      await _apiService.createCustomOrderRequest(
        targetType: _targetType,
        targetArtisanId:
            _targetType == 'specific_artisan' ? _selectedArtisanId : null,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        budget: _budgetController.text.trim().isEmpty
            ? null
            : double.parse(_budgetController.text.trim()),
        deadline: _deadlineController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Custom request sent')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Custom Request')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _artisansFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final artisans = snapshot.data ?? [];
          if (artisans.isEmpty) {
            return Center(child: Text('No artisans available'));
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(16),
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'specific_artisan',
                      label: Text('Specific'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: 'broadcast',
                      label: Text('Broadcast'),
                      icon: Icon(Icons.campaign),
                    ),
                  ],
                  selected: {_targetType},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _targetType = selection.first;
                      if (_targetType == 'broadcast') {
                        _selectedArtisanId = null;
                      }
                    });
                  },
                ),
                SizedBox(height: 16),
                if (_targetType == 'specific_artisan')
                  DropdownButtonFormField<String>(
                    value: _selectedArtisanId,
                    decoration: InputDecoration(
                      labelText: 'Artisan',
                      border: OutlineInputBorder(),
                    ),
                    items: artisans.map((artisan) {
                      return DropdownMenuItem(
                        value: artisan['id']?.toString(),
                        child:
                            Text('${artisan['name']} - ${artisan['location']}'),
                      );
                    }).toList(),
                    validator: (value) =>
                        value == null ? 'Select an artisan' : null,
                    onChanged: (value) =>
                        setState(() => _selectedArtisanId = value),
                  ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Title is required' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Description is required' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                  validator: (value) {
                    final quantity = int.tryParse(value ?? '');
                    if (quantity == null || quantity <= 0) return 'Enter a valid quantity';
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Budget (optional)', border: OutlineInputBorder()),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _deadlineController,
                  decoration: InputDecoration(
                    labelText: 'Deadline (optional ISO)',
                    hintText: '2026-08-01T00:00:00Z',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Sending...' : 'Send Request'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
