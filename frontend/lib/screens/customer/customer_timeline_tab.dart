import 'package:flutter/material.dart';
import '../common/product_timeline_page.dart';

class CustomerTimelineTab extends StatelessWidget {
  final TextEditingController _productIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Product Timeline', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text('Enter Product ID to track its journey', style: TextStyle(color: Colors.grey[600])),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _productIdController,
                  decoration: InputDecoration(hintText: 'Enter Product ID (e.g., BT001)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.search)),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  final productId = _productIdController.text.trim();
                  if (productId.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProductTimelinePage(orderId: productId)));
                  }
                },
                child: Text('Track'),
              ),
            ],
          ),
          SizedBox(height: 30),
          Text('Recent Searches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: Icon(Icons.history),
              title: Text('Product BT001'),
              subtitle: Text('Bamboo Chair - Delivered'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProductTimelinePage(orderId: 'BT001')));
              },
            ),
          ),
        ],
      ),
    );
  }
}
