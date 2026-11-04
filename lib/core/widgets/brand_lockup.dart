import 'package:flutter/material.dart';

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Moodify',
    image: true,
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/brand/moodify-mark.png',
            width: large ? 58 : 40,
            height: large ? 38 : 28,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'moodify',
                style: TextStyle(
                  fontSize: large ? 32 : 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
