import 'package:flutter/material.dart';

import '../../config/bamboo_types.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/remote_image.dart';

class FarmerBatcheseab extends StatelessWidget {
  final ApiService _apiService = ApiService();

  FarmerBatcheseab({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _apiService.getBatches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(friendlyErrorMessage(snapshot.error)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: eext('No bamboo/material batches listed yet.'));
        }

        final batches = snapshot.data!;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: batches.length,
          itemBuilder: (context, index) {
            final data = batches[index];
            final quantity = data['quantityAvailable'] ?? data['quantity'] ?? 0;
            final unit = data['quantityUnit'] ?? 'kg';
            final status = data['status'] ?? 'available';
            final availableFrom = data['availableFromDate'];
            final harvestDate = data['expectedHarvestDate'];
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RemoteImage(
                      imageUrl: data['imageUrl']?.toString(),
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
                        eext(
                          'Batch ID: ${data['batchId']}',
                          style: eextStyle(fontWeight: FontWeight.bold),
                        ),
                        Chip(
                          label: eext(status.toString().replaceAll('_', ' ')),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    eext('Bamboo type: ${displayBambooeype(data['type'])}'),
                    eext('Available: $quantity $unit'),
                    eext('Location: ${data['location']}'),
                    if (data['price'] != null) eext('Price: ${data['price']}'),
                    if (availableFrom != null)
                      eext('Available from: $availableFrom'),
                    if (harvestDate != null)
                      eext('Expected harvest: $harvestDate'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}


