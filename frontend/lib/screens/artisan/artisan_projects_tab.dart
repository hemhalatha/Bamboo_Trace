import 'package:flutter/material.dart';

import '../../config/bamboo_types.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import '../../widgets/remote_image.dart';
import 'add_project_page.dart';

class ArtisanProjectsTab extends StatefulWidget {
  const ArtisanProjectsTab({super.key});

  @override
  State<ArtisanProjectsTab> createState() => _ArtisanProjectsTabState();
}

class _ArtisanProjectsTabState extends State<ArtisanProjectsTab> {
  final ApiService _apiService = ApiService();
  late Future<List<Map<String, dynamic>>> _productsFuture;
  String _selectedFilter = 'all';

  static const _filters = <String>[
    'all',
    'draft',
    'available',
    'ordered',
    'sold',
    'archived',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _productsFuture = _apiService.getMyArtisanProducts();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _productsFuture;
  }

  Future<void> _addProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddProjectPage()),
    );
    if (created == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddProjectPage(project: product)),
    );
    if (updated == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _updateStatus(
    Map<String, dynamic> product,
    String status,
  ) async {
    final id = product['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await _apiService.updateArtisanProductStatus(id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product marked ${artisanProductStatusLabel(status)}'),
        ),
      );
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
    }
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
      case 'draft':
      default:
        return Colors.blueGrey;
    }
  }

  String _productName(Map<String, dynamic> product) {
    final value = product['productName'] ?? product['title'];
    final name = value?.toString().trim() ?? '';
    return name.isEmpty ? 'Untitled product' : name;
  }

  String _priceLabel(Map<String, dynamic> product) {
    final value = product['price'];
    final price = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (price == null) return 'Price not set';
    final hasDecimals = price % 1 != 0;
    return 'Rs. ${price.toStringAsFixed(hasDecimals ? 2 : 0)}';
  }

  List<Map<String, dynamic>> _filteredProducts(
    List<Map<String, dynamic>> products,
  ) {
    if (_selectedFilter == 'all') return products;
    return products
        .where(
          (product) =>
              normalizeArtisanProductStatus(product['status']) ==
              _selectedFilter,
        )
        .toList();
  }

  Map<String, int> _statusCounts(List<Map<String, dynamic>> products) {
    final counts = {for (final status in artisanProductStatuses) status: 0};
    for (final product in products) {
      final status = normalizeArtisanProductStatus(product['status']);
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Bamboo Products',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 6),
              Text(
                'Create, publish, and manage your bamboo products.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _addProduct,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            foregroundColor: Colors.white,
          ),
          icon: Icon(Icons.add),
          label: Text('Add Product'),
        ),
      ],
    );
  }

  Widget _buildCounts(List<Map<String, dynamic>> products) {
    final counts = _statusCounts(products);
    final cards = artisanProductStatuses.map((status) {
      final color = _statusColor(status);
      return _StatusCountCard(
        label: artisanProductStatusLabel(status),
        value: counts[status] ?? 0,
        color: color,
      );
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 560
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 48) / 5;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width.clamp(140, 220).toDouble(),
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filters.map((filter) {
          final selected = _selectedFilter == filter;
          final label = filter == 'all'
              ? 'All'
              : artisanProductStatusLabel(filter);
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) => setState(() => _selectedFilter = filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProducts(List<Map<String, dynamic>> products) {
    final filtered = _filteredProducts(products);
    if (filtered.isEmpty) {
      return _EmptyProductsState(
        filterLabel: _selectedFilter == 'all'
            ? null
            : artisanProductStatusLabel(_selectedFilter),
        onAddProduct: _addProduct,
      );
    }

    return Column(
      children: filtered
          .map(
            (product) => Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _ProductCard(
                product: product,
                name: _productName(product),
                price: _priceLabel(product),
                status: normalizeArtisanProductStatus(product['status']),
                bambooType: displayBambooType(product['bambooType']),
                materialSource: displayMaterialSource(product['materialSource']),
                statusColor: _statusColor(
                  normalizeArtisanProductStatus(product['status']),
                ),
                onEdit: () => _editProduct(product),
                onPublish: () => _updateStatus(product, 'available'),
                onArchive: () => _updateStatus(product, 'archived'),
                onMarkSold: () => _updateStatus(product, 'sold'),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorState(
            message: friendlyErrorMessage(snapshot.error),
            onRetry: () => setState(_reload),
          );
        }

        final products = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              _buildHeader(),
              SizedBox(height: 20),
              _buildCounts(products),
              SizedBox(height: 20),
              _buildFilters(),
              SizedBox(height: 16),
              _buildProducts(products),
            ],
          ),
        );
      },
    );
  }
}

class _StatusCountCard extends StatelessWidget {
  const _StatusCountCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withOpacity(0.14),
              child: Text(
                value.toString(),
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.name,
    required this.price,
    required this.status,
    required this.bambooType,
    required this.materialSource,
    required this.statusColor,
    required this.onEdit,
    required this.onPublish,
    required this.onArchive,
    required this.onMarkSold,
  });

  final Map<String, dynamic> product;
  final String name;
  final String price;
  final String status;
  final String bambooType;
  final String materialSource;
  final Color statusColor;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onArchive;
  final VoidCallback onMarkSold;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final image = RemoteImage(
              imageUrl: product['imageUrl']?.toString(),
              height: compact ? 160 : 96,
              width: compact ? double.infinity : 96,
              icon: Icons.eco,
            );
            final details = _ProductDetails(
              name: name,
              price: price,
              status: status,
              bambooType: bambooType,
              materialSource: materialSource,
              statusColor: statusColor,
              actions: _actions(),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [image, SizedBox(height: 12), details],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                image,
                SizedBox(width: 12),
                Expanded(child: details),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _actions() {
    switch (status) {
      case 'draft':
        return [
          _ActionButton(label: 'Edit', icon: Icons.edit, onPressed: onEdit),
          _ActionButton(
            label: 'Publish',
            icon: Icons.publish,
            onPressed: onPublish,
          ),
          _ActionButton(
            label: 'Archive',
            icon: Icons.archive,
            onPressed: onArchive,
          ),
        ];
      case 'available':
        return [
          _ActionButton(label: 'Edit', icon: Icons.edit, onPressed: onEdit),
          _ActionButton(
            label: 'Archive',
            icon: Icons.archive,
            onPressed: onArchive,
          ),
        ];
      case 'ordered':
        return [
          _ActionButton(
            label: 'Mark as Sold',
            icon: Icons.check_circle,
            onPressed: onMarkSold,
          ),
        ];
      case 'sold':
        return [
          _ActionButton(
            label: 'Archive',
            icon: Icons.archive,
            onPressed: onArchive,
          ),
        ];
      case 'archived':
      default:
        return [
          Chip(
            avatar: Icon(Icons.visibility, size: 16),
            label: Text('View only'),
          ),
        ];
    }
  }
}

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({
    required this.name,
    required this.price,
    required this.status,
    required this.bambooType,
    required this.materialSource,
    required this.statusColor,
    required this.actions,
  });

  final String name;
  final String price;
  final String status;
  final String bambooType;
  final String materialSource;
  final Color statusColor;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 8),
            _StatusBadge(status: status, color: statusColor),
          ],
        ),
        SizedBox(height: 6),
        Text(
          price,
          style: TextStyle(
            color: Colors.green[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _MetaText(label: 'Bamboo', value: bambooType),
            _MetaText(label: 'Source', value: materialSource),
          ],
        ),
        SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        artisanProductStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: TextStyle(color: Colors.grey[700]),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState({
    required this.filterLabel,
    required this.onAddProduct,
  });

  final String? filterLabel;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    final title = filterLabel == null
        ? 'No products yet'
        : 'No $filterLabel products';
    return Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 44, color: Colors.grey[600]),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Add a bamboo product when you are ready to list it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAddProduct,
              icon: Icon(Icons.add),
              label: Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 44, color: Colors.red[700]),
            SizedBox(height: 12),
            Text(
              'Unable to load products',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
