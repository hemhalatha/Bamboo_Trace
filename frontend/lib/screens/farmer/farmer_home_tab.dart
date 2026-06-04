import 'package:flutter/material.dart';
import '../../widgets/stat_card.dart';

class FarmerHomeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // For demonstration, these stats can be replaced with real data from Firestore
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),

          Row(
            children: const [
              Expanded(
                child: StatCard(
                  title: 'Batches in Stock',
                  value: '12',
                  icon: Icons.inventory,
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'Total Harvested',
                  value: '150kg',
                  icon: Icons.agriculture_rounded,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          SizedBox(height: 30),
          Text('Latest Transactions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[100],
                child: Icon(Icons.trending_up, color: Colors.green),
              ),
              title: Text('Batch #BT001 Sold'),
              subtitle: Text('To Artisan Raj Kumar - 25kg'),
              trailing: Text('₹2,500'),
            ),
          ),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Icon(Icons.inventory_2, color: Colors.blue),
              ),
              title: Text('New Harvest Added'),
              subtitle: Text('Batch #BT012 - 30kg'),
              trailing: Text('Today'),
            ),
          ),
        ],
      ),
    );
  }
}
