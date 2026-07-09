import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/bamboo_types.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/profile_completion_guard.dart';
import '../../widgets/image_picker_field.dart';
import '../../widgets/remote_image.dart';

const artisanProductStatuses = <String>[
  'draft',
  'available',
  'ordered',
  'sold',
  'archived',
];

const artisanProductFormStatuses = <String>['draft', 'available'];

const materialSourceOptions = <String>[
  'BambooTrace Batch',
  'External Purchase',
  'Own Stock',
  'Unknown / Not Specified',
];

String artisanProductStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'available':
      return 'Available';
    case 'ordered':
      return 'Ordered';
    case 'sold':
      return 'Sold';
    case 'archived':
      return 'Archived';
    case 'draft':
    default:
      return 'Draft';
  }
}

String normalizeArtisanProductStatus(Object? value) {
  final status = value?.toString().trim().toLowerCase() ?? '';
  return artisanProductStatuses.contains(status) ? status : 'draft';
}

String displayMaterialSource(Object? value) {
  final source = value?.toString().trim() ?? '';
  return materialSourceOptions.contains(source)
      ? source
      : 'Unknown / Not Specified';
}

class AddProjectPage extends StatefulWidget {
  const AddProjectPage({super.key, this.project});

  final Map<String, dynamic>? project;

  @override
  State<AddProjectPage> createState() => _AddProjectPageState();
}

class _AddProjectPageState extends State<AddProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _sourceDetailsController = TextEditingController();
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;
  String _selectedBambooType = 'Other / Unknown';
  String _selectedMaterialSource = 'Unknown / Not Specified';
  String _selectedStatus = 'draft';
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  bool get _isEditing => widget.project?['id'] != null;
  bool get _canEditStatus =>
      !_isEditing || artisanProductFormStatuses.contains(_selectedStatus);

  @override
  void initState() {
    super.initState();
    final product = widget.project;
    if (product == null) return;

    _productNameController.text =
        (product['productName'] ?? product['title'] ?? '').toString();
    _descriptionController.text = product['description']?.toString() ?? '';
    final price = product['price'];
    _priceController.text = price == null ? '' : price.toString();
    _selectedBambooType = displayBambooType(product['bambooType']);
    _selectedMaterialSource = displayMaterialSource(product['materialSource']);
    _selectedStatus = normalizeArtisanProductStatus(product['status']);
    _sourceDetailsController.text =
        product['sourceDetails']?.toString() ??
        product['sourceBatchId']?.toString() ??
        '';
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _sourceDetailsController.dispose();
    super.dispose();
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

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    final profileComplete = await ensureProfileComplete(
      context,
      message: 'Please complete your profile before listing products.',
    );
    if (!profileComplete) return;

    setState(() => _isSaving = true);
    try {
      String? imageUrl;
      if (_selectedImage != null) {
        try {
          imageUrl = await _apiService.uploadImage(_selectedImage!);
        } catch (error) {
          if (!mounted) return;
          final saveWithoutImage = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Image upload failed'),
              content: Text(
                '${friendlyErrorMessage(error)}\n\n'
                'You can save the product without the new image and add it later.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Retry later'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Save without image'),
                ),
              ],
            ),
          );
          if (saveWithoutImage != true) return;
        }
      }
      final sourceDetails = _sourceDetailsController.text.trim();
      final payload = <String, dynamic>{
        'productName': _productNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'bambooType': _selectedBambooType,
        'materialSource': _selectedMaterialSource,
        if (_canEditStatus) 'status': _selectedStatus,
        'productType': 'Product',
        'quantity': 1,
        'estimatedDays': 1,
        'progress': 0.0,
        if (sourceDetails.isNotEmpty) 'sourceDetails': sourceDetails,
        if (_selectedMaterialSource == 'BambooTrace Batch' &&
            sourceDetails.isNotEmpty)
          'sourceBatchId': sourceDetails,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      };

      if (_isEditing) {
        await _apiService.updateArtisanProduct(
          widget.project!['id'].toString(),
          payload,
        );
      } else {
        await _apiService.createArtisanProduct(payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Product updated' : 'Product added'),
        ),
      );
      Navigator.pop(context, true);
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

  Widget _sectionHeading(String title, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          SizedBox(height: 3),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingImageUrl = widget.project?['imageUrl']?.toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth < 600 ? 16 : 24,
                    vertical: 24,
                  ),
                  children: [
                    _sectionHeading(
                      'Product details',
                      'Use a clear title and price customers can understand.',
                    ),
                    TextFormField(
                      controller: _productNameController,
                      decoration: InputDecoration(
                        labelText: 'Product name/title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Product name is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 3,
                      maxLines: 5,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        final price = double.tryParse(value?.trim() ?? '');
                        if (price == null) return 'Enter a valid price';
                        if (price < 0) return 'Price cannot be negative';
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _sectionHeading(
                      'Product image',
                      'Use a well-lit image that clearly shows the product.',
                    ),
                    if (existingImageUrl != null &&
                        existingImageUrl.isNotEmpty &&
                        _selectedImageBytes == null) ...[
                      Text('Current image', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      RemoteImage(
                        imageUrl: existingImageUrl,
                        height: 160,
                        width: double.infinity,
                        icon: Icons.eco,
                      ),
                      SizedBox(height: 16),
                    ],
                    ImagePickerField(
                      label: 'Product image',
                      imageBytes: _selectedImageBytes,
                      isBusy: _isSaving,
                      onPick: _pickImage,
                      onClear: () => setState(() {
                        _selectedImage = null;
                        _selectedImageBytes = null;
                      }),
                    ),
                    SizedBox(height: 16),
                    _sectionHeading(
                      'Bamboo source',
                      'Batch linking is optional. Select the source that best matches your material.',
                    ),
                    DropdownButtonFormField<String>(
                      value: _selectedBambooType,
                      decoration: InputDecoration(
                        labelText: 'Bamboo type',
                        border: OutlineInputBorder(),
                      ),
                      items: bambooTypeOptions
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedBambooType = value);
                      },
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedMaterialSource,
                      decoration: InputDecoration(
                        labelText: 'Material source',
                        border: OutlineInputBorder(),
                      ),
                      items: materialSourceOptions
                          .map(
                            (source) =>
                                DropdownMenuItem(value: source, child: Text(source)),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedMaterialSource = value);
                        }
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _sourceDetailsController,
                      decoration: InputDecoration(
                        labelText: _selectedMaterialSource == 'BambooTrace Batch'
                            ? 'Batch ID or source details (optional)'
                            : 'Source details (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    _sectionHeading(
                      'Listing status',
                      'Save as draft or publish the product as available.',
                    ),
                    if (_canEditStatus)
                      DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: artisanProductFormStatuses
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(artisanProductStatusLabel(status)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _selectedStatus = value);
                        },
                      )
                    else
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          '${artisanProductStatusLabel(_selectedStatus)} '
                          '(managed by the order workflow)',
                        ),
                      ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProduct,
                        icon: _isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.save),
                        label: Text(
                          _isSaving
                              ? 'Saving...'
                              : (_isEditing ? 'Save Product' : 'Add Product'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
