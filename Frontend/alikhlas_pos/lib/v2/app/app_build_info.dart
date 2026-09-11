const _appGitRevision = String.fromEnvironment('APP_GIT_SHA');

/// Adds the CI commit to diagnostics without hard-coding a stale release id.
/// Local developer builds intentionally keep the normal package version.
String withBuildRevision(String version) {
  final revision = _appGitRevision.trim();
  if (revision.isEmpty) return version;
  final shortRevision = revision.length > 12
      ? revision.substring(0, 12)
      : revision;
  return '$version · $shortRevision';
}
