import 'dart:io';
import 'dart:typed_data';

import 'package:arte_in_ferro_rapportini/core/errors/app_exception.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class MediaService {
  MediaService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final Uuid _uuid = const Uuid();

  Future<String?> captureAndCompressPhoto(String rapportinoId) {
    return _pickAndCompressPhoto(rapportinoId, ImageSource.camera);
  }

  Future<String?> selectAndCompressPhoto(String rapportinoId) {
    return _pickAndCompressPhoto(rapportinoId, ImageSource.gallery);
  }

  Future<String?> _pickAndCompressPhoto(
    String rapportinoId,
    ImageSource imageSource,
  ) async {
    final source = await _picker.pickImage(
      source: imageSource,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (source == null) return null;

    final directory = await _reportDirectory(rapportinoId, 'foto');
    final targetPath = p.join(directory.path, '${_uuid.v4()}.jpg');
    final compressed = await FlutterImageCompress.compressAndGetFile(
      source.path,
      targetPath,
      minWidth: 1920,
      minHeight: 1080,
      quality: 76,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    if (compressed == null || !await File(compressed.path).exists()) {
      throw const AppException('Non è stato possibile comprimere la fotografia.');
    }
    return compressed.path;
  }

  Future<String> saveSignature(String rapportinoId, Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw const AppException('La firma è vuota.');
    }
    final directory = await _reportDirectory(rapportinoId, 'firma');
    final file = File(p.join(directory.path, 'firma_cliente.png'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Directory> _reportDirectory(String reportId, String child) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'rapportini', reportId, child));
    await directory.create(recursive: true);
    return directory;
  }
}

