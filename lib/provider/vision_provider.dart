import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter_agentic_app/provider/base_provider.dart';
import 'package:flutter_agentic_app/services/gemini_service.dart';
import 'package:flutter_agentic_app/services/image_compression_service.dart';
import 'package:flutter_agentic_app/services/media_permission_service.dart';
import 'package:image_picker/image_picker.dart';

class VisionProvider extends BaseProvider {
  VisionProvider({
    MediaPermissionService? permissionService,
    ImageCompressionService? compressionService,
    ImagePicker? imagePicker,
    GeminiService? geminiService,
  }) : _permissionService = permissionService ?? MediaPermissionService(),
       _compressionService = compressionService ?? ImageCompressionService(),
       _imagePicker = imagePicker ?? ImagePicker(),
       _geminiService = geminiService ?? GeminiService.instance;

  final MediaPermissionService _permissionService;
  final ImageCompressionService _compressionService;
  final ImagePicker _imagePicker;
  final GeminiService _geminiService;

  Uint8List? _imageBytes;
  String? _imagePath;
  String? _explanation;
  String _prompt = '';
  int? _originalBytes;
  int? _compressedBytes;
  bool _isCompressing = false;
  bool _needsSettings = false;

  Uint8List? get imageBytes => _imageBytes;
  String? get imagePath => _imagePath;
  String? get explanation => _explanation;
  String get prompt => _prompt;
  int? get originalBytes => _originalBytes;
  int? get compressedBytes => _compressedBytes;
  bool get isCompressing => _isCompressing;
  bool get needsSettings => _needsSettings;
  bool get hasImage => _imageBytes != null;

  void updatePrompt(String value) {
    _prompt = value;
    notifyListeners();
  }

  Future<void> captureFromCamera() => _pickAndExplain(MediaSource.camera);

  Future<void> pickFromGallery() => _pickAndExplain(MediaSource.gallery);

  Future<void> analyzeCurrentImage() async {
    if (_imageBytes == null) {
      setError('Please capture or select an image first.');
      return;
    }
    await _explain(_imageBytes!, mimeType: 'image/jpeg');
  }

  void clearImage() {
    _imageBytes = null;
    _imagePath = null;
    _explanation = null;
    _originalBytes = null;
    _compressedBytes = null;
    _needsSettings = false;
    clearError();
    notifyListeners();
  }

  Future<void> _pickAndExplain(MediaSource source) async {
    clearError();
    _needsSettings = false;
    _explanation = null;

    final allowed = await _permissionService.ensurePermission(source);
    if (!allowed) {
      final opened = await _permissionService.openSettingsIfPermanentlyDenied(
        source,
      );
      _needsSettings = true;
      setError(
        opened
            ? 'Permission is required. Enable it in Settings and try again.'
            : source == MediaSource.camera
            ? 'Camera permission is required to take a photo.'
            : 'Photo library permission is required to select an image.',
      );
      return;
    }

    try {
      final picked = await _imagePicker.pickImage(
        source: source == MediaSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 95,
      );

      if (picked == null) {
        return;
      }

      _isCompressing = true;
      notifyListeners();

      final compressed = await _compressionService.compressForUpload(
        picked.path,
      );

      _imageBytes = compressed.bytes;
      _imagePath = compressed.path;
      _originalBytes = compressed.originalBytes;
      _compressedBytes = compressed.compressedBytes;
      _isCompressing = false;
      notifyListeners();

      await _explain(compressed.bytes, mimeType: compressed.mimeType);
    } catch (e, stackTrace) {
      _isCompressing = false;
      log('Vision pick/compress failed: $e', stackTrace: stackTrace);
      setError('Could not process the image. Please try again.');
    }
  }

  Future<void> _explain(Uint8List bytes, {required String mimeType}) async {
    setLoading(true);
    clearError();

    try {
      final result = await _geminiService.explainImage(
        imageBytes: bytes,
        mimeType: mimeType,
        prompt: _prompt,
      );

      if (result == null || result.isEmpty) {
        setError('Gemini returned an empty explanation.');
        return;
      }

      _explanation = result;
      notifyListeners();
    } catch (e, stackTrace) {
      log('Vision explain failed: $e', stackTrace: stackTrace);
      setError('Failed to explain the image. Please try again.');
    } finally {
      setLoading(false);
    }
  }
}
