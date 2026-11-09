import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

const campusImageMaxDimension = 1920.0;
const campusImageQuality = 82;
const campusImageMaxBytes = 5 * 1024 * 1024;

class CampusUploadImage {
  const CampusUploadImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

class CampusUploadMedia {
  const CampusUploadMedia({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.isVideo,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final bool isVideo;
}

class CampusImageException implements Exception {
  const CampusImageException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 先让已有的系统选图插件缩小尺寸、压缩质量，再读取待上传的数据。
/// 不拉伸小图、不裁切；具体编码格式由当前平台的选图插件决定。
Future<XFile?> pickCampusImage(ImagePicker picker) => picker.pickImage(
  source: ImageSource.gallery,
  maxWidth: campusImageMaxDimension,
  maxHeight: campusImageMaxDimension,
  imageQuality: campusImageQuality,
  requestFullMetadata: false,
);

Future<List<XFile>> pickCampusImages(ImagePicker picker, int remaining) async {
  if (remaining <= 0) return [];
  // image_picker 的多选至少需要两个名额，只剩一张时改用单选。
  if (remaining == 1) {
    final file = await pickCampusImage(picker);
    return file == null ? [] : [file];
  }
  final files = await picker.pickMultiImage(
    maxWidth: campusImageMaxDimension,
    maxHeight: campusImageMaxDimension,
    imageQuality: campusImageQuality,
    requestFullMetadata: false,
    limit: remaining,
  );
  return files.take(remaining).toList();
}

/// 发帖支持图片和视频混合多选。平台不支持混合媒体时回退到图片多选。
Future<List<XFile>> pickCampusMedia(ImagePicker picker, int remaining) async {
  if (remaining <= 0) return [];
  try {
    final files = await picker.pickMultipleMedia(
      maxWidth: campusImageMaxDimension,
      maxHeight: campusImageMaxDimension,
      imageQuality: campusImageQuality,
      requestFullMetadata: false,
      limit: remaining,
    );
    return files.take(remaining).toList();
  } catch (_) {
    return pickCampusImages(picker, remaining);
  }
}

const campusVideoMaxBytes = 50 * 1024 * 1024;

/// 读取发帖媒体。图片沿用原压缩和格式校验；视频接受 MP4/MOV/WebM。
Future<CampusUploadMedia> readCampusMedia(XFile file) async {
  final name = file.name.toLowerCase();
  final mime = (file.mimeType ?? '').toLowerCase();
  final isVideo =
      mime.startsWith('video/') ||
      name.endsWith('.mp4') ||
      name.endsWith('.m4v') ||
      name.endsWith('.mov') ||
      name.endsWith('.webm');
  if (isVideo) {
    if (await file.length() > campusVideoMaxBytes) {
      throw const CampusImageException('视频不能超过 50 MB，请选择更短的视频。');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const CampusImageException('视频内容为空，请重新选择。');
    }
    final mp4 =
        name.endsWith('.mp4') || name.endsWith('.m4v') || mime == 'video/mp4';
    final mov = name.endsWith('.mov') || mime == 'video/quicktime';
    final webm = name.endsWith('.webm') || mime == 'video/webm';
    if (!mp4 && !mov && !webm) {
      throw const CampusImageException('仅支持 MP4、MOV 或 WebM 视频。');
    }
    return CampusUploadMedia(
      bytes: bytes,
      filename: mov
          ? 'campus-video.mov'
          : webm
          ? 'campus-video.webm'
          : 'campus-video.mp4',
      mimeType: mov
          ? 'video/quicktime'
          : webm
          ? 'video/webm'
          : 'video/mp4',
      isVideo: true,
    );
  }
  final image = await readCampusUploadImage(file);
  return CampusUploadMedia(
    bytes: image.bytes,
    filename: image.filename,
    mimeType: image.mimeType,
    isVideo: false,
  );
}

Future<CampusUploadImage> readCampusUploadImage(XFile file) async {
  if (await file.length() > campusImageMaxBytes) {
    throw const CampusImageException('处理后的图片仍超过 5 MB，请选择尺寸更小的图片。');
  }
  final bytes = await file.readAsBytes();
  if (bytes.length > campusImageMaxBytes) {
    throw const CampusImageException('处理后的图片仍超过 5 MB，请选择尺寸更小的图片。');
  }
  final jpeg = _hasHeader(bytes, [0xff, 0xd8, 0xff]);
  final png = _hasHeader(bytes, [137, 80, 78, 71, 13, 10, 26, 10]);
  if (!jpeg && !png) {
    throw const CampusImageException('请选择 JPG 或 PNG 图片。');
  }
  // 系统可能把 HEIC 转为 JPEG，不能继续沿用原始后缀或 MIME。
  return CampusUploadImage(
    bytes: bytes,
    filename: jpeg ? 'campus-image.jpg' : 'campus-image.png',
    mimeType: jpeg ? 'image/jpeg' : 'image/png',
  );
}

bool _hasHeader(Uint8List bytes, List<int> header) {
  if (bytes.length < header.length) return false;
  for (var index = 0; index < header.length; index++) {
    if (bytes[index] != header[index]) return false;
  }
  return true;
}
