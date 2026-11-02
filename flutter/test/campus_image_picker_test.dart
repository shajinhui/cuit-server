import 'dart:typed_data';

import 'package:chengxin_youyou/features/campus/presentation/campus_image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('单选和多选都传入尺寸及质量限制，不请求完整照片元数据', () async {
    final picker = _Picker();
    await pickCampusImage(picker);
    await pickCampusImages(picker, 3);
    expect(picker.dimensions, [1920, 1920]);
    expect(picker.qualities, [82, 82]);
    expect(picker.metadata, [false, false]);
    expect(picker.multiLimit, 3);
  });

  test('论坛只剩一个名额时用单选，取消不会添加图片', () async {
    final picker = _Picker();
    expect(await pickCampusImages(picker, 1), isEmpty);
    expect(picker.singleCalls, 1);
    expect(picker.multiLimit, isNull);
  });

  test('图片按真实内容确定格式，系统转码后不继续使用 HEIC 后缀', () async {
    final image = await readCampusUploadImage(
      XFile.fromData(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]),
        name: 'original.heic',
        mimeType: 'image/heic',
      ),
    );
    expect(image.filename, 'campus-image.jpg');
    expect(image.mimeType, 'image/jpeg');
  });

  test('PNG 保留格式，伪装成 JPG 的其他内容会被拒绝', () async {
    final png = await readCampusUploadImage(
      XFile.fromData(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        name: 'photo.jpg',
      ),
    );
    expect(png.mimeType, 'image/png');
    expect(png.filename, endsWith('.png'));
    await expectLater(
      readCampusUploadImage(
        XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'fake.jpg'),
      ),
      throwsA(isA<CampusImageException>()),
    );
  });

  test('处理后仍超过上传上限时拒绝上传', () async {
    await expectLater(
      readCampusUploadImage(
        XFile.fromData(Uint8List(campusImageMaxBytes + 1), name: 'large.png'),
      ),
      throwsA(isA<CampusImageException>()),
    );
  });
}

class _Picker extends ImagePicker {
  final dimensions = <double?>[];
  final qualities = <int?>[];
  final metadata = <bool>[];
  int singleCalls = 0;
  int? multiLimit;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    singleCalls++;
    dimensions.add(maxWidth);
    expect(maxHeight, maxWidth);
    qualities.add(imageQuality);
    metadata.add(requestFullMetadata);
    return null;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    bool requestFullMetadata = true,
    int? limit,
  }) async {
    dimensions.add(maxWidth);
    expect(maxHeight, maxWidth);
    qualities.add(imageQuality);
    metadata.add(requestFullMetadata);
    multiLimit = limit;
    return [];
  }
}
