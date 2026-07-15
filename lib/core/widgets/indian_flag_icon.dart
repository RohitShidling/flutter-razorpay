import 'package:flutter/material.dart';

/// Compact Indian flag for +91 phone prefix (no external flag package).
class IndianFlagIcon extends StatelessWidget {
  const IndianFlagIcon({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final width = size * 1.5;
    return Container(
      width: width,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(child: ColoredBox(color: const Color(0xFFFF9933))),
          Expanded(
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF000080), width: 1),
                  ),
                  child: Center(
                    child: Container(
                      width: size * 0.12,
                      height: size * 0.12,
                      decoration: const BoxDecoration(
                        color: Color(0xFF000080),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: ColoredBox(color: const Color(0xFF138808))),
        ],
      ),
    );
  }
}
