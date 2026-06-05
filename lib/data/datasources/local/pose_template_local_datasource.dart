import 'package:alpen_ai_camera/data/models/pose_template_model.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

abstract class PoseTemplateLocalDataSource {
  Future<List<PoseTemplateModel>> getAvailableTemplates();
  Future<PoseTemplateModel?> getTemplateById(String templateId);
  Future<void> saveTemplate(PoseTemplateModel template);
  Future<void> updateTemplate(PoseTemplateModel template);
  Future<void> deleteTemplate(String templateId);
  Future<void> toggleFavorite(String templateId);
  Future<bool> exists(String templateId);
}

class HivePoseTemplateLocalDataSource implements PoseTemplateLocalDataSource {
  HivePoseTemplateLocalDataSource({Box<Map>? box}) : _box = box;

  static const String boxName = 'pose_templates';
  Box<Map>? _box;

  Future<Box<Map>> get _openBox async {
    final existing = _box;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    _box = await Hive.openBox<Map>(boxName);
    return _box!;
  }

  @override
  Future<List<PoseTemplateModel>> getAvailableTemplates() async {
    final box = await _openBox;
    return box.values
        .map((value) => PoseTemplateModel.fromJson(Map<String, dynamic>.from(value)))
        .toList();
  }

  @override
  Future<PoseTemplateModel?> getTemplateById(String templateId) async {
    final box = await _openBox;
    final raw = box.get(templateId);
    if (raw == null) {
      return null;
    }

    return PoseTemplateModel.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<void> saveTemplate(PoseTemplateModel template) async {
    final box = await _openBox;
    await box.put(template.id, template.toJson());
  }

  @override
  Future<void> updateTemplate(PoseTemplateModel template) async {
    final box = await _openBox;
    await box.put(template.id, template.toJson());
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    final box = await _openBox;
    await box.delete(templateId);
  }

  @override
  Future<void> toggleFavorite(String templateId) async {
    final box = await _openBox;
    final raw = box.get(templateId);
    if (raw == null) {
      return;
    }
    final template = PoseTemplateModel.fromJson(Map<String, dynamic>.from(raw));
    await box.put(
      templateId,
      template.toJson()..['isFavorite'] = !template.isFavorite,
    );
  }

  @override
  Future<bool> exists(String templateId) async {
    final box = await _openBox;
    return box.containsKey(templateId);
  }
}
