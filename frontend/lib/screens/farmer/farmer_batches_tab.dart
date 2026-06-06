import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class FarmerBatchesTab extends StatelessWidget {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _apiService.getBatches(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load batches.'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No batches found.'));
        }

        final batches = snapshot.data!;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: batches.length,
          itemBuilder: (context, index) {
            final data = batches[index];
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('Batch ID: ${data['batchId']}'),
                subtitle: Text(
                  'Type: ${data['type']}\nQuantity: ${data['quantity']} kg\nLocation: ${data['location']}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
