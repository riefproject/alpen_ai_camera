import 'package:alpen_ai_camera/data/models/pose_template_model.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

abstract class PoseTemplateLocalDataSource {
  Future<List<PoseTemplateModel>> getAvailableTemplates();
  Future<PoseTemplateModel?> getTemplateById(String templateId);
  Future<void> saveTemplate(PoseTemplateModel template);
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
}
