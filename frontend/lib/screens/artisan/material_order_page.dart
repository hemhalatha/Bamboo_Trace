import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class MaterialOrderPage extends StatefulWidget {
  const MaterialOrderPage({super.key, required this.batch});

  final Map<String, dynamic> batch;

  @override
  State<MaterialOrderPage> createState() => _MaterialOrderPageState();
}

class _MaterialOrderPageState extends State<MaterialOrderPage> {
  final _quantityController = TextEditingController(text: '1');
  String _fulfillmentType = 'delivery';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final quantity = int.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ApiService().placeMaterialOrder(
        batchId: widget.batch['id'] as String,
        quantity: quantity,
        quantityUnit: widget.batch['quantityUnit']?.toString() ?? 'kg',
        fulfillmentType: _fulfillmentType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Material order placed')),
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
    final farmerName = widget.batch['farmerName'] ?? 'Unknown farmer';
    final farmerLocation = widget.batch['farmerLocation'] ?? widget.batch['location'] ?? 'Not specified';
    final availableFrom = widget.batch['availableFromDate'];
    final harvestDate = widget.batch['expectedHarvestDate'];
    final quantity = widget.batch['quantityAvailable'] ?? widget.batch['quantity'] ?? 0;
    final unit = widget.batch['quantityUnit'] ?? 'kg';
    final isUpcoming = widget.batch['status'] == 'upcoming';

    return Scaffold(
      appBar: AppBar(title: Text(isUpcoming ? 'Pre-order Material' : 'Buy Material')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.inventory_2, color: Colors.green[700]),
                title: Text(widget.batch['type'] ?? 'Bamboo material'),
                subtitle: Text(
                  'Farmer: $farmerName\nLocation: $farmerLocation\nAvailable: $quantity $unit',
                ),
                isThreeLine: true,
              ),
            ),
            if (availableFrom != null) Text('Available from: $availableFrom'),
            if (harvestDate != null) Text('Expected harvest: $harvestDate'),
            SizedBox(height: 20),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity ($unit)',
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
                onPressed: _isSubmitting ? null : _placeOrder,
                child: _isSubmitting
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(isUpcoming ? 'Pre-order' : 'Buy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
