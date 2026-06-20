import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order_request.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/error_messages.dart';

class OrderRequestsTab extends StatefulWidget {
  const OrderRequestsTab({super.key, required this.title});

  final String title;

  @override
  State<OrderRequestsTab> createState() => _OrderRequestsTabState();
}

class _OrderRequestsTabState extends State<OrderRequestsTab>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  late Future<List<OrderRequest>> _activeFuture;
  late Future<List<OrderRequest>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload() {
    _activeFuture = _apiService.getActiveRequests();
    _historyFuture = _apiService.getRequestHistory();
  }

  Future<void> _respond(OrderRequest request, bool accepted) async {
    if (accepted) {
      await _apiService.acceptOrderRequest(request.id);
    } else {
      await _apiService.rejectOrderRequest(request.id);
    }
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            widget.title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _RequestList(
                future: _activeFuture,
                active: true,
                onRespond: _respond,
              ),
              _RequestList(
                future: _historyFuture,
                active: false,
                onRespond: _respond,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.future,
    required this.active,
    required this.onRespond,
  });

  final Future<List<OrderRequest>> future;
  final bool active;
  final Future<void> Function(OrderRequest request, bool accepted) onRespond;

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser?.id;
    return FutureBuilder<List<OrderRequest>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(friendlyErrorMessage(snapshot.error)));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Text(active ? 'No active requests' : 'No request history'),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final productName = request.product?['productName'];
            final batchName = request.batch?['batchId'];
            final senderName = request.sender?['name'] ?? 'Sender';
            final receiverName = request.receiver?['name'] ?? 'Receiver';
            final isReceiver = request.receiverId == currentUserId;
            final partyLabel = isReceiver
                ? 'From: $senderName'
                : 'To: $receiverName';
            return Card(
              margin: EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          productName ?? batchName ?? 'Material request',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        _StatusChip(status: request.status),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(partyLabel),
                    SizedBox(height: 4),
                    Text(
                      'Quantity: ${request.quantity} ${request.quantityUnit}',
                    ),
                    if (request.notes != null && request.notes!.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(request.notes!),
                    ],
                    if (active && isReceiver) ...[
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => onRespond(request, false),
                            child: Text('Reject'),
                          ),
                          ElevatedButton(
                            onPressed: () => onRespond(request, true),
                            child: Text('Accept'),
                          ),
                        ],
                      ),
                    ],
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'accepted' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.orange,
    };
    return Chip(
      label: Text(status.replaceAll('_', ' ')),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color.shade700),
    );
  }
}
