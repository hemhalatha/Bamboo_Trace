import 'package:flutter/material.dart';
import '../common/product_timeline_page.dart';

class CustomerOrdersTab extends StatelessWidget {
  final orders = [
    {'id': 'ORD001', 'product': 'Bamboo Chair Set', 'status': 'In Progress', 'date': '25/07/2025', 'price': '₹2,500'},
    {'id': 'ORD002', 'product': 'Bamboo Lamp', 'status': 'Delivered', 'date': '20/07/2025', 'price': '₹800'},
    {'id': 'ORD003', 'product': 'Custom Bamboo Table', 'status': 'Pending', 'date': '28/07/2025', 'price': '₹4,200'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Orders', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                Color bgColor;
                Color textColor;

                switch (order['status']) {
                  case 'Delivered':
                    bgColor = Colors.green[100]!;
                    textColor = Colors.green[700]!;
                    break;
                  case 'In Progress':
                    bgColor = Colors.orange[100]!;
                    textColor = Colors.orange[700]!;
                    break;
                  default:
                    bgColor = Colors.grey[100]!;
                    textColor = Colors.grey[700]!;
                }

                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Order ${order['id']}', style: TextStyle(fontWeight: FontWeight.bold)),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
                            child: Text(order['status']!, style: TextStyle(fontSize: 12, color: textColor)),
                          ),
                        ]),
                        SizedBox(height: 8),
                        Text(order['product']!),
                        SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('Ordered on ${order['date']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(order['price']!, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                        ]),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ProductTimelinePage(orderId: order['id']!)),
                            );
                          },
                          child: Text('Track Order'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
