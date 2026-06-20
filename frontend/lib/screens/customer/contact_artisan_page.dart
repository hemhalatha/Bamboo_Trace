import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/profile_completion_guard.dart';
import '../../widgets/remote_image.dart';

class ContactArtisanPage extends StatefulWidget {
  const ContactArtisanPage({super.key, required this.product});

  final Map<String, dynamic> product;

  @override
  State<ContactArtisanPage> createState() => _ContactArtisanPageState();
}

class _ContactArtisanPageState extends State<ContactArtisanPage> {
  final _quantityController = TextEditingController(text: '1');
  String _fulfillmentType = 'delivery';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  String _projectStatus() {
    final status = widget.product['status']?.toString().trim().toLowerCase();
    if (status != null && status.isNotEmpty) return status;
    final hidden = widget.product['isHidden'] == true;
    final quantity =
        int.tryParse(widget.product['quantity']?.toString() ?? '') ?? 0;
    if (hidden) return 'draft';
    if (quantity <= 0) return 'sold';
    return 'available';
  }

  Future<void> _submitRequest() async {
    final profileComplete = await ensureProfileComplete(
      context,
      message: 'Please complete your profile before placing an order.',
    );
    if (!profileComplete) return;
    final status = _projectStatus();
    final availableQuantity =
        int.tryParse(widget.product['quantity']?.toString() ?? '') ?? 0;
    if (status != 'available' || availableQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This product is not available to order.')),
      );
      return;
    }
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Enter a valid quantity')));
      return;
    }
    if (quantity > availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Requested quantity exceeds available stock.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ApiService().placeProductOrder(
        productId: widget.product['id'] as String,
        quantity: quantity,
        quantityUnit: 'item',
        fulfillmentType: _fulfillmentType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order placed')));
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
    final productName = widget.product['productName'] ?? 'Selected product';
    final productType = widget.product['productType'] ?? '';
    final artisanName = widget.product['artisanName'] ?? 'Unknown artisan';
    final artisanLocation =
        widget.product['artisanLocation'] ?? 'Not specified';
    final status = _projectStatus();
    final availableQuantity =
        int.tryParse(widget.product['quantity']?.toString() ?? '') ?? 0;
    final canOrder = status == 'available' && availableQuantity > 0;
    return Scaffold(
      appBar: AppBar(
        title: Text('Buy Product'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RemoteImage(
                    imageUrl: widget.product['imageUrl']?.toString(),
                    height: 84,
                    width: 84,
                    icon: Icons.eco,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(productType),
                        Text('Seller: $artisanName'),
                        Text('Location: $artisanLocation'),
                        Text(
                          canOrder
                              ? '$availableQuantity available'
                              : 'Status: ${status.replaceAll('_', ' ')}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _fulfillmentType,
            decoration: InputDecoration(
              labelText: 'Fulfillment',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
              DropdownMenuItem(value: 'pickup', child: Text('Pickup')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _fulfillmentType = value);
            },
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubmitting || !canOrder ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
              ),
              child: _isSubmitting
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Place Order', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
