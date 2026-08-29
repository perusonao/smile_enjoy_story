import 'package:flutter/material.dart';

/// Presentation-only shell for game event dialogs.
///
/// Gameplay callbacks, result types, and state mutations stay owned by the
/// event-specific dialog. This widget only standardizes visual structure.
class GameEventModal extends StatelessWidget {
  const GameEventModal({
    super.key,
    this.imageAsset,
    this.imageKey,
    this.category,
    required this.title,
    this.description,
    this.infoSection,
    required this.actions,
    this.barrierDismissible = true,
  });

  final String? imageAsset;
  final Key? imageKey;
  final String? category;
  final String title;
  final String? description;
  final Widget? infoSection;
  final List<Widget> actions;

  /// Mirrors the existing showDialog contract. The helper below reads this
  /// value; the shell itself never changes dismissal policy.
  final bool barrierDismissible;

  static const double imageHeight = 180;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasImage = imageAsset != null;

    return AlertDialog(
      semanticLabel: category == null ? title : '$category: $title',
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 40),
      contentPadding: EdgeInsets.zero,
      actionsPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasImage) _EventImage(asset: imageAsset!, imageKey: imageKey),
            Padding(
              padding: EdgeInsets.fromLTRB(20, hasImage ? 16 : 20, 20, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      description!,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                  if (infoSection != null) ...[
                    const SizedBox(height: 14),
                    infoSection!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  actions[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.asset, this.imageKey});

  final String asset;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: GameEventModal.imageHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: Image.asset(
              asset,
              key: imageKey,
              fit: BoxFit.cover,
              // PR #36's iOS rendering investigation evaluated and rejected
              // cacheWidth, filterQuality.low, and gaplessPlayback here:
              // these small bundled images would only be requested at an
              // upscale decode size, low filtering made that upscale softer,
              // and each showDialog call creates a fresh Image element so
              // gapless provider swaps cannot help. Event callers instead use
              // _precacheEventImage in public_demo_01_placeholder_screen.dart,
              // which is the established fix for first-frame image pop-in.
              errorBuilder: (context, error, stackTrace) => Container(
                color: scheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.notifications_active_outlined,
                  size: 48,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 40,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x4D000000)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<T?> showGameEventModal<T>(
  BuildContext context, {
  required GameEventModal dialog,
  bool? barrierDismissible,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible ?? dialog.barrierDismissible,
    builder: (_) => dialog,
  );
}
