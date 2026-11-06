import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.large = false});
  final bool large;

  @override
  Widget build(BuildContext context) {
    final badgeSize = large ? 48.0 : 34.0;
    final badgeRadius = large ? 15.0 : 11.0;

    return Semantics(
      label: 'Moodify',
      image: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: badgeSize,
              height: badgeSize,
              padding: EdgeInsets.all(large ? 8 : 5.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(badgeRadius),
                color: const Color(0xFF14161D),
                border: Border.all(color: const Color(0x26FFFFFF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: large ? 14 : 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/brand/moodify-mark.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            SizedBox(width: large ? 12 : 9),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  large ? 'moodify' : 'Moodify',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: large ? 32 : 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: large ? -1.1 : -0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
