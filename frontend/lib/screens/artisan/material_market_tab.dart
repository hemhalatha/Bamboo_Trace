import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'material_order_page.dart';

class MaterialMarketTab extends StatefulWidget {
  const MaterialMarketTab({super.key});

  @override
  State<MaterialMarketTab> createState() => _MaterialMarketTabState();
}

class _MaterialMarketTabState extends State<MaterialMarketTab> {
  final _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _batchesFuture;

  @override
  void initState() {
    super.initState();
    _batchesFuture = _apiService.getBatchCatalog();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Material Market', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _batchesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final batches = snapshot.data ?? [];
                if (batches.isEmpty) {
                  return Center(child: Text('No material listings'));
                }
                return ListView.builder(
                  itemCount: batches.length,
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    final quantity = batch['quantityAvailable'] ?? batch['quantity'] ?? 0;
                    final unit = batch['quantityUnit'] ?? 'kg';
                    final harvestDate = batch['expectedHarvestDate'];
                    final availableFrom = batch['availableFromDate'];
                    final status = batch['status'] ?? 'available';
                    final isUpcoming = status == 'upcoming';
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(Icons.grass, color: Colors.green[700]),
                        title: Row(
                          children: [
                            Expanded(child: Text(batch['type'] ?? 'Bamboo material')),
                            Chip(
                              label: Text(isUpcoming ? 'Upcoming' : 'Available Now'),
                              backgroundColor:
                                  isUpcoming ? Colors.orange[100] : Colors.green[100],
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Farmer: ${batch['farmerName'] ?? 'Unknown'}\n'
                          'Location: ${batch['farmerLocation'] ?? batch['location'] ?? 'Not specified'}\n'
                          '${isUpcoming ? 'Expected harvest: ${harvestDate ?? 'TBD'}' : 'Available: $quantity $unit'}'
                          '${availableFrom != null ? '\nAvailable from: $availableFrom' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: TextButton(
                          child: Text(isUpcoming ? 'Pre-order' : 'Buy'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MaterialOrderPage(batch: batch),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
