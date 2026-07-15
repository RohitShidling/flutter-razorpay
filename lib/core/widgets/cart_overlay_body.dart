import 'package:flutter/material.dart';
import 'package:meal_app/core/widgets/cart_floating_button.dart';

/// Full-height body wrapper so the cart chip stays pinned bottom-right.
class CartOverlayBody extends StatelessWidget {
  final Widget child;

  const CartOverlayBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        const CartFloatingButton(),
      ],
    );
  }
}
