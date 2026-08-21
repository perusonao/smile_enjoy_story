import 'package:flutter/material.dart';

class PublicDemoSalesProgress extends StatelessWidget {
  const PublicDemoSalesProgress({
    super.key,
    required this.currentStep,
    this.preEntry = false,
  });

  final int currentStep;
  final bool preEntry;

  @override
  Widget build(BuildContext context) {
    final labels = preEntry
        ? const ['準備', '営業', '紹介', '上位面談', '客先面談', '受注']
        : const ['SkillSheet', '営業', '紹介', '上位面談', '客先面談', '受注'];
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('営業進捗', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          // Wrap (not a horizontally-scrolling Row) so all six steps stay
          // visible without side-scrolling on a ~390px iPhone viewport: six
          // chips plus separators don't fit on one line at a readable font
          // size, so this lets the steps flow onto a second line instead of
          // being clipped off-screen or hidden behind a scroll affordance
          // the user has no visual cue to find. Each step keeps its own
          // trailing chevron bundled into a single Wrap child (chip+chevron
          // as one Row) so a chevron never gets orphaned alone at the start
          // of a wrapped line.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < labels.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: i <= currentStep ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Step markers were previously the literal characters
                          // '✓ ' / '● ' inlined into the Text string below. Both
                          // codepoints (U+2713, U+25CF) are missing from the
                          // bundled NotoSansJP subset font, which made CanvasKit
                          // fall back to an on-demand Google Fonts fetch for
                          // just those glyphs — visible as a momentary tofu box
                          // (see investigation report). Icon glyphs come from
                          // the tree-shaken MaterialIcons font instead, so they
                          // don't depend on NotoSansJP glyph coverage at all.
                          if (i < currentStep) ...[
                            const Icon(Icons.check, size: 12),
                            const SizedBox(width: 2),
                          ] else if (i == currentStep) ...[
                            const Icon(Icons.circle, size: 8),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == currentStep ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i != labels.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(Icons.chevron_right, size: 14),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
