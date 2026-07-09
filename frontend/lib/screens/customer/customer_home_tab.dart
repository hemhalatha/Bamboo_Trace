import 'package:flutter/material.dart';

import '../customer/contact_artisan_page.dart';
import '../customer/custom_request_page.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/remote_image.dart';

class CustomerHomeTab extends StatefulWidget {
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenRequests;

  const CustomerHomeTab({super.key, this.onOpenOrders, this.onOpenRequests});

  @override
  State<CustomerHomeTab> createState() => _CustomerHomeTabState();
}

class _CustomerHomeTabState extends State<CustomerHomeTab> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late Future<List<Map<String, dynamic>>> _productsFuture;
  late Future<Map<String, dynamic>> _statsFuture;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _productsFuture = _apiService.getProjectCatalog();
    _statsFuture = _apiService.getDashboardStats();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshHome() {
    setState(() {
      _productsFuture = _apiService.getProjectCatalog();
      _statsFuture = _apiService.getDashboardStats();
    });
  }

  void _scrollToProducts() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      260,
      duration: Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  int _count(Map<String, dynamic> stats, String key) {
    final value = stats[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _textValue(Map<String, dynamic> product, String key, String fallback) {
    final value = product[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
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

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _formatPrice(dynamic value) {
    final price = double.tryParse(value?.toString() ?? '');
    if (price == null || price <= 0) return 'Price on request';
    final amount = price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(2);
    return 'INR $amount';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Color(0xFF246B45);
      case 'ordered':
        return Color(0xFFB26A00);
      case 'sold':
        return Color(0xFFB3261E);
      case 'archived':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  List<String> _categories(List<Map<String, dynamic>> products) {
    final values = <String>{};
    for (final product in products) {
      final bambooType = product['bambooType']?.toString().trim();
      final productType = product['productType']?.toString().trim();
      if (bambooType != null && bambooType.isNotEmpty) values.add(bambooType);
      if (values.length < 5 && productType != null && productType.isNotEmpty) {
        values.add(productType);
      }
      if (values.length >= 6) break;
    }
    return ['All', ...values.take(6)];
  }

  bool _matchesFilters(Map<String, dynamic> product) {
    final query = _searchController.text.trim().toLowerCase();
    final category = _selectedCategory.toLowerCase();
    final haystack = [
      product['productName'],
      product['productType'],
      product['bambooType'],
      product['artisanName'],
      product['artisanLocation'],
      product['description'],
    ].whereType<Object>().map((value) => value.toString().toLowerCase()).join(' ');
    final matchesQuery = query.isEmpty || haystack.contains(query);
    final matchesCategory = _selectedCategory == 'All' || haystack.contains(category);
    return matchesQuery && matchesCategory;
  }

  Widget _sectionHeader(String title, String subtitle, {Widget? action}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
              ),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildHero() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFEAF4EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(0xFFD5E8D9)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'BambooTrace marketplace',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Color(0xFF246B45),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 14),
              Text(
                'Shop traceable bamboo products made by local artisans.',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF123D2A),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Browse products, request custom work, and track every order from one place.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Color(0xFF4C6254)),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _scrollToProducts,
                icon: Icon(Icons.search),
                label: Text('Browse products'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenRequests ??
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CustomRequestPage()),
                      );
                    },
                icon: Icon(Icons.design_services),
                label: Text('Custom request'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, SizedBox(height: 18), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: intro),
              SizedBox(width: 28),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 230),
                child: actions,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveOrderBanner() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        final activeOrders = _count(snapshot.data ?? {}, 'activeOrders');
        if (activeOrders <= 0) return SizedBox.shrink();
        return Container(
          margin: EdgeInsets.only(top: 16),
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color(0xFFFFF6E0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFFFFD98A)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFFFE4A8),
                child: Icon(Icons.local_shipping, color: Color(0xFF8A5A00)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$activeOrders active order${activeOrders == 1 ? '' : 's'} need your attention.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: widget.onOpenOrders,
                child: Text('View'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndCategories(List<Map<String, dynamic>> products) {
    final categories = _categories(products);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search products, bamboo type, artisan, or location',
            prefixIcon: Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(Icons.close),
                    onPressed: () {
                      setState(() => _searchController.clear());
                    },
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((category) {
              final selected = category == _selectedCategory;
              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = category),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final status = _projectStatus(product);
    final quantity = int.tryParse(product['quantity']?.toString() ?? '') ?? 0;
    final canOrder = status == 'available' && quantity > 0;
    final statusColor = _statusColor(status);
    final name = _textValue(product, 'productName', 'Bamboo product');
    final bambooType = _textValue(product, 'bambooType', 'Bamboo type not specified');
    final artisan = _textValue(product, 'artisanName', 'Artisan');
    final location = _textValue(product, 'artisanLocation', 'Location not specified');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canOrder
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactArtisanPage(product: product),
                  ),
                );
              }
            : null,
        child: Opacity(
          opacity: canOrder ? 1 : 0.68,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RemoteImage(
                      imageUrl: product['imageUrl']?.toString(),
                      borderRadius: 0,
                      icon: Icons.eco,
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.94),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _formatStatus(status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      _formatPrice(product['price']),
                      style: TextStyle(
                        color: Color(0xFF246B45),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      bambooType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'By $artisan • $location',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            canOrder ? '$quantity available' : 'Not available',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: canOrder ? Color(0xFF246B45) : Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Icon(
                          canOrder ? Icons.arrow_forward : Icons.block,
                          size: 18,
                          color: canOrder ? Color(0xFF246B45) : Colors.grey,
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
  }

  Widget _buildProducts() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _messageCard(
            icon: Icons.wifi_off,
            title: 'Products could not load',
            message: friendlyErrorMessage(snapshot.error),
            action: OutlinedButton.icon(
              onPressed: _refreshHome,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
          );
        }
        final products = snapshot.data ?? [];
        final filtered = products.where(_matchesFilters).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchAndCategories(products),
            SizedBox(height: 18),
            _sectionHeader(
              'Shop bamboo products',
              '${filtered.length} product${filtered.length == 1 ? '' : 's'} available from artisans',
            ),
            SizedBox(height: 12),
            if (products.isEmpty)
              _messageCard(
                icon: Icons.storefront,
                title: 'No products listed yet',
                message: 'Artisan products will appear here after they are published.',
              )
            else if (filtered.isEmpty)
              _messageCard(
                icon: Icons.search_off,
                title: 'No matching products',
                message: 'Try a different search term or category.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width < 520 ? 1 : width < 900 ? 2 : 3;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 330,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _buildProductCard(filtered[index]),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildAccountSnapshot() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LinearProgressIndicator(minHeight: 2);
        }
        if (snapshot.hasError) {
          return _messageCard(
            icon: Icons.error_outline,
            title: 'Account snapshot unavailable',
            message: friendlyErrorMessage(snapshot.error),
            action: TextButton(onPressed: _refreshHome, child: Text('Retry')),
          );
        }
        final stats = snapshot.data ?? {};
        final metrics = [
          _MetricData('Orders', _count(stats, 'totalOrders').toString(), Icons.shopping_bag),
          _MetricData('Active', _count(stats, 'activeOrders').toString(), Icons.pending_actions),
          _MetricData('Requests', _count(stats, 'customRequests').toString(), Icons.assignment),
          _MetricData('Alerts', _count(stats, 'unreadNotifications').toString(), Icons.notifications),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 460 ? 2 : 4;
            final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: metrics.map((metric) {
                return SizedBox(
                  width: width,
                  child: Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Color(0xFFE0E6DF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(metric.icon, color: Color(0xFF246B45), size: 20),
                        SizedBox(height: 10),
                        Text(
                          metric.value,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          metric.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomRequestStrip() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF6F1E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE9DEC8)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFE7D7B9),
            child: Icon(Icons.design_services, color: Color(0xFF6D4B16)),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need something made to order?',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3),
                Text(
                  'Send a custom request to artisans for products that are not listed yet.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: widget.onOpenRequests ??
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CustomRequestPage()),
                  );
                },
            icon: Icon(Icons.add),
            label: Text('Request'),
          ),
        ],
      ),
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFEAF4EC),
              child: Icon(icon, color: Color(0xFF246B45)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text(message, style: TextStyle(color: Colors.grey[700])),
                  if (action != null) ...[
                    SizedBox(height: 10),
                    action,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refreshHome(),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(),
                _buildActiveOrderBanner(),
                SizedBox(height: 24),
                _buildProducts(),
                SizedBox(height: 28),
                _buildCustomRequestStrip(),
                SizedBox(height: 28),
                _sectionHeader(
                  'Account snapshot',
                  'Quick numbers are still here, just lower than the shop floor.',
                ),
                SizedBox(height: 12),
                _buildAccountSnapshot(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;

  const _MetricData(this.label, this.value, this.icon);
}
