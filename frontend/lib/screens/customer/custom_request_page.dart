import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/profile_completion_guard.dart';
import '../../widgets/image_picker_field.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  late Future<List<Map<String, dynamic>>> _artisansFuture;
  String _targetType = 'specific_artisan';
  String? _selectedArtisanId;
  bool _isSubmitting = false;
  DateTime? _deadlineDate;
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

  Future<void> _pickDeadlineDate() async {
    final today = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _deadlineDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 5),
    );
    if (selectedDate != null) {
      setState(() {
        _deadlineDate = selectedDate;
        _deadlineController.text = _formatDisplayDate(selectedDate);
      });
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
    final profileComplete = await ensureProfileComplete(
      context,
      message: 'Please complete your profile before creating a custom request.',
    );
    if (!profileComplete) return;
    setState(() => _isSubmitting = true);
    try {
      final imageUrl = _selectedImage == null
          ? null
          : await _apiService.uploadImage(_selectedImage!);
      await _apiService.createCustomOrderRequest(
        targetType: _targetType,
        targetArtisanId: _targetType == 'specific_artisan'
            ? _selectedArtisanId
            : null,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        quantity: int.parse(_quantityController.text.trim()),
        budget: _budgetController.text.trim().isEmpty
            ? null
            : double.parse(_budgetController.text.trim()),
        deadline: _deadlineDate == null ? null : _formatApiDate(_deadlineDate!),
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Custom request sent')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      if (await handleProfileRequired(context, e)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
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
            return Center(child: Text(friendlyErrorMessage(snapshot.error)));
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
                        child: Text(
                          '${artisan['name']} - ${artisan['location']}',
                        ),
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
                  decoration: InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Title is required'
                      : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Description is required'
                      : null,
                ),
                SizedBox(height: 16),
                ImagePickerField(
                  label: 'Reference image',
                  imageBytes: _selectedImageBytes,
                  isBusy: _isSubmitting,
                  onPick: _pickImage,
                  onClear: () => setState(() {
                    _selectedImage = null;
                    _selectedImageBytes = null;
                  }),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final quantity = int.tryParse(value ?? '');
                    if (quantity == null || quantity <= 0)
                      return 'Enter a valid quantity';
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Budget (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _deadlineController,
                  decoration: InputDecoration(
                    labelText: 'Deadline (optional)',
                    hintText: 'dd-MM-yyyy',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: _pickDeadlineDate,
                    ),
                  ),
                  readOnly: true,
                  onTap: _pickDeadlineDate,
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
