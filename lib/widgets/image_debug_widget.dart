import 'package:flutter/material.dart';

class ImageDebugWidget extends StatelessWidget {
  final String? imagePath;
  final String? fullUrl;
  final String bookTitle;

  const ImageDebugWidget({
    Key? key,
    this.imagePath,
    this.fullUrl,
    required this.bookTitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.yellow[50],
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEBUG: $bookTitle',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Path: ${imagePath ?? "null"}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Full URL: ${fullUrl ?? "null"}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 4),
          if (fullUrl != null)
            Image.network(
              fullUrl!,
              height: 80,
              width: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 80,
                  width: 60,
                  color: Colors.red[100],
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 16),
                      Text('Error', style: TextStyle(fontSize: 10, color: Colors.red)),
                    ],
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 80,
                  width: 60,
                  color: Colors.blue[100],
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
