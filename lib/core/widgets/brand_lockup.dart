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
            width: large ? 58 : 28,
            height: large ? 38 : 28,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
          SizedBox(width: large ? 12 : 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                large ? 'moodify' : 'Moodify',
                style: TextStyle(
                  fontSize: large ? 32 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: large ? -1.3 : .3,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
