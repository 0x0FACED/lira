import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:zxing2/qrcode.dart';

/// Reads an invitation from a QR image without blocking the interface.
Future<String> decodeLocalSyncQrImage(Uint8List bytes) =>
    compute(_decodeInvitationImage, bytes);

String _decodeInvitationImage(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported QR image');
  final oriented = image.bakeOrientation(decoded);
  final pixels = Int32List(oriented.width * oriented.height);
  for (var y = 0; y < oriented.height; y++) {
    for (var x = 0; x < oriented.width; x++) {
      final pixel = oriented.getPixel(x, y);
      pixels[y * oriented.width + x] =
          (image.getRed(pixel) << 16) |
          (image.getGreen(pixel) << 8) |
          image.getBlue(pixel);
    }
  }
  final source = RGBLuminanceSource(oriented.width, oriented.height, pixels);
  final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
  final invitation = result.text.trim();
  if (!invitation.startsWith('lira-sync:')) {
    throw const FormatException('Not a Lira sync invitation');
  }
  return invitation;
}
