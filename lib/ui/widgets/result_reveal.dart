import 'package:flutter/material.dart';

/// A short "judging…" beat before a Selection/interview result reveals
/// (Playable 0.4C.3 §7): the outcome is already decided the instant this
/// widget builds — this only delays *displaying* it, so the player feels a
/// beat of tension instead of an instant flash-cut to 合格/不合格.
///
/// Driven by a bounded [Future.delayed], not a real animation, so E2E tests
/// never need a fixed sleep: `result-pending` is present until the delay
/// fires, then swaps for `result-revealed` — a locator waiting on either key
/// settles naturally.
class ResultReveal extends StatefulWidget {
  const ResultReveal({super.key, required this.builder, this.duration = defaultDuration, this.pendingLabel = '判定しています…'});

  /// Exposed so callers that must sequence something *after* the reveal
  /// (e.g. a one-time tutorial dialog that shouldn't cover up the "判定して
  /// います…" beat and race ahead of it) can reference the same duration
  /// instead of duplicating the magic number (Codex review, PR #9).
  static const Duration defaultDuration = Duration(milliseconds: 650);

  final WidgetBuilder builder;
  final Duration duration;
  final String pendingLabel;

  @override
  State<ResultReveal> createState() => _ResultRevealState();
}

class _ResultRevealState extends State<ResultReveal> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_revealed) {
      return Center(
        key: const ValueKey('result-pending'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(widget.pendingLabel, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }
    return KeyedSubtree(key: const ValueKey('result-revealed'), child: widget.builder(context));
  }
}
