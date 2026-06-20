import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImagePickerField extends StatelessWidget {
  const ImagePickerField({
    super.key,
    required this.label,
    required this.imageBytes,
    required this.onPick,
    required this.onClear,
    this.isBusy = false,
  });

  final String label;
  final Uint8List? imageBytes;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: Colors.grey[200],
                child: hasImage
                    ? Image.memory(imageBytes!, fit: BoxFit.cover)
                    : Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 44,
                          color: Colors.grey[600],
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: isBusy ? null : onPick,
                icon: Icon(Icons.photo_library),
                label: Text(hasImage ? 'Change image' : 'Select image'),
              ),
              if (hasImage)
                TextButton.icon(
                  onPressed: isBusy ? null : onClear,
                  icon: Icon(Icons.close),
                  label: Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
