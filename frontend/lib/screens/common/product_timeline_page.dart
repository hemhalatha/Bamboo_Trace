import 'package:flutter/material.dart';

class ProductTimelinePage extends StatelessWidget {
  final String orderId;

  ProductTimelinePage({required this.orderId});

  Widget _buildTimelineItem(String title, String description, String time, IconData icon, Color color, bool isCompleted) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted ? color : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              if (title != 'Ready for Delivery')
                Container(width: 2, height: 40, color: isCompleted ? color : Colors.grey[300]),
            ],
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isCompleted ? Colors.black : Colors.grey)),
                SizedBox(height: 4),
                Text(description, style: TextStyle(color: isCompleted ? Colors.grey[700] : Colors.grey[500])),
                SizedBox(height: 4),
                Text(time, style: TextStyle(fontSize: 12, color: isCompleted ? color : Colors.grey[500], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Example timeline steps; replace with dynamic data as needed
    final timelineSteps = [
      {"title": "Harvested", "description": "Bamboo harvested from Farm A, Assam", "time": "20/07/2025 - 09:00 AM", "icon": Icons.agriculture, "color":Colors.green, "isCompleted": true},
      {"title": "Quality Check", "description": "Quality verified and approved", "time": "20/07/2025 - 11:30 AM", "icon": Icons.verified, "color": Colors.blue, "isCompleted": true},
      {"title": "Crafting Started", "description": "Artisan Raj Kumar started crafting", "time": "22/07/2025 - 10:00 AM", "icon": Icons.handyman, "color": Colors.orange, "isCompleted": true},
      {"title": "In Progress", "description": "Chair 75% complete", "time": "28/07/2025 - 03:00 PM", "icon": Icons.pending, "color": Colors.orange, "isCompleted": true},
      {"title": "Final Touches", "description": "Adding finishing polish", "time": "Expected: 30/07/2025", "icon": Icons.brush, "color": Colors.grey, "isCompleted": false},
      {"title": "Ready for Delivery", "description": "Product ready for shipment", "time": "Expected: 01/08/2025", "icon": Icons.local_shipping, "color": Colors.grey, "isCompleted": false},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Product Timeline'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[700]),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Product ID: $orderId', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Bamboo Chair - Premium Quality'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
            Text('Journey Timeline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: timelineSteps.map((step) {
                  return _buildTimelineItem(
                    step['title'] as String,
                    step['description'] as String,
                    step['time'] as String,
                    step['icon'] as IconData,
                    step['color'] as Color,
                    step['isCompleted'] as bool,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
