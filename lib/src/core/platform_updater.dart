/// Abstract interface for platform configuration updates.
///
/// After icon/splash generation, each platform may need its configuration
/// files updated to reference the newly generated assets (e.g.,
/// AndroidManifest.xml, Info.plist, index.html, Runner.rc).
abstract class PlatformUpdater {
  /// Updates platform configuration files to reference generated assets.
  ///
  /// [projectRoot] is the root directory of the Flutter project.
  /// [flavorName] is the optional name of the flavor to update configuration for.
  Future<void> update(String projectRoot, {String? flavorName});
}
