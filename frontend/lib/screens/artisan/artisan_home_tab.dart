import 'package:flutter/material.dart';
import '../../widgets/stat_card.dart';

class ArtisanHomeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Replace these mock values with Firestore data streams if desired
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workshop Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),

          Row(
            children: const [
              Expanded(
                child: StatCard(
                  title: 'In Progress',
                  value: '5',
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: 'Completed',
                  value: '23',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          StatCard(
            title: 'Current Orders',
            value: '8',
            icon: Icons.shopping_cart,
            color: Colors.blue,
          ),

          SizedBox(height: 30),
          Text('Recent Projects',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange[100],
                child: Icon(Icons.handyman, color: Colors.orange),
              ),
              title: Text('Bamboo Chair Set'),
              subtitle: Text('Progress: 75% • Due: 2 days'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
          ),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green[100],
                child: Icon(Icons.check, color: Colors.green),
              ),
              title: Text('Bamboo Lamp'),
              subtitle: Text('Completed • Delivered'),
              trailing: Icon(Icons.arrow_forward_ios),
            ),
          ),
        ],
      ),
    );
  }
}
