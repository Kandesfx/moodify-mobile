import 'package:flutter/material.dart';

class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({super.key, required this.message, this.isError = true});
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.error : scheme.onSurfaceVariant;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: color, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}
