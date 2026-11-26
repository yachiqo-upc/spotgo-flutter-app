String? validateEvidenceImage(List<int> bytes, String contentType) {
  if (bytes.length > 5 * 1024 * 1024) {
    return 'Image must not exceed 5 MB.';
  }
  final isJpeg =
      contentType == 'image/jpeg' &&
      bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff;
  final isPng =
      contentType == 'image/png' &&
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47;
  if (!isJpeg && !isPng) {
    return 'Choose a valid JPEG or PNG image.';
  }
  if (!_withinPixelLimit(bytes, png: isPng)) {
    return 'Evidence images must not exceed 20 million pixels.';
  }
  return null;
}

bool _withinPixelLimit(List<int> bytes, {required bool png}) {
  int? width;
  int? height;
  if (png) {
    if (bytes.length < 24 ||
        bytes[12] != 0x49 ||
        bytes[13] != 0x48 ||
        bytes[14] != 0x44 ||
        bytes[15] != 0x52) {
      return false;
    }
    width = _read32(bytes, 16);
    height = _read32(bytes, 20);
  } else {
    const frameMarkers = {
      0xc0,
      0xc1,
      0xc2,
      0xc3,
      0xc5,
      0xc6,
      0xc7,
      0xc9,
      0xca,
      0xcb,
      0xcd,
      0xce,
      0xcf,
    };
    var offset = 2;
    while (offset < bytes.length) {
      if (bytes[offset++] != 0xff) continue;
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) return false;
      final marker = bytes[offset++];
      if (marker == 0xd8 ||
          marker == 0xd9 ||
          marker == 0x01 ||
          marker >= 0xd0 && marker <= 0xd7) {
        continue;
      }
      if (offset + 2 > bytes.length) return false;
      final segmentLength = bytes[offset] << 8 | bytes[offset + 1];
      if (segmentLength < 2 || offset + segmentLength > bytes.length) {
        return false;
      }
      if (frameMarkers.contains(marker)) {
        if (segmentLength < 7) return false;
        height = bytes[offset + 3] << 8 | bytes[offset + 4];
        width = bytes[offset + 5] << 8 | bytes[offset + 6];
        break;
      }
      offset += segmentLength;
    }
  }
  return width != null &&
      height != null &&
      width > 0 &&
      height > 0 &&
      width * height <= 20000000;
}

int _read32(List<int> bytes, int offset) =>
    bytes[offset] << 24 |
    bytes[offset + 1] << 16 |
    bytes[offset + 2] << 8 |
    bytes[offset + 3];
