/// Supported target platforms for icon and splash generation.
enum Platform {
  android,
  ios,
  macos,
  web,
  linux,
  windows,
}

/// Android icon size constants for each density bucket.
class AndroidSizes {
  AndroidSizes._();

  /// Standard launcher icon sizes per density.
  static const Map<String, int> densityBuckets = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  /// Adaptive icon foreground/background sizes per density.
  /// Adaptive icons use 108dp which scales per density.
  static const Map<String, int> adaptiveSizes = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
  };
}

/// iOS icon size constants.
class IosSizes {
  IosSizes._();

  /// The single icon size required for iOS 18+ (App Store and universal usage).
  static const int appStoreSize = 1024;
}

/// macOS icon size constants.
class MacosSizes {
  MacosSizes._();

  /// All required icon sizes for the macOS asset catalog.
  static const List<int> sizes = [16, 32, 64, 128, 256, 512, 1024];
}

/// Web icon size constants.
class WebSizes {
  WebSizes._();

  /// Favicon sizes embedded in the ICO file for broad browser compatibility.
  static const List<int> faviconSizes = [48];

  /// PWA small icon size.
  static const int pwaSmall = 192;

  /// PWA large icon size.
  static const int pwaLarge = 512;

  /// Maskable small icon size.
  static const int maskableSmall = 192;

  /// Maskable large icon size.
  static const int maskableLarge = 512;
}

/// Linux icon size constants.
class LinuxSizes {
  LinuxSizes._();

  /// Standard Linux desktop icon size.
  static const int iconSize = 512;
}

/// Windows icon size constants.
class WindowsSizes {
  WindowsSizes._();

  /// Sizes embedded in the ICO file.
  static const List<int> icoSizes = [16, 32, 48, 64, 128, 256];
}
