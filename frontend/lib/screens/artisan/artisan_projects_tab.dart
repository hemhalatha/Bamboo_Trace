import 'package:flutter/material.dart';

import '../../services/api_service.dart';

class ArtisanProjectsTab extends StatelessWidget {
  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _apiService.getProjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load projects.'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No projects found.'));
        }

        final projects = snapshot.data!;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final data = projects[index];
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('${data['productName']}'),
                subtitle: Text(
                  'Type: ${data['productType']}\nQuantity: ${data['quantity']}\nProgress: ${data['progress']}%',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
