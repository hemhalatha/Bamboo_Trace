import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/custom_order_request.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/profile_completion_guard.dart';
import '../../widgets/remote_image.dart';
import '../customer/custom_request_page.dart';

class CustomRequestsTab extends StatefulWidget {
  const CustomRequestsTab({super.key, required this.title});

  final String title;

  @override
  State<CustomRequestsTab> createState() => _CustomRequestsTabState();
}

class _CustomRequestsTabState extends State<CustomRequestsTab>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabController;
  late Future<List<CustomOrderRequest>> _activeFuture;
  late Future<List<CustomOrderRequest>> _historyFuture;

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
    _activeFuture = _apiService.getActiveCustomOrderRequests();
    _historyFuture = _apiService.getCustomOrderRequestHistory();
  }

  Future<void> _openCreateRequest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustomRequestPage()),
    );
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _respond(CustomOrderRequest request, bool accept) async {
    if (accept) {
      final profileComplete = await ensureProfileComplete(
          context,
          message: 'Please complete your profile before accepting requests.',
        );
      if (!profileComplete) return;
    }
    try {
      if (accept) {
        await _apiService.acceptCustomOrderRequest(request.id);
      } else {
        await _apiService.rejectCustomOrderRequest(request.id);
      }
    } catch (e) {
      if (!mounted) return;
      if (await handleProfileRequired(context, e)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
      return;
    }
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = context.read<AuthService>().currentUser?.role;
    final canCreate = currentRole == 'customer';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 4),
                  Text(
                    canCreate
                        ? 'Create and track made-to-order bamboo requests.'
                        : 'Review customer requests and manage responses.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              );
              final addButton = FilledButton.icon(
                onPressed: _openCreateRequest,
                icon: Icon(Icons.add),
                label: Text('New Request'),
              );
              if (!canCreate) return titleBlock;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: addButton),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  SizedBox(width: 12),
                  addButton,
                ],
              );
            },
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
              _CustomRequestList(
                future: _activeFuture,
                active: true,
                onRespond: _respond,
              ),
              _CustomRequestList(
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

class _CustomRequestList extends StatelessWidget {
  const _CustomRequestList({
    required this.future,
    required this.active,
    required this.onRespond,
  });

  final Future<List<CustomOrderRequest>> future;
  final bool active;
  final Future<void> Function(CustomOrderRequest request, bool accept)
  onRespond;

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthService>().currentUser;
    return FutureBuilder<List<CustomOrderRequest>>(
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
            child: Text(
              active
                  ? 'No active custom requests'
                  : 'No custom request history',
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final customerName = request.customer?['name'] ?? 'Customer';
            final artisanName = request.targetType == 'broadcast'
                ? 'Broadcast to all artisans'
                : request.targetArtisan?['name'] ?? 'Artisan';
            final acceptedByName =
                request.acceptedByArtisan?['name'] ?? 'Accepted artisan';
            final partyLine = currentUser?.role == 'artisan'
                ? 'Customer: $customerName'
                : request.acceptedByArtisanId != null
                    ? 'Artisan: $acceptedByName'
                    : 'Artisan: $artisanName';
            final canRespond =
                active &&
                currentUser?.role == 'artisan' &&
                request.status == 'open' &&
                !request.rejectedByCurrentUser &&
                (request.targetType == 'broadcast' ||
                    request.targetArtisanId == currentUser?.id);
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
                          request.title,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Chip(label: Text(request.status)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(partyLine),
                    Text('Quantity: ${request.quantity}'),
                    if (request.budget != null)
                      Text('Budget: ${request.budget}'),
                    if (request.deadline != null)
                      Text('Deadline: ${request.deadline}'),
                    if (request.rejectedByCurrentUser)
                      Text('You rejected this request'),
                    SizedBox(height: 8),
                    Text(request.description),
                    if (request.imageUrl != null &&
                        request.imageUrl!.isNotEmpty) ...[
                      SizedBox(height: 12),
                      RemoteImage(
                        imageUrl: request.imageUrl,
                        height: 160,
                        width: double.infinity,
                        icon: Icons.design_services,
                      ),
                    ],
                    if (canRespond) ...[
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
