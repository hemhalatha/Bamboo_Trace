import 'package:flutter/material.dart';
import '../customer/contact_artisan_page.dart';
import '../customer/custom_request_page.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/remote_image.dart';
import '../../widgets/stat_card.dart';

class CustomerHomeTab extends StatefulWidget {
  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  final _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _productsFuture;
  late Future<Map<String, dynamic>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _apiService.getProjectCatalog();
    _statsFuture = _apiService.getDashboardStats();
  }

  int _count(Map<String, dynamic> stats, String key) {
    final value = stats[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _projectStatus(Map<String, dynamic> product) {
    final status = product['status']?.toString().trim().toLowerCase();
    if (status != null && status.isNotEmpty) return status;
    final hidden = product['isHidden'] == true;
    final quantity = int.tryParse(product['quantity']?.toString() ?? '') ?? 0;
    if (hidden) return 'draft';
    if (quantity <= 0) return 'sold';
    return 'available';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'ordered':
        return Colors.orange;
      case 'sold':
        return Colors.red;
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildStats() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(friendlyErrorMessage(snapshot.error)),
            ),
          );
        }
        final stats = snapshot.data ?? {};
        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth < 360
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 2;
            final cards = [
              StatCard(
                title: 'My Orders',
                value: _count(stats, 'totalOrders').toString(),
                icon: Icons.shopping_bag,
                color: Colors.blue,
              ),
              StatCard(
                title: 'Active Orders',
                value: _count(stats, 'activeOrders').toString(),
                icon: Icons.pending_actions,
                color: Colors.orange,
              ),
              StatCard(
                title: 'Custom Requests',
                value: _count(stats, 'customRequests').toString(),
                icon: Icons.assignment,
                color: Colors.purple,
              ),
              StatCard(
                title: 'Available Products',
                value: _count(stats, 'availableProducts').toString(),
                icon: Icons.storefront,
                color: Colors.green,
              ),
              StatCard(
                title: 'Unread Alerts',
                value: _count(stats, 'unreadNotifications').toString(),
                icon: Icons.notifications,
                color: Colors.red,
              ),
            ];
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: cards
                  .map((card) => SizedBox(width: cardWidth, child: card))
                  .toList(),
            );
          },
        );
      },
    );
  }

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
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.green[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Sustainable Bamboo Products',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Trace your product journey',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30),
          _buildStats(),
          SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Featured Products',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(onPressed: () {}, child: Text('View All')),
            ],
          ),
          SizedBox(height: 10),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(friendlyErrorMessage(snapshot.error));
              }
              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return Text('No products available yet');
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth < 360 ? 1 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 270,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final status = _projectStatus(product);
                      final quantity =
                          int.tryParse(product['quantity']?.toString() ?? '') ??
                              0;
                      final canOrder = status == 'available' && quantity > 0;
                      return Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: canOrder
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ContactArtisanPage(product: product),
                                    ),
                                  );
                                }
                              : null,
                          child: Opacity(
                            opacity: canOrder ? 1 : 0.72,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: RemoteImage(
                                      imageUrl:
                                          product['imageUrl']?.toString(),
                                      borderRadius: 12,
                                      icon: Icons.eco,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              product['productName'] ?? '',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusColor(status)
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: _statusColor(status),
                                              ),
                                            ),
                                            child: Text(
                                              status.replaceAll('_', ' '),
                                              style: TextStyle(
                                                color: _statusColor(status),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        product['productType'] ?? '',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'By ${product['artisanName'] ?? 'Artisan'}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        product['artisanLocation'] ??
                                            'Location not specified',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              canOrder
                                                  ? '$quantity available'
                                                  : 'Not available to order',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: canOrder
                                                    ? Colors.green[700]
                                                    : Colors.grey[700],
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(
                                            canOrder
                                                ? Icons.add_shopping_cart
                                                : Icons.block,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),

          SizedBox(height: 30),

          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.message, color: Colors.blue[700]),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width - 128,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Orders',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Select a product to buy from its artisan seller',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Select a product to place an order'),
                        ),
                      );
                    },
                    child: Text('Buy'),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.design_services, color: Colors.orange[700]),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width - 128,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custom Request',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Ask a specific artisan to make something not listed for sale',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CustomRequestPage()),
                      );
                    },
                    child: Text('Request'),
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

