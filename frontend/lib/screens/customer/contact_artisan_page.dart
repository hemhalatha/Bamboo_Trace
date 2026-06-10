import 'package:flutter/material.dart';

import '../../services/api_service.dart';

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

  Future<void> _submitRequest() async {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a valid quantity')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order placed')),
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
    final productName = widget.product['productName'] ?? 'Selected product';
    final productType = widget.product['productType'] ?? '';
    final artisanName = widget.product['artisanName'] ?? 'Unknown artisan';
    final artisanLocation = widget.product['artisanLocation'] ?? 'Not specified';
    return Scaffold(
      appBar: AppBar(
        title: Text('Buy Product'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.eco, color: Colors.green[700]),
                title: Text(productName),
                subtitle: Text('$productType\nSeller: $artisanName\nLocation: $artisanLocation'),
                isThreeLine: true,
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
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                child: _isSubmitting
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Place Order', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
