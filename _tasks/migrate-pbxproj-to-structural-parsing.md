# Migrate pbxproj manipulation from regex to structural parsing

## Problem

All `project.pbxproj` modifications across the codebase use regex-based string manipulation. This is brittle because:

- pbxproj is a structured format (NeXTSTEP/old-style ASCII plist) with nested blocks, not flat text.
- Regex patterns break when crossing block boundaries (nested `{}`, `;` within blocks).
- Targeting the correct section (e.g., Runner vs RunnerTests build phase) requires tracing relationships across sections — something regex can't scope reliably.
- Insertions land in the wrong target, removals miss edge cases, and patterns fail on non-standard formatting.

### Known bugs caused by regex approach

- `macos_asset_catalog_linker.dart` inserted `Assets.xcassets in Resources` into the **RunnerTests** build phase instead of the **Runner** build phase because the regex matched the first `PBXResourcesBuildPhase` encountered in the file.
- Multi-target projects (Runner + RunnerTests + extensions) have non-deterministic ordering in pbxproj — regex that works on one project fails on another.

---

## Scope & effort estimate

This is a **large architectural migration** spanning multiple weeks:

- **Parser foundation**: ~3–5 files, ~800 lines of parser code
- **Query/mutation API**: ~2–3 files, ~400 lines
- **Migration of 6 existing files**: each requires rewrite of pbxproj manipulation logic
- **Test fixtures**: real pbxproj files from multiple project configurations
- **Validation**: byte-level comparison, Xcode build verification

---

## Current state

Files doing regex-based pbxproj manipulation:

| File                                                      | Operations                                                                  | Complexity                                            |
| --------------------------------------------------------- | --------------------------------------------------------------------------- | ----------------------------------------------------- |
| `lib/src/platforms/macos/macos_legacy_icon_cleaner.dart`  | Remove PBXFileReference, PBXBuildFile, Resources phase entries for `.icns`  | Medium — multi-section removal by pattern             |
| `lib/src/platforms/macos/macos_asset_catalog_linker.dart` | Add PBXBuildFile + insert into correct target's Resources phase             | High — must identify correct target                   |
| `lib/src/platforms/macos/macos_updater.dart`              | Inject/replace `ASSETCATALOG_COMPILER_APPICON_NAME` in buildSettings        | Medium — multiple buildSettings blocks                |
| `lib/src/platforms/macos/macos_pbxproj_patcher.dart`      | Clone build configs per flavor, add xcconfig file refs, update config lists | Very high — 300+ lines of regex, nested block cloning |
| `lib/src/platforms/ios/ios_pbxproj_patcher.dart`          | Same as macOS patcher for iOS                                               | Very high — same complexity                           |
| `lib/src/platforms/ios/ios_updater.dart`                  | Inject `ASSETCATALOG_COMPILER_APPICON_NAME` for iOS                         | Medium                                                |
| `lib/src/shared/xcode/swift_version_resolver.dart`        | Read-only: extract `SWIFT_VERSION` from buildSettings                       | Low — read-only, regex is acceptable                  |

---

## pbxproj format overview

The `project.pbxproj` file is an **old-style ASCII plist** with a specific Xcode schema:

```
// !$*UTF8*$!
{
    archiveVersion = 1;
    classes = { };
    objectVersion = 54;
    objects = {

/* Begin PBXBuildFile section */
        AABBCCDD /* Assets.xcassets in Resources */ = {
            isa = PBXBuildFile;
            fileRef = 11223344 /* Assets.xcassets */;
        };
/* End PBXBuildFile section */

/* Begin PBXNativeTarget section */
        33CC10EC /* Runner */ = {
            isa = PBXNativeTarget;
            buildPhases = (
                33CC10EB /* Resources */,
                33CC10E9 /* Sources */,
                33CC10EA /* Frameworks */,
            );
            buildConfigurationList = 33CC10ED /* ... */;
            name = Runner;
            productType = "com.apple.product-type.application";
        };
        331C80D2 /* RunnerTests */ = {
            isa = PBXNativeTarget;
            buildPhases = (
                331C80D3 /* Resources */,
                331C80D4 /* Sources */,
            );
            name = RunnerTests;
            productType = "com.apple.product-type.bundle.unit-test";
        };
/* End PBXNativeTarget section */

/* Begin PBXResourcesBuildPhase section */
        331C80D3 /* Resources */ = {
            isa = PBXResourcesBuildPhase;
            files = ( );
        };
        33CC10EB /* Resources */ = {
            isa = PBXResourcesBuildPhase;
            files = (
                AABBCCDD /* Assets.xcassets in Resources */,
            );
        };
/* End PBXResourcesBuildPhase section */

    };
    rootObject = 33CC10E5 /* Project object */;
}
```

Key characteristics:

- **Sections** are delimited by `/* Begin X section */` / `/* End X section */` comments
- **Object IDs** are 24-character hex strings (or 8-char in older projects)
- **Comments** (`/* ... */`) appear after IDs everywhere — they're informational, not semantic
- **Values** can be: strings, quoted strings, arrays `( )`, dictionaries `{ }`, or references (bare IDs)
- **Relationships** are by object ID — a target references its build phases by their IDs
- **Ordering** within sections is non-deterministic — Xcode may reorder entries

---

## Target architecture (recommended: Option C — minimal targeted parser)

### File structure

```text
lib/src/shared/xcode/
├── pbxproj_file.dart           <-- Top-level API: load, query, mutate, save
├── pbxproj_tokenizer.dart      <-- Tokenizes raw content into tokens
├── pbxproj_section_parser.dart <-- Parses section boundaries and object entries
├── pbxproj_object.dart         <-- Data model for parsed objects
├── pbxproj_serializer.dart     <-- Writes modified objects back to valid format
└── swift_version_resolver.dart <-- Existing (low risk, can stay regex-based)
```

### Public API surface

```dart
/// Top-level entry point for pbxproj manipulation.
class PbxprojFile {
  /// Loads and parses a project.pbxproj file.
  factory PbxprojFile.load(String path);

  /// Finds a PBXNativeTarget by productType.
  /// e.g., 'com.apple.product-type.application' for the main app.
  PbxObject? findNativeTarget({required String productType});

  /// Finds a PBXNativeTarget by name (fallback).
  PbxObject? findNativeTargetByName(String name);

  /// Given a target, returns its PBXResourcesBuildPhase object.
  PbxObject? resourcesBuildPhase(PbxObject target);

  /// Given a target, returns its PBXSourcesBuildPhase object.
  PbxObject? sourcesBuildPhase(PbxObject target);

  /// Finds a PBXFileReference by its `path` field value.
  PbxObject? findFileReference({required String path});

  /// Finds a PBXBuildFile by its `fileRef` ID.
  PbxObject? findBuildFile({required String fileRefId});

  /// All objects in a given section (e.g., 'PBXBuildFile').
  List<PbxObject> section(String sectionName);

  /// Adds an object to a section. Returns the generated/provided ID.
  String addObject(String sectionName, PbxObject object);

  /// Removes an object by ID from its section.
  void removeObject(String objectId);

  /// Adds an ID to an array field on an existing object.
  /// e.g., adding a build file ID to a phase's `files` array.
  void addToArrayField(String objectId, String fieldName, String valueId,
      {String? comment});

  /// Removes an ID from an array field.
  void removeFromArrayField(
      String objectId, String fieldName, String valueId);

  /// Gets a field value from an object.
  String? getField(String objectId, String fieldName);

  /// Sets a field value on an object.
  void setField(String objectId, String fieldName, String value);

  /// Writes the modified content back to the file.
  void save();
}

/// Represents a parsed pbxproj object (one entry within a section).
class PbxObject {
  final String id;
  final String? comment;        // e.g., "Runner", "Assets.xcassets"
  final String isa;             // e.g., "PBXNativeTarget"
  final Map<String, dynamic> fields;
}
```

### How current operations would look after migration

**Adding Assets.xcassets to Runner's Resources phase (currently `macos_asset_catalog_linker.dart`):**

```dart
void link(String projectRoot) {
  final pbx = PbxprojFile.load(
    '$projectRoot/macos/Runner.xcodeproj/project.pbxproj',
  );

  // Check if already linked.
  final existing = pbx.findBuildFile(fileRefId: assetCatalogRef.id);
  if (existing != null) return;

  // Find Assets.xcassets file reference.
  final fileRef = pbx.findFileReference(path: 'Assets.xcassets');
  if (fileRef == null) return;

  // Find the app target's Resources phase.
  final appTarget = pbx.findNativeTarget(
    productType: 'com.apple.product-type.application',
  );
  if (appTarget == null) return;
  final resourcesPhase = pbx.resourcesBuildPhase(appTarget);
  if (resourcesPhase == null) return;

  // Add PBXBuildFile entry.
  final buildFileId = pbx.addObject('PBXBuildFile', PbxObject(
    isa: 'PBXBuildFile',
    comment: 'Assets.xcassets in Resources',
    fields: {'fileRef': fileRef.id},
  ));

  // Add to Resources phase files list.
  pbx.addToArrayField(resourcesPhase.id, 'files', buildFileId,
      comment: 'Assets.xcassets in Resources');

  pbx.save();
}
```

**Removing .icns entries (currently `macos_legacy_icon_cleaner.dart`):**

```dart
void cleanPbxproj(String projectRoot) {
  final pbx = PbxprojFile.load(
    '$projectRoot/macos/Runner.xcodeproj/project.pbxproj',
  );

  // Find all .icns file references.
  final icnsRefs = pbx.section('PBXFileReference')
      .where((obj) => obj.fields['path']?.toString().endsWith('.icns') ?? false)
      .toList();

  for (final ref in icnsRefs) {
    // Remove associated PBXBuildFile entries.
    final buildFile = pbx.findBuildFile(fileRefId: ref.id);
    if (buildFile != null) {
      // Remove from any build phase files arrays.
      // ... (parser handles finding which phases reference it)
      pbx.removeObject(buildFile.id);
    }
    // Remove the file reference itself.
    pbx.removeObject(ref.id);
  }

  pbx.save();
}
```

---

## Migration plan (detailed)

### Phase 1: Parser foundation (estimated: 3–4 days)

**Deliverables:**

- `pbxproj_tokenizer.dart` — tokenizes `{`, `}`, `(`, `)`, `=`, `;`, strings, comments
- `pbxproj_section_parser.dart` — identifies sections, parses objects within them
- `pbxproj_object.dart` — data model

**Acceptance criteria:**

- Can load a real `project.pbxproj` from `flutter create` and parse all sections
- Can load a complex project with multiple targets, extensions, build configs
- Round-trip: `parse → serialize` produces byte-identical output (no modifications)
- Unit tests with fixture files covering: single target, multi-target, flavored project

**Risks:**

- Quoted strings with special chars (spaces, backslashes, unicode)
- Inline vs multi-line comments
- Array entries with and without trailing commas
- Objects spread across one line vs multi-line

### Phase 2: Query layer (estimated: 2–3 days)

**Deliverables:**

- `pbxproj_file.dart` — public API with query methods
- Target lookup, build phase lookup, file ref lookup, build file lookup

**Acceptance criteria:**

- `findNativeTarget(productType: 'com.apple.product-type.application')` returns correct target in multi-target project
- `resourcesBuildPhase(target)` follows the ID chain correctly
- `findFileReference(path: 'Assets.xcassets')` works regardless of section ordering

### Phase 3: Mutation layer (estimated: 2–3 days)

**Deliverables:**

- `addObject`, `removeObject`, `addToArrayField`, `removeFromArrayField`, `setField`
- `pbxproj_serializer.dart` — writes modified state back

**Acceptance criteria:**

- Adding an object produces valid pbxproj that Xcode can open
- Removing an object removes it from all referencing arrays
- Setting a field value preserves surrounding formatting
- ID generation produces unique 24-char hex IDs

**Risks:**

- Preserving formatting and comment styles on write
- Handling the case where a section doesn't exist yet (needs `/* Begin X section */` creation)
- Orphan references after removal (build file removed but ID still in a phase's `files`)

### Phase 4: Migrate existing code (estimated: 4–5 days)

Migrate one file at a time. Each migration is a standalone PR.

| Order | File                              | Reason for ordering                     |
| ----- | --------------------------------- | --------------------------------------- |
| 1     | `macos_asset_catalog_linker.dart` | Simplest — one add operation            |
| 2     | `macos_legacy_icon_cleaner.dart`  | Remove operations — tests already exist |
| 3     | `macos_updater.dart`              | Field modification (buildSettings)      |
| 4     | `ios_updater.dart`                | Same pattern as macOS updater           |
| 5     | `macos_pbxproj_patcher.dart`      | Most complex — config cloning           |
| 6     | `ios_pbxproj_patcher.dart`        | Same complexity as macOS patcher        |

**Per-file acceptance criteria:**

- Existing tests pass without modification (behavior unchanged)
- No regex patterns remain for pbxproj manipulation in that file
- File stays under 200 lines

### Phase 5: Validation (estimated: 2–3 days)

**Test matrix:**

| Project type                                    | Targets                          | Configurations                    |
| ----------------------------------------------- | -------------------------------- | --------------------------------- |
| Fresh `flutter create` (macOS)                  | Runner + RunnerTests             | Debug/Release/Profile             |
| Fresh `flutter create` (iOS)                    | Runner + RunnerTests             | Debug/Release/Profile             |
| Existing project with flavors                   | Runner + RunnerTests             | Debug/Release/Profile × N flavors |
| Project with app extensions                     | Runner + RunnerTests + Extension | Multiple                          |
| Older Xcode project format (objectVersion < 54) | Runner only                      | Debug/Release                     |

**Validation steps:**

1. Run the tool on each test project
2. Open in Xcode — no errors, project navigable
3. Build succeeds (`xcodebuild -scheme Runner build`)
4. Icons appear correctly
5. Diff output against known-good regex output (if available)

---

## Constraints

- Must remain a pure Dart package (no Flutter SDK, no Ruby, no system tools).
- Parser lives in `lib/src/shared/xcode/` (shared between iOS and macOS platforms).
- Each file stays under **200 lines** — parser will need 4–5 files.
- Existing tests must continue passing after migration.
- `swift_version_resolver.dart` is read-only and low risk — can stay regex-based or migrate last.

---

## References

- pbxproj format: NeXTSTEP ASCII property list (`.pbxproj` is a specific Xcode schema on top)
- `xcodeproj` Ruby gem source (reference implementation): https://github.com/CocoaPods/Xcodeproj
- Xcode project file format (unofficial docs): https://pewpewthespells.com/blog/pbxproj_identifiers.html
- Apple's old-style plist grammar: `{ key = value; }` with `( array, items )` and `/* comments */`
