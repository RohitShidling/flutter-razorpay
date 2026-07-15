import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Full-screen image preview with pinch-to-zoom and close button.
/// Works identically on both Android and iOS.
class ImagePreviewDialog extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const ImagePreviewDialog({
    super.key,
    required this.imageUrl,
    this.title,
  });

  /// Opens the image preview as a full-screen overlay.
  static void show(BuildContext context, String imageUrl, {String? title}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ImagePreviewDialog(imageUrl: imageUrl, title: title);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Solid dark scrim background — no blur
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 250),
              builder: (context, value, child) {
                return Container(
                  color: Colors.black.withValues(alpha: 0.85 * value),
                );
              },
            ),
          ),
          
          // Image with pinch-to-zoom
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: GestureDetector(
              // Tapping anywhere in the transparent area dismisses the dialog
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.transparent,
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: GestureDetector(
                    // Absorb taps on the actual image so it doesn't dismiss when tapping the image
                    onTap: () {},
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      progressIndicatorBuilder: (context, _, progress) {
                        return SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            value: progress.progress,
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        );
                      },
                      errorWidget: (_, __, ___) => const Icon(
                        CupertinoIcons.photo, 
                        color: Colors.white54, 
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // SafeArea for UI controls (Close button & Title)
          SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Close button
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(CupertinoIcons.xmark, color: Colors.white, size: 22),
                    ),
                  ),
                ),
                // Title at bottom
                if (title != null && title!.trim().isNotEmpty)
                  Positioned(
                    bottom: 30,
                    left: 24,
                    right: 24,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Text(
                          // .trim() removes any \r\n from the API which causes vertical off-centering
                          title!.trim(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            height: 1.2, // Ensures proper vertical alignment
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
