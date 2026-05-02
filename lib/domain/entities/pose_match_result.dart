class PoseMatchResult {
  const PoseMatchResult({
    required this.isMatched,
    required this.score,
    required this.feedbackMessage,
  });

  // TODO: Describe the scoring outcome that drives ghost-layer feedback and acceptance rules.
  final bool isMatched;
  final double score;
  final String feedbackMessage;
}
