import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/api_service.dart';
import '../common/product_timeline_page.dart';

class CustomerTimelineTab extends StatefulWidget {
  const CustomerTimelineTab({super.key});

  @override
  State<CustomerTimelineTab> createState() => _CustomerTimelineTabState();
}

class _CustomerTimelineTabState extends State<CustomerTimelineTab> {
  final _orderIdController = TextEditingController();
  final _apiService = ApiService();
  late Future<List<Order>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _apiService.getOrderModels();
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    super.dispose();
  }

  void _openTimeline(String orderId) {
    final value = orderId.trim();
    if (value.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductTimelinePage(orderId: value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Timeline',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Enter an order ID, product ID, batch ID, or product name',
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 32,
                ),
                child: TextField(
                  controller: _orderIdController,
                  decoration: InputDecoration(
                    hintText: 'Enter order ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => _openTimeline(_orderIdController.text),
                child: Text('Track'),
              ),
            ],
          ),
          SizedBox(height: 30),
          Text(
            'Recent Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          FutureBuilder<List<Order>>(
            future: _ordersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Unable to load recent orders.'),
                  ),
                );
              }
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No orders available for timeline tracking.'),
                  ),
                );
              }
              return Column(
                children: orders.take(5).map((order) {
                  final id = order.id ?? order.productId ?? order.productName;
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.timeline),
                      title: Text(order.productName),
                      subtitle: Text(
                        '${order.orderType.replaceAll('_', ' ')} - ${order.status.replaceAll('_', ' ')}',
                      ),
                      trailing: Icon(Icons.arrow_forward_ios),
                      onTap: () => _openTimeline(id),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
