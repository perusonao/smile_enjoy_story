import 'package:flutter/material.dart';

class PublicDemoEventDialog extends StatelessWidget {
  const PublicDemoEventDialog({
    super.key,
    required this.title,
    required this.imageAsset,
    required this.message,
    required this.nextAction,
    this.imageKey,
  });

  final String title;
  final String imageAsset;
  final String message;
  final String nextAction;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  imageAsset,
                  key: imageKey,
                  fit: BoxFit.cover,
                  // No cacheWidth/filterQuality/gaplessPlayback here (PR #36
                  // re-evaluated per the iOS rendering investigation):
                  // - cacheWidth: the bundled event images are ~160-220px
                  //   wide natively, well under any on-screen target size on
                  //   a high-DPR phone, so a computed cacheWidth can only
                  //   ask for an *upscale* — Flutter/Skia don't upsample
                  //   during decode, so it had no measurable effect and just
                  //   added MediaQuery-dependent complexity.
                  // - filterQuality.low: dropped the paint-time filter below
                  //   Image.asset's medium default, making the (already
                  //   small, already-upscaled) images look softer for no
                  //   offsetting benefit.
                  // - gaplessPlayback: only suppresses a flicker when an
                  //   *existing* Image element's provider is swapped; this
                  //   dialog is rebuilt fresh via showDialog's builder every
                  //   time, so there's no persisting element for it to help.
                  // The actual pop-in/layout-shift this trio was reaching
                  // for is now addressed by precaching the image before the
                  // dialog opens (see _precacheEventImage in
                  // public_demo_01_placeholder_screen.dart).
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.notifications_active_outlined, size: 48),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('次の行動', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(nextAction),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('確認'),
        ),
      ],
    );
  }
}
