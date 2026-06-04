import 'package:flutter/material.dart';
import '../customer/contact_artisan_page.dart';

class CustomerHomeTab extends StatelessWidget {
  final products = [
    {'name': 'Bamboo Chair', 'price': '₹2,500', 'artisan': 'Raj Kumar'},
    {'name': 'Bamboo Lamp', 'price': '₹800', 'artisan': 'Priya Singh'},
    {'name': 'Bamboo Table', 'price': '₹4,200', 'artisan': 'Kumar Das'},
    {'name': 'Bamboo Basket', 'price': '₹350', 'artisan': 'Maya Devi'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.green[400]!, Colors.green[600]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Sustainable Bamboo Products', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Trace your product journey', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),
          SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Featured Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(onPressed: () {}, child: Text('View All')),
            ],
          ),
          SizedBox(height: 10),

          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Container(decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.vertical(top: Radius.circular(12))), child: Center(child: Icon(Icons.eco, size: 50, color: Colors.green[600])))),
                    Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product['name']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 4),
                          Text('By ${product['artisan']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(product['price']!, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                            Icon(Icons.add_shopping_cart, size: 20),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: 30),

          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.message, color: Colors.blue[700]),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Custom Orders', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Contact artisans for personalized products', style: TextStyle(color: Colors.grey[600])),
                    ]),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ContactArtisanPage()));
                    },
                    child: Text('Contact'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
