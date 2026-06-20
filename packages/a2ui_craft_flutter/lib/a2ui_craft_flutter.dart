/// # A2UI Craft — Flutter adapter
///
/// Renders A2UI Craft (RFW-format) templates using Flutter widgets. The public
/// API (`Runtime`, `RemoteComponent`, `LocalComponentLibrary`,
/// `createCoreComponents`, ...) is intentionally identical to the other
/// framework adapters; only the rendered node type (Flutter [Widget]) differs.
library a2ui_craft_flutter;

export 'src/core_components.dart';
export 'src/remote_component.dart';
export 'src/runtime.dart';
