// import 'package:flutter/material.dart';
// import 'package:perpus_app/models/book.dart';

// class BookImageWidget extends StatefulWidget {
//   final Book book;
//   final double? width;
//   final double? height;
//   final BorderRadius? borderRadius;
//   final BoxFit fit;
//   final Widget? placeholder;
//   final Widget? errorWidget;

//   const BookImageWidget({
//     super.key,
//     required this.book,
//     this.width,
//     this.height,
//     this.borderRadius,
//     this.fit = BoxFit.cover,
//     this.placeholder,
//     this.errorWidget,
//   });

//   @override
//   State<BookImageWidget> createState() => _BookImageWidgetState();
// }

// class _BookImageWidgetState extends State<BookImageWidget> {
//   int retryCount = 0;
//   final int maxRetries = 3;

//   @override
//   Widget build(BuildContext context) {
//     // Default placeholder
//     Widget defaultPlaceholder = Container(
//       width: widget.width,
//       height: widget.height,
//       decoration: BoxDecoration(
//         borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
//         gradient: LinearGradient(
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//           colors: [
//             Colors.indigo.shade400,
//             Colors.purple.shade400,
//           ],
//         ),
//       ),
//       child: Icon(
//         Icons.menu_book_rounded,
//         color: Colors.white70,
//         size: (widget.width != null && widget.height != null) 
//             ? (widget.width! + widget.height!) / 6 
//             : 40,
//       ),
//     );

//     // Default error widget with retry
//     Widget defaultErrorWidget = Container(
//       width: widget.width,
//       height: widget.height,
//       decoration: BoxDecoration(
//         borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
//         color: Colors.red.shade50,
//         border: Border.all(color: Colors.red.shade200),
//       ),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.broken_image_outlined,
//             color: Colors.red.shade400,
//             size: (widget.width != null && widget.height != null) 
//                 ? (widget.width! + widget.height!) / 8 
//                 : 32,
//           ),
//           const SizedBox(height: 4),
//           Text(
//             'Image Error',
//             style: TextStyle(
//               color: Colors.red.shade600,
//               fontSize: 10,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           if (retryCount < maxRetries) ...[
//             const SizedBox(height: 4),
//             GestureDetector(
//               onTap: () {
//                 setState(() {
//                   retryCount++;
//                 });
//               },
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: Colors.red.shade100,
//                   borderRadius: BorderRadius.circular(4),
//                   border: Border.all(color: Colors.red.shade300),
//                 ),
//                 child: Text(
//                   'Retry',
//                   style: TextStyle(
//                     fontSize: 8,
//                     color: Colors.red.shade700,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );

//     // If no cover URL, show placeholder
//     if (widget.book.coverUrl == null || widget.book.coverUrl!.isEmpty) {
//       return widget.placeholder ?? defaultPlaceholder;
//     }

//     // Show image with loading and error handling
//     Widget imageWidget = Image.network(
//       widget.book.coverUrl!,
//       width: widget.width,
//       height: widget.height,
//       fit: widget.fit,
//       key: ValueKey('${widget.book.coverUrl}_$retryCount'), // Force rebuild on retry
//       loadingBuilder: (context, child, loadingProgress) {
//         if (loadingProgress == null) return child;
        
//         return Container(
//           width: widget.width,
//           height: widget.height,
//           decoration: BoxDecoration(
//             borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
//             color: Colors.blue.shade50,
//             border: Border.all(color: Colors.blue.shade200),
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               CircularProgressIndicator(
//                 value: loadingProgress.expectedTotalBytes != null
//                     ? loadingProgress.cumulativeBytesLoaded /
//                         loadingProgress.expectedTotalBytes!
//                     : null,
//                 strokeWidth: 2,
//                 valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 'Loading...',
//                 style: TextStyle(
//                   color: Colors.blue.shade600,
//                   fontSize: 10,
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//       errorBuilder: (context, error, stackTrace) {
//         print('❌ Image load error for "${widget.book.judul}": $error');
//         print('🔗 Image URL: ${widget.book.coverUrl}');
//         return widget.errorWidget ?? defaultErrorWidget;
//       },
//     );

//     // Apply border radius if specified
//     if (widget.borderRadius != null) {
//       return ClipRRect(
//         borderRadius: widget.borderRadius!,
//         child: imageWidget,
//       );
//     }

//     return imageWidget;
//   }
// }
