class PoseLandmark {
  const PoseLandmark({
    required this.name,
    required this.x,
    required this.y,
    this.z = 0,
    this.visibility,
  });

  // TODO: Represent a single normalized body keypoint that can be shared by ML, domain, and UI layers.
  final String name;
  final double x;
  final double y;
  final double z;
  final double? visibility;
}
