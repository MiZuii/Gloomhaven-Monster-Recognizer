import 'package:camera/camera.dart';
import 'package:image/image.dart';
import 'dart:io' show Platform;

Image convertBaseOnTargetDevice(CameraImage image) {
  if( Platform.isAndroid) { return convertYUV420toImage(image); }
  else if( Platform.isIOS) { return convertBGRA8888ToImage(image); }
  throw "Unsupported platform";
}

Image convertBGRA8888ToImage(CameraImage image) {
  final plane = image.planes[0]; 

  return Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: plane.bytes.buffer,
    rowStride: plane.bytesPerRow,
    order: ChannelOrder.bgra,
  );
}

const shift = (0xFF << 24);
Image convertYUV420toImage(CameraImage image) {
  try {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    var img = Image.new(height: height, width: width, format: Format.float32);

    // Fill image buffer with plane[0] from YUV420_888
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        double r = (yp + vp * 1436 / 1024 - 179).clamp(0, 255);
        double g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).clamp(0, 255);
        double b = (yp + up * 1814 / 1024 - 227).clamp(0, 255);

        img.getPixel(x, y).setRgb(r, g, b);
      }
    }

    return img;

  } catch (e) {
    print(">>>>>>>>>>>> ERROR:" + e.toString());
    rethrow;
  }
}
