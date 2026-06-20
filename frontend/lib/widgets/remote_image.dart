import 'package:flutter/material.dart';

import '../config/app_config.dart';

class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.imageUrl,
    this.height,
    this.width,
    this.borderRadius = 8,
    this.icon = Icons.image_outlined,
  });

  final String? imageUrl;
  final double? height;
  final double? width;
  final double borderRadius;
  final IconData icon;

  String? get _resolvedUrl {
    if (imageUrl == null || imageUrl!.isEmpty) return null;
    if (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://')) {
      return imageUrl;
    }
    final path = imageUrl!.startsWith('/') ? imageUrl! : '/$imageUrl';
    return '${AppConfig.apiBaseUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = _resolvedUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        height: height,
        width: width,
        color: Colors.grey[200],
        child: resolvedUrl == null
            ? Center(child: Icon(icon, color: Colors.grey[600]))
            : Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Center(child: Icon(icon, color: Colors.grey[600])),
              ),
      ),
    );
  }
}
