class CameraSession {
  const CameraSession({
    required this.sessionId,
    required this.isActive,
    required this.createdAt,
  });

  // TODO: Represent the active camera session state used across layers.
  final String sessionId;
  final bool isActive;
  final DateTime createdAt;
}
