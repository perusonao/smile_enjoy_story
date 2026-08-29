import 'package:flutter/material.dart';

/// Immutable, presentation-only identity of the artifact currently running.
///
/// Values are supplied by the build command. This class never queries GitHub
/// at runtime and is deliberately independent of gameplay state.
@immutable
class BuildInfo {
  const BuildInfo._({required this.commitSha, this.pullRequestNumber});

  factory BuildInfo.fromValues({String commitSha = '', String prNumber = ''}) {
    final normalizedSha = commitSha.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{7,64}$').hasMatch(normalizedSha)) {
      return const BuildInfo._(commitSha: '');
    }

    final normalizedPr = prNumber.trim();
    final parsedPr = RegExp(r'^[1-9][0-9]*$').hasMatch(normalizedPr)
        ? int.tryParse(normalizedPr)
        : null;
    return BuildInfo._(commitSha: normalizedSha, pullRequestNumber: parsedPr);
  }

  factory BuildInfo.fromEnvironment() => BuildInfo.fromValues(
    commitSha: const String.fromEnvironment('BUILD_COMMIT_SHA'),
    prNumber: const String.fromEnvironment('BUILD_PR_NUMBER'),
  );

  final String commitSha;
  final int? pullRequestNumber;

  bool get isAvailable => commitSha.isNotEmpty;

  String get shortSha => isAvailable ? commitSha.substring(0, 7) : '';

  String get displayLabel {
    if (!isAvailable) return '';
    final pr = pullRequestNumber;
    return pr == null ? 'Deploy: $shortSha' : 'Deploy: PR #$pr · $shortSha';
  }
}

/// Compact header label for developer/tester deployment diagnostics.
class BuildInfoLabel extends StatelessWidget {
  const BuildInfoLabel({super.key, required this.buildInfo});

  final BuildInfo buildInfo;

  @override
  Widget build(BuildContext context) {
    if (!buildInfo.isAvailable) return const SizedBox.shrink();
    return Text(
      buildInfo.displayLabel,
      key: const Key('build-info-label'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 10,
      ),
    );
  }
}
