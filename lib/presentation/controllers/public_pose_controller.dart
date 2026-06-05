import 'package:alpen_ai_camera/domain/entities/public_pose.dart';
import 'package:alpen_ai_camera/domain/repositories/public_pose_repository.dart';
import 'package:flutter/foundation.dart';

class PublicPoseController extends ChangeNotifier {
  PublicPoseController({required PublicPoseRepository repository})
      : _repository = repository;

  final PublicPoseRepository _repository;
  List<PublicPose> _poses = const <PublicPose>[];
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasMore = true;

  List<PublicPose> get poses => _poses;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  Future<void> fetchPoses({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _poses = const <PublicPose>[];
      _hasMore = true;
    }

    if (!_hasMore) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.getPoses(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        offset: _poses.length,
      );
      _poses = [..._poses, ...result];
      _hasMore = result.length >= 20;
    } catch (e) {
      _errorMessage = 'Gagal memuat pose: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    fetchPoses(refresh: true);
  }

  Future<void> downloadPose(PublicPose pose) async {
    try {
      await _repository.incrementDownload(pose.id);
    } catch (e) {
      _errorMessage = 'Gagal mendownload: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<PublicPose> uploadPose({
    required String title,
    required String description,
    required Map<String, dynamic> templateData,
    required String? sourceImagePath,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final pose = await _repository.uploadPose(
        title: title,
        description: description,
        templateData: templateData,
        sourceImagePath: sourceImagePath,
      );
      return pose;
    } catch (e) {
      _errorMessage = 'Gagal mengunggah pose: $e';
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
