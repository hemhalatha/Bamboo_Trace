import 'package:flutter/material.dart';

import '../../config/bamboo_types.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/remote_image.dart';
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
          Text(
            'Material Market',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _batchesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(friendlyErrorMessage(snapshot.error)));
                }
                final batches = snapshot.data ?? [];
                if (batches.isEmpty) {
                  return Center(child: Text('No material listings'));
                }
                return ListView.builder(
                  itemCount: batches.length,
                  itemBuilder: (context, index) {
                    final batch = batches[index];
                    final quantity =
                        batch['quantityAvailable'] ?? batch['quantity'] ?? 0;
                    final unit = batch['quantityUnit'] ?? 'kg';
                    final harvestDate = batch['expectedHarvestDate'];
                    final availableFrom = batch['availableFromDate'];
                    final status = batch['status'] ?? 'available';
                    final isUpcoming = status == 'upcoming';
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RemoteImage(
                              imageUrl: batch['imageUrl']?.toString(),
                              height: 140,
                              width: double.infinity,
                              icon: Icons.grass,
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Icon(Icons.grass, color: Colors.green[700]),
                                Text(
                                  displayBambooType(batch['type']),
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Chip(
                                  label: Text(
                                    isUpcoming ? 'Upcoming' : 'Available Now',
                                  ),
                                  backgroundColor: isUpcoming
                                      ? Colors.orange[100]
                                      : Colors.green[100],
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text('Farmer: ${batch['farmerName'] ?? 'Unknown'}'),
                            Text(
                              'Location: ${batch['farmerLocation'] ?? batch['location'] ?? 'Not specified'}',
                            ),
                            Text(
                              isUpcoming
                                  ? 'Expected harvest: ${harvestDate ?? 'TBD'}'
                                  : 'Available: $quantity $unit',
                            ),
                            if (availableFrom != null)
                              Text('Available from: $availableFrom'),
                            SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                child: Text(isUpcoming ? 'Pre-order' : 'Buy'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MaterialOrderPage(batch: batch),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
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
