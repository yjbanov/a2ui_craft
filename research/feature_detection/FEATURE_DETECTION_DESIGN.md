# Research: Feature Detection across Clients, Form Factors, and Versions

The question: A2UI Craft templates are
authored once, deployed ephemerally (e.g. via CDN or dynamic services), and rendered
across clients that differ along multiple dimensions:

1. **Client version / API skew:** different host app builds have different sets of
   primitives and local functions, evolving widgets (new optional arguments), evolving
   functions, and evolving data schemas.
2. **Form factors & hardware capabilities:** phones and watches have GPS, cameras,
   and NFC, while laptops and TVs do not. A template rendering for a phone/watch might
   render a live `Location` or `Camera` widget, while on a laptop it should render a
   `LocationFinder` search box or `PhotoPicker`.
3. **Platform-specific ecosystems:** iOS provides `ApplePay`; Android provides
   `GooglePay`.

Crucially, in production **a template must not crash on a client that lacks a widget or feature
if it does not render that branch.**. This can be strict during testing. Furthermore,
feature detection must **preserve dead code elimination (DCE) and minification** on
both the host and the remote template.

Because A2UI Craft is in its pre-1.0 infancy and not yet published, we have the mandate
and opportunity to get feature detection, metadata reflection, and host-side template
compilation designed directly into the foundation from day one.

This document surveys the design space, investigates how the engine currently behaves
when encountering missing features, analyzes candidate mechanisms, and proposes a
unified architecture.

---

## 1. Executive Summary & Thesis

Feature detection in A2UI Craft cannot be solved by a single mechanism because
**client differences exist at two fundamentally distinct layers**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          1. PHYSICAL & AMBIENT                              │
│  Hardware Sensors & Modalities (GPS, Camera, NFC, Touch, D-Pad, Biometrics) │
│  Form Factors (Watch, Phone, Tablet, Laptop, TV, Auto)                      │
│  OS Environment (iOS, Android, macOS, Windows, Linux, Web)                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  -> Belongs in MediaContext (ambient, dynamic, re-renders on permission/dock)│
│  -> Referenced via: media.formFactor, media.platform, media.capabilities.*   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      ▲
                                      │ Complementary
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          2. RUNTIME ENGINE & API                            │
│  Widget Primitives (ApplePay, Location, Markdown, Custom primitives)        │
│  Arbitrary Immutable Metadata (args, semver, API levels, a11y strings)      │
│  Pure Functions (geoDistance, formatCurrency, fancyMath)                    │
│  Engine & App Versions (runtime version, host app build)                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  -> Belongs in Runtime Introspection (static, host-registered symbol tables) │
│  -> Referenced via: Location.args.latLong, meta(w: ...), hasWidget(...)     │
│  -> Constant-folded at host load time (dead branches excised before render) │
└─────────────────────────────────────────────────────────────────────────────┘
```

Conflating these two layers creates severe failure modes:
- **Testing hardware to assume API presence:** Checking `media.hasGps` does not guarantee
  the host app compiled or registered the `Location` widget primitive into its
  `LocalWidgetLibrary`.
- **User-Agent sniffing:** Checking `media.platform == "ios"` to show `ApplePay` fails
  on iPads without Apple Pay, in enterprise environments where it is disabled, or when
  rendered in a third-party host that did not link payment libraries.
- **Testing APIs to assume hardware presence:** A laptop host might link a shared
  library containing the `Location` primitive, but the laptop hardware lacks a GPS
  provider, leading to runtime timeouts or blank maps.

### Core Architectural Conclusions

1. **Two-Pillar Architecture:**
   - **Pillar 1 (Environmental Capabilities):** Expand `MediaContext` (`media.` scope)
     with quantized device form factors, target platform, and hardware capability flags.
   - **Pillar 2 (Runtime API Introspection & Metadata):** Provide an open metadata
     inspection system allowing hosts to attach arbitrary static data to any local widget
     or function, accessible via direct language member access (`Location.args.latLong`),
     dynamic queries (`meta(w: ...)`), and semantic convenience shorthands (`hasWidget`).
2. **Mechanism, Not Policy:** The engine does not impose opinions on how host apps
   version their primitives (semver vs. integer levels) or restrict reflection to argument
   names. Attaching open metadata dictionaries (`Map<String, Object?>`) enables versioning,
   argument detection, static accessibility (a11y) strings, and business capabilities
   under a single unified mechanism.
3. **First-Class Language Integration (`Location.args.latLong`):**
   In RFW, constructor calls refer to widgets unprefixed: `Location(...)`. Therefore,
   property/metadata reflection should refer to widgets unprefixed: `Location.args.latLong`.
   A synthetic `meta.` prefix (`meta.Location`) would be redundant and semantically inverted
   (implying "meta contains Location", rather than "Location has metadata").
4. **Strict Immutability & Host-Side Constant Folding:**
   Unlike reactive data (`data.`) or ambient snapshots (`media.`), host metadata is
   **strictly immutable**. When a template is loaded (`runtime.update`), the host engine
   runs an AST specialization pass that evaluates static metadata checks, folds pure boolean
   expressions, and **prunes dead branches before the template is ever evaluated or bound**.
5. **No Redundant Primitives:**
   Instead of introducing an artificial `FeatureGate` primitive that duplicates `Switch`,
   Craft relies cleanly on its existing language `Switch` construct. Constant folding
   ensures `switch Location.args.latLong` incurs zero runtime overhead.
6. **Dead Code Elimination (DCE) is Preserved by Construction:**
   - Host primitives and functions are registered via explicit string maps (`LocalWidgetLibrary`,
     `LocalFunctionLibrary`). Host DCE operates ahead-of-time (Dart AOT / dart2js): unreferenced
     Dart classes are stripped. Introspection only queries what the host explicitly retained.
   - Remote templates never self-reflect on their own definitions (`WidgetDeclaration`),
     allowing template-private widgets to be renamed, minified, or dead-code eliminated
     freely by offline tooling.

---

## 2. Taxonomy of Client Variation

Templates encounter variation across three distinct axes:

### Axis 1: Temporal / Version Skew (Host App & Engine Evolution)

| Variation | Example | Risk / Consequence if Unhandled |
| :--- | :--- | :--- |
| **New Primitive Widget** | Host v1.0 has core primitives; Host v1.1 adds `BarcodeScanner` or `Markdown`. | Rendering `BarcodeScanner` on v1.0 crashes or displays an `ErrorWidget`. |
| **Evolving Widget Arguments** | Host v1.0 `Location(address: "...")`; Host v1.1 adds `Location(latLong: [...], zoom: 15)`. | Old client ignores `zoom`; template doesn't know it needs to render separate zoom buttons. |
| **New Pure Functions** | Host v1.0 has standard arithmetic/strings; Host v1.2 adds `formatCurrency(val, "USD")` or `geoDistance(...)`. | Old client throws or fails to evaluate the expression. |
| **Evolving Function Arguments** | Host v1.0 `math(val: 42)`; Host v1.1 adds optional `precision: 2`. | In debug mode, older client's eager bind validation throws on unselected branches. |
| **Evolving Data Fields** | Host data model adds `user.coordinates` alongside `user.zipCode`. | Safe today via totality (`data.user.coordinates` yields `null` on older data). |
| **Custom Primitives** | Host app registers brand-specific widgets (`AcmeLoyaltyCard`). | Shared templates must detect whether they are embedded in `AcmeApp` or a generic host. |

### Axis 2: Physical / Hardware Capabilities & Form Factors

| Form Factor / Device | Hardware Capabilities | Appropriate UI Strategy |
| :--- | :--- | :--- |
| **Phone / Watch** | High-accuracy GPS, accelerometer, rear/front cameras, NFC, cellular. | Live `Location` map widget, direct `Camera` capture, tap-to-pay. |
| **Laptop / Desktop** | Wi-Fi IP location only, webcam only, mouse + keyboard, large screen. | `LocationFinder` search box, file/photo picker, standard credit card checkout. |
| **TV / 10-foot UI** | Remote control / D-pad focus navigation, no camera, no touch, no GPS. | Large glanceable cards, address entry via on-screen keyboard / search. |
| **Automotive Display** | Safety-constrained, voice-first, glanceable, high contrast, GPS. | Minimal interaction, high-level route summary. |

### Axis 3: Platform Ecosystem & Native Integrations

| Feature | Platform A | Platform B | Fallback |
| :--- | :--- | :--- | :--- |
| **Express Checkout** | `ApplePay` (iOS, macOS Safari) | `GooglePay` (Android, Chrome) | Standard `CreditCardForm` |
| **Media Capture** | `Camera` (hardware viewfinder) | `PhotoPicker` (file system / gallery) | File upload input |
| **Sharing** | Native OS Share Sheet | Web Share API | Copy link to clipboard |
| **Authentication** | FaceID / TouchID / Biometrics | Screen lock credential | Password field |

---

## 3. Deep Dive: Current Engine Behavior

Before proposing new mechanisms, we must trace what the engine does today when a template
references a missing widget or function.

### 3.1 Parse Time (`text.dart` and `binary.dart`)

```rfw
widget MyComponent = switch args.useNew {
  true: FutureWidget(specialArg: 123),
  default: StandardWidget(),
};
```

1. The text parser encounters `FutureWidget(specialArg: 123)`.
2. It does **not** check whether `FutureWidget` exists in any widget library.
3. It emits a `ConstructorCall('FutureWidget', {'specialArg': 123})`.
4. **Result:** Any syntactic widget or function call parses cleanly into AST and binary.
   The parser is completely agnostic to library contents.

### 3.2 Bind Time (`runtime.dart` in Flutter and Jaspr)

When `Runtime.build` is called:

1. `_bindArguments` recursively walks the AST.
2. For each `ConstructorCall`:
   - It checks `_functions[node.name]`. If present, creates `_FunctionCall`.
   - Otherwise, it queries `_findConstructor(FullyQualifiedWidgetName(library, node.name))`.
   - If not found:
     ```dart
     return _CurriedLocalWidget.error(fullName,
         'Could not find remote widget named ${fullName.widget} in ${fullName.library}.')
       ..propagateSource(source);
     ```
3. **Critical Observation:** `_bindArguments` **does not throw** when a widget constructor
   is missing. It wraps the missing constructor in an error widget builder.
4. If this missing widget sits inside an arm of a `Switch`:
   - The `Switch` node holds `_CurriedLocalWidget.error` for the `true` arm and
     `_CurriedLocalWidget` (valid) for the `default` arm.

### 3.3 Render Time (`runtime.dart`)

1. During `_CurriedSwitch.buildChild`, the engine evaluates the switch condition via
   `_resolveFrom`.
2. If the condition resolves to `default`:
   - It selects the `default` arm.
   - It builds and mounts `StandardWidget`.
   - The `FutureWidget` error builder is **never invoked, never built, and never mounted**.
3. **Result:** In the existing engine, **unselected branches containing missing widgets
   already do not crash the app!**

### 3.4 The Latent Bug: Eager Function Argument Validation

While missing widgets degrade safely, **functions currently have an eager validation bug
in debug mode**.

In `runtime.dart`:
```dart
final LocalFunction? function = _functions[node.name];
if (function != null && ...) {
  assert(() {
    _debugValidateFunctionArguments(node.name, function, subArguments);
    return true;
  }());
  return _FunctionCall(node.name, function.implementation, subArguments);
}
```

If a template attempts to branch on an evolving function:
```rfw
switch hasFunctionArg(function: "math", arg: "precision") {
  true: math(val: 42, precision: 2),
  default: math(val: 42),
}
```

On an older client where `math` exists but only declares argument `val`:
1. `_bindArguments` runs eagerly on **all** arms of the `Switch`.
2. For `math(val: 42, precision: 2)`, `_debugValidateFunctionArguments` runs.
3. It encounters `precision`, which is not in `function.arguments`.
4. It **throws `RemoteFlutterWidgetsException` immediately at bind time**, crashing before
   the `Switch` can ever evaluate `hasFunctionArg`!

> [!IMPORTANT]
> **Prerequisite Engine Invariant:**
> For feature detection to work reliably, function argument validation and missing function
> handling must be **error-contained**. An invalid or unknown function call in an AST
> branch must yield a deferred error node (analogous to `_CurriedLocalWidget.error`) rather
> than throwing eagerly during tree binding.
>
> *(Note: Host-side constant folding (§6.4) excises unselected dead branches before `_bindArguments`
> ever runs, providing a complete structural defense).*

---

## 4. Evaluation of Candidate Approaches

### Approach A: Expansion of the Media Query Mechanism (`MediaContext` / `media.`)

In this approach, `MediaContext` is expanded to carry hardware and platform capabilities:

```dart
class MediaContext {
  final WindowSizeClass width;
  final WindowHeightClass height;
  final ScreenOrientation orientation;
  final bool reducedMotion;

  // Proposed environmental additions:
  final DeviceFormFactor formFactor; // phone, watch, tablet, desktop, tv, auto
  final TargetPlatform platform;    // ios, android, macos, windows, linux, web
  final Set<String> capabilities;   // 'gps', 'camera', 'biometrics', 'nfc', 'applePay'
}
```

Exposed in the template via the existing `media.` scope:
```rfw
widget LocationSpecimen = switch media.capabilities.gps {
  true: Location(latLong: args.pos),
  default: LocationFinder(city: args.city),
};
```

#### Evaluation:
- **Pros:**
  - Naturally fits the reactive snapshot model: if the user grants GPS permission, or plugs
    in an external camera, the host supplies a new `MediaContext` snapshot and the template
    re-renders in place (identical to a dark-mode toggle or viewport resize).
  - Familiar mental model (mirrors web media queries and Flutter `MediaQuery`).
  - Zero syntax or parser changes.
- **Cons:**
  - **Cannot detect API / widget availability:** The host might be running on a phone with
    GPS, but the host application binary may have been compiled without the `Location`
    primitive.
  - **Cannot detect widget arguments:** It cannot answer whether `Location` supports `zoom`.
  - **Host burden:** The host developer must manually enumerate and maintain every capability
    string in `MediaContext`. If the host forgets to set `capabilities: {'applePay'}`, the
    template will never use `ApplePay` even though the widget is fully registered and working.

### Approach B: Dedicated Ambient Reference Scope (`runtime.` / `meta.`)

Introduce a new ambient reference scope, alongside `args.`, `data.`, `state.`, `theme.`,
and `media.`:

```rfw
widget MapSpecimen = switch meta.Location.args.latLong {
  true: Location(latLong: args.pos),
  default: Location(address: args.address),
};
```

#### Evaluation:
- **Pros:**
  - Separates static metadata from physical presentation.
- **Cons:**
  - Forces a synthetic namespace prefix (`meta.`) that inverts the subject-property relationship.
    In RFW, widgets are instantiated unprefixed (`Location(...)`). It is semantically illogical
    to say "meta contains Location"; rather, "Location has metadata".
  - Direct member access (`Location.args.latLong`, see §6.2) is cleaner and more natural.

### Approach C: Runtime Reflection via Introspection Functions

Provide standard pure functions in the function library:

```rfw
widget PaySpecimen = switch hasWidget(name: "ApplePay") {
  true: ApplePay(amount: args.total),
  default: switch hasWidget(name: "GooglePay") {
    true: GooglePay(amount: args.total),
    default: CreditCardForm(),
  },
};
```

#### Evaluation:
- **Pros:**
  - **Zero Language / Parser / Binary Churn:** RFW already parses `hasWidget(name: "ApplePay")`
    as a `ConstructorCall`.
  - **Dynamic Queries:** Allows querying widgets by dynamic variable string (e.g. `hasWidget(name: args.targetWidget)`).
  - **Strict and Total:** If the widget does not exist, `hasWidget` returns `false`.
- **Cons:**
  - More verbose than direct dot-syntax for common static checks.

---

## 5. Dead Code Elimination (DCE) & Minification Rationale

A major concern when introducing reflection into any framework is the impact on compiler
optimizations (dead code elimination and minification).

### 5.1 Host-Side Dead Code Elimination

In traditional Dart or JavaScript, general-purpose reflection (`dart:mirrors`, `Class.forName`,
or arbitrary string evaluation) disables tree shaking because the compiler cannot determine
which symbols might be accessed at runtime.

In A2UI Craft, runtime reflection does **not** defeat host DCE:

1. **Explicit Symbol Dictionaries:**
   The host registers primitives and functions using explicit map literals:
   ```dart
   LocalWidgetLibrary({
     'Text': buildText,
     'Button': buildButton,
     'ApplePay': buildApplePay,
   });
   ```
2. **Standard Compiler Tree Shaking:**
   - If an application never includes `ApplePay` in its `LocalWidgetLibrary`, the `buildApplePay`
     function and all its underlying dependencies (PassKit, native channels) are **completely
     unreferenced** in Dart code and are cleanly tree-shaken from the compiled host binary.
   - The runtime introspection function `hasWidget(name: "ApplePay")` or direct lookup
     `ApplePay.meta` simply checks: `runtime.libraries.containsKey("ApplePay")`.
   - Checking for the presence of a key in a map does not require retaining the unreferenced
     symbol! If `ApplePay` was tree-shaken, the key is absent, and the check returns `false` or `null`.

### 5.2 Remote Template Minification & Symbol Obfuscation

A2UI Craft enforces a strict separation between **host primitives** and **template widgets**:

```
┌────────────────────────────────────────────────────────────┐
│                    Host Application                        │
│  Public Primitives Contract: "Text", "Button", "ApplePay"  │
│  (Fixed string tokens — non-minifiable public API)        │
└────────────────────────────────────────────────────────────┘
                              ▲
                              │ Invoked over boundary
                              ▼
┌────────────────────────────────────────────────────────────┐
│                    Remote Template                         │
│  Private Widgets: "widget _MyInternalCard = ..."           │
│  Private State:   "state._counter"                         │
│  (Author-private — 100% minifiable & tree-shakable)        │
└────────────────────────────────────────────────────────────┘
```

1. **No Template Self-Reflection:**
   Templates can **only** introspect the host runtime (`Location.args`, `hasWidget`, `meta`). Templates
   can **never** introspect other remote template declarations or private symbols.
2. **Safe Tooling Optimization:**
   Because templates cannot ask `"Does template widget _MyInternalCard exist?"`, offline
   template compilers, bundlers, or binary packagers can:
   - Rename private widget declarations to short mangled names (e.g. `_MyInternalCard` → `w1`).
   - Eliminate unused template declarations (DCE of unreferenced `.craft` files).
   - Inline single-use templates.

---

## 6. The Unified Metadata Architecture

### 6.1 The Three Tiers of Data Dynamicity in Craft

To reason clearly about metadata, we must categorize how data behaves in A2UI Craft:

```
┌────────────────────────┬──────────────────────────┬─────────────────────────────┐
│ Category               │ Mechanism                │ Dynamicity & Reactivity     │
├────────────────────────┼──────────────────────────┼─────────────────────────────┤
│ 1. Reactive Data       │ DynamicContent           │ Fully dynamic, mutable,     │
│    (data., state.)     │ Pub-sub subscriptions    │ push-updated at runtime.    │
├────────────────────────┼──────────────────────────┼─────────────────────────────┤
│ 2. Ambient Environment │ MediaContext             │ Host-measured snapshot,     │
│    (media.)            │ re-renders on change     │ changes on resize/dock.     │
├────────────────────────┼──────────────────────────┼─────────────────────────────┤
│ 3. Host Metadata       │ LocalWidget.meta         │ Strictly immutable, static, │
│    (Location.args)     │ LocalFunction.meta       │ constant-folded at load.    │
└────────────────────────┴──────────────────────────┴─────────────────────────────┘
```

Host metadata belongs to Tier 3. It is **strictly immutable**: once a `LocalWidgetLibrary`
or `LocalFunctionLibrary` is registered with the `Runtime`, its metadata dictionary cannot
be modified at runtime (enforced via `const` or `Map.unmodifiable`).

#### Why Strict Immutability Matters (Contrasted with Tiers 1 & 2)

| Dimension | Tier 1: Reactive Data (`data.`, `state.`) | Tier 2: Ambient Environment (`media.`) | Tier 3: Host Metadata (`Location.args`) |
| :--- | :--- | :--- | :--- |
| **Lifecycle** | Ephemeral, session-lived, mutated by server/host events. | Host-measured snapshot, changes on window resize, rotation, or OS permission grant. | Engine/host build-time constant; fixed when the host registers libraries. |
| **Reactivity** | Registers pub-sub listeners in `DynamicContent`; triggers targeted subtree re-renders. | Triggers full-tree layout/responsive re-evaluation when media state changes. | **Zero pub-sub tracking.** Does not listen or re-render; values never change during a session. |
| **Evaluation Time** | Bound dynamically on each build/render pass. | Bound dynamically on each build/render pass. | **Evaluated ahead-of-time** during `runtime.update()` (template load/compilation). |
| **AST Impact** | Dynamic data cannot alter AST structure; only passes values into widget slots. | Re-evaluates conditional branches dynamically at render time. | **Prunes dead AST branches permanently** before the template is ever evaluated or bound. |
| **Failure Containment** | Safe via totality (`null` on missing keys). | Safe via default enum/boolean values. | Unselected branches containing missing widgets or unknown functions are **completely eliminated from the AST**, guaranteeing zero crashes even in debug mode. |

Because Tier 3 is strictly immutable, it is safe to perform aggressive **host-side constant folding and specialization** at `runtime.update()` time.

### 6.2 Mechanism over Policy

Instead of hardcoding specialized reflection functions for every conceivable question
(`hasWidgetArg`, `hasFunctionArg`, `widgetVersion`, `functionVersion`, `apiLevel`), the
engine provides a **single, open mechanism**:

> **Host app developers can attach arbitrary static metadata (`Map<String, Object?>`) to any
> local widget and any local function.**

The templating engine remains **completely unopinionated** regarding:
- The structure of the metadata dictionary.
- The versioning scheme (SemVer strings, incrementing integer API levels, or release dates).
- The domain meaning of keys (a11y strings, hardware requirements, business capabilities).

```dart
/// A local primitive widget descriptor with optional static metadata.
class LocalWidget {
  const LocalWidget({
    required this.builder,
    this.meta = const <String, Object?>{},
  });

  final LocalWidgetBuilder builder;

  /// Arbitrary static metadata provided by the host developer.
  final Map<String, Object?> meta;
}
```

And in `LocalFunction`:
```dart
class LocalFunction {
  const LocalFunction({
    required this.arguments,
    required this.implementation,
    this.meta = const <String, Object?>{},
  });

  final Map<String, FunctionArgType> arguments;
  final LocalFunctionImplementation implementation;
  final Map<String, Object?> meta;
}
```

Backward compatibility: `LocalWidgetLibrary` continues to accept plain `LocalWidgetBuilder`
closures; if provided without `LocalWidget`, `meta` is treated as an empty map `{}`.

---

### 6.3 Syntactic Representations: Direct Member Access vs. Functions

How does a template inspect this metadata? There are three complementary access levels:

#### Level 1: Direct Language Member Access (`Location.args.latLong`)

In RFW, constructor calls refer to widgets unprefixed: `Location(...)`. Therefore,
property/metadata reflection should refer to widgets unprefixed: `Location.args.latLong`.
This elevates widgets and functions to first-class citizens in expression space:

```rfw
switch Location.args.latLong {
  true: Location(latLong: args.pos),
  default: Location(address: args.address),
}
```

And for functions:
```rfw
switch geoDistance.since {
  null: FallbackDistance(),
  default: Text(text: geoDistance(from: args.p1, to: args.p2)),
}
```

**Grammar & Parser Integration:**
In `_readValue` in `packages/a2ui_craft/lib/src/text.dart`:
1. If an identifier is followed by `(`, it is a `ConstructorCall`: `Location(...)`.
2. If an identifier is followed by `.`, it parses as a `SymbolReference('Location', _readParts())`.
3. This is **structurally identical** to `WidgetBuilderArgReference` (which parses `scope.item.title`).
   No complex postfix grammar is required; it directly extends identifier reference parsing.
4. If `Location` is not found, or `Location.meta` lacks the path, it evaluates to `missing` (null)
   via totality.

#### Level 2: Dynamic Reflection Functions (`meta(w: ...)`, `meta(f: ...)`)

When a widget or function name is **dynamic** (e.g. passed in via `args.preferredWidget` or
from an A2UI message payload), static symbol syntax cannot be used. For dynamic lookup,
standard functions are provided:

```rfw
switch meta(w: args.preferredWidget, path: "supported") {
  true: ...,
  default: ...,
}
```

Where `path` is an optional dot-separated key path into the metadata dictionary.

#### Level 3: Semantic Convenience Shorthands (Desugaring)

Shorthands for quintessential parts of the system are valuable ergonomics. They are not
an anti-pattern when they cleanly desugar into metadata lookups:

- **`hasWidget(name: "Foo")`**
  $\equiv$ `notEquals(a: meta(w: "Foo"), b: null)`
- **`hasWidgetArg(widget: "Foo", arg: "bar")`**
  $\equiv$ `equals(a: meta(w: "Foo", path: "args.bar"), b: true)`
- **`hasFunction(name: "foo")`**
  $\equiv$ `notEquals(a: meta(f: "foo"), b: null)`
- **`hasFunctionArg(function: "foo", arg: "bar")`**
  $\equiv$ `notEquals(a: meta(f: "foo", path: "args.bar"), b: null)`
  *(Note: because `LocalFunction` already carries an `arguments` schema in Dart, `hasFunctionArg`
  automatically inspects `LocalFunction.arguments.containsKey(arg)` by default even if `meta` is empty).*

---

### 6.4 Host-Side Template Compilation & Constant Folding

Because metadata is immutable, metadata queries and pure expressions over them are
**compile-time constants** from the perspective of the host app.

When the host loads a template via `runtime.update(name, library)`, the engine can run
an **AST specialization and constant-folding pass** in `package:a2ui_craft` before the
template is ever rendered:

```
Text / Binary (.craft / .rfw)
             │
             ▼
  parseLibraryFile()  ──▶  Raw RemoteWidgetLibrary (generic AST)
             │
             ▼
  runtime.update()    ──▶  [Host Specialization / Constant Folding Pass]
             │
             ▼
 Specialized RemoteWidgetLibrary (dead branches pruned, constants folded)
             │
             ▼
  Runtime.build()     ──▶  Fast, zero-overhead render tree
```

#### How Folding Works:

1. **Pure Static Switches (Dead Branch Pruning):**
   ```rfw
   switch Location.args.latLong {
     true: Location(latLong: args.pos),
     default: LocationFinder(),
   }
   ```
   If `Location.args.latLong` resolves to `true`:
   - The `Switch` node is replaced with `Location(latLong: args.pos)`.
   - The `default` branch is **excised completely from memory**.
2. **Short-Circuiting Hybrid Expressions (Static $\times$ Dynamic):**
   ```rfw
   switch and(a: hasWidget(name: "Location"), b: media.hasGps) {
     true: Location(latLong: args.pos),
     default: LocationFinder(),
   }
   ```
   If `hasWidget("Location")` is `false`:
   - The boolean logic evaluator recognizes `and(false, <dynamic>)` $\rightarrow$ `false`.
   - The `true` branch is **pruned immediately at load time**, without even needing to wait
     for runtime GPS permission!
3. **Algebraic Simplification:**
   If `hasWidget("Location")` is `true`, `and(true, media.hasGps)` simplifies directly
   to `media.hasGps`, leaving only the dynamic check for the render pass.

#### Architectural Benefits of Host Compilation:
- **Zero Loop Overhead:** In repeated lists (`...for item in data.items`), metadata checks
  do not run 1,000 times per frame; the switch was eliminated ahead of time.
- **Excising Unsupported Calls:** Unselected branches containing newer function calls
  are pruned before `_bindArguments` ever visits them, completely bypassing eager debug
  schema validation issues.

---

### 6.5 Beyond Versioning: Rich Metadata Use Cases

The true power of an open metadata system is that it solves problems far beyond version skew:

#### 1. Static Accessibility (A11y) Text Negotiation
A host app can supply standardized, localized accessibility descriptions directly in its
primitives, avoiding bloat in over-the-wire templates:
```dart
'ApplePay': LocalWidget(
  builder: buildApplePay,
  meta: {
    'a11y': {
      'label': 'Double-tap to authorize payment with Apple Pay',
      'hint': 'Requires biometric authentication',
    },
  },
)
```
In template:
```rfw
Text(
  text: ApplePay.a11y.label,
  variant: "caption",
)
```

#### 2. Business Capability Negotiation
A widget can declare what business capabilities it supports:
```dart
'BarcodeScanner': LocalWidget(
  builder: buildScanner,
  meta: {
    'formats': {'qr': true, 'ean13': true, 'upc': true},
    'requiresFlashlight': false,
  },
)
```
In template:
```rfw
switch BarcodeScanner.formats.qr {
  true: QRScannerButton(),
  default: ManualEntryForm(),
}
```

#### 3. Unopinionated Versioning Models
- **Semver:** A host can use `'version': '2.1.0'`, and templates can use comparison functions.
- **Android-style API Level:** A host can use `'apiLevel': 34`, and templates can use
  `greaterThanOrEqual(a: Location.apiLevel, b: 34)`.
- **Feature Flags:** A host can use `'betaFeatures': true`.

---

## 7. The Proposed Architecture: The Unified Two-Pillar Model

```
                                  Feature Detection System
                                             │
                  ┌──────────────────────────┴──────────────────────────┐
                  ▼                                                     ▼
        Pillar 1: Environment                                 Pillar 2: Runtime API & Meta
        (Physical / Ambient)                                  (Software / Symbols / Data)
  ─────────────────────────────────                    ─────────────────────────────────
  • Exposed on `media.` scope                          • Direct Language Member Access:
  • Re-renders on change (immutable snapshot)            - Location.args.latLong
  • Values:                                              - ApplePay.a11y.label
    - media.formFactor                                 • Functional & Dynamic Access:
    - media.platform                                     - meta(w: "...", path: "...")
    - media.capabilities.<feature>                      - meta(f: "...", path: "...")
                                                       • Convenience Shorthands:
                                                         - hasWidget(name: "...")
                                                         - hasWidgetArg(widget: "...", arg: "...")
                                                         - hasFunction(name: "...")
                                                         - hasFunctionArg(function: "...", arg: "...")
                                                       • Host-Side Constant Folding:
                                                         - Excises dead branches at runtime.update()
```

### 7.1 Pillar 1 Specification: Environmental `MediaContext`

Expand `MediaContext` with quantized physical traits and hardware capabilities:

```dart
enum DeviceFormFactor {
  phone('phone'),
  watch('watch'),
  tablet('tablet'),
  desktop('desktop'),
  tv('tv'),
  auto('auto');

  const DeviceFormFactor(this.id);
  final String id;
}

enum HostPlatform {
  ios('ios'),
  android('android'),
  web('web'),
  macos('macos'),
  windows('windows'),
  linux('linux');

  const HostPlatform(this.id);
  final String id;
}
```

In `MediaContext`:
```dart
class MediaContext {
  const MediaContext({
    required this.width,
    this.height = WindowHeightClass.medium,
    this.orientation = ScreenOrientation.portrait,
    this.reducedMotion = false,
    this.formFactor = DeviceFormFactor.phone,
    this.platform = HostPlatform.web,
    this.capabilities = const <String>{},
  });

  final DeviceFormFactor formFactor;
  final HostPlatform platform;
  final Set<String> capabilities; // e.g. {'gps', 'camera', 'biometrics', 'nfc'}

  DynamicContent toContent() => DynamicContent()
    ..updateAll(<String, Object?>{
      'width': width.id,
      'height': height.id,
      'orientation': orientation.id,
      'reducedMotion': reducedMotion,
      'formFactor': formFactor.id,
      'platform': platform.id,
      'hasGps': capabilities.contains('gps'),
      'hasCamera': capabilities.contains('camera'),
      'hasBiometrics': capabilities.contains('biometrics'),
      'hasNfc': capabilities.contains('nfc'),
    });
}
```

### 7.2 Pillar 2 Specification: Runtime API Introspection & Metadata

1. **Direct Symbol Access:**
   `Location.args.latLong` &rarr; traverses the `meta` dictionary of the widget/function.
2. **Dynamic Meta Functions:**
   `meta(w: string?, f: string?, path: string?) -> any` &rarr; dynamic query supporting variable names.
3. **Convenience Shorthands:**
   `hasWidget(name)`, `hasWidgetArg(widget, arg)`, `hasFunction(name)`, `hasFunctionArg(function, arg)`.
4. **App & Protocol Version:**
   `appVersion() -> string`, `runtimeVersion() -> number`.

---

## 8. Concrete Scenarios & Code Examples

### Scenario 1: Phone/Watch GPS vs. Laptop LocationFinder

```rfw
import core;

widget LocationView = switch and(a: hasWidget(name: "Location"), b: media.hasGps) {
  true: Location(
    latLong: args.coordinates,
    zoom: 15,
  ),
  default: LocationFinder(
    initialQuery: args.city,
    onSelect: event "addressSelected" { address: event.value },
  ),
};
```

### Scenario 2: Apple Pay vs. Google Pay vs. Standard Credit Card

```rfw
import core;

widget ExpressCheckout = switch and(a: hasWidget(name: "ApplePay"), b: equals(a: media.platform, b: "ios")) {
  true: ApplePay(
    total: args.amount,
    currency: "USD",
    onComplete: event "paymentSuccess" { token: event.token },
  ),
  default: switch and(a: hasWidget(name: "GooglePay"), b: equals(a: media.platform, b: "android")) {
    true: GooglePay(
      total: args.amount,
      currency: "USD",
      onComplete: event "paymentSuccess" { token: event.token },
    ),
    default: CreditCardForm(
      amount: args.amount,
      onSubmit: event "chargeCard" {},
    ),
  },
};
```

### Scenario 3: Direct Symbol Member Access (`Location.args.latLong`)

```rfw
import core;

widget MapDisplay = switch Location.args.latLong {
  true: Location(latLong: [args.latitude, args.longitude]),
  default: Location(address: args.formattedAddress),
};
```

On an older client where `Location` only knows `address`:
- Host compilation evaluates `Location.args.latLong` to `missing` (null).
- The `switch` constant-folds directly to `Location(address: args.formattedAddress)`.
- The `true` arm is excised before binding; no unknown argument error occurs.

### Scenario 4: Evolving Pure Functions

```rfw
import core;

widget PriceTag = switch hasFunction(name: "formatCurrency") {
  true: Text(text: formatCurrency(value: args.price, currency: "USD")),
  default: Text(text: concat(a: "$", b: args.price)),
};
```

On Host v1:
- `hasFunction("formatCurrency")` constant-folds to `false`.
- The `switch` folds to `concat("$", args.price)`.
- The dead `formatCurrency` branch is eliminated from the AST.

---

## 9. Phased Implementation Roadmap

This design can be delivered incrementally in 5 disciplined phases:

```
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 1: Environmental Capabilities in MediaContext                    │
│ • Add formFactor, platform, capabilities Set to MediaContext           │
│ • Expose media.formFactor, media.platform, media.hasGps, etc.          │
│ • Parity tests on Flutter and Jaspr                                    │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 2: Deferred Function Error Containment & Introspection Helpers   │
│ • Fix _debugValidateFunctionArguments to be error-contained (deferred) │
│ • Implement hasWidget, hasFunction, appVersion, runtimeVersion         │
│ • Conformance tests verifying unselected missing widgets/functions     │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 3: Metadata Dictionaries, Constant Folding & Symbol Access       │
│ • Introduce LocalWidget and LocalFunction immutable metadata maps      │
│ • Implement host-side AST specialization & constant-folding pass       │
│ • Support SymbolReference in text parser (Location.args.latLong)       │
│ • Implement dynamic meta(w: ..., path: ...) function                   │
│ • Parity tests across Flutter and Jaspr                                │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 4: Test & Example Scenario Coverage                              │
│ • Add rich multi-scenario tests (e.g. Scenarios 1–4 from Section 8)    │
│ • Add dedicated sample project(s) demonstrating feature detection      │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 5: Landing Page Section on the Demo Site                         │
│ • Add a Feature Detection section to the landing page                  │
│ • Interactive side-by-side demo showcasing fallback and adaptation     │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 10. Summary & Recommendation

| Requirement | Proposed Solution | Why It Wins |
| :--- | :--- | :--- |
| **Differentiate Form Factors & Sensors (GPS, Camera)** | `MediaContext` (`media.formFactor`, `media.hasGps`, etc.) | Ambient, reactive snapshot model; auto-updates on permission/docking. |
| **Differentiate Client Versions & Missing Primitives** | `hasWidget(name)` or `meta(w: name)` | Zero grammar/binary churn; total; dead code elimination preserved. |
| **Direct First-Class Member Access** | `Location.args.latLong` / `ApplePay.a11y.label` | Idiomatic language expression; zero boilerplate; mirrors constructor calls. |
| **Non-Versioning Host-Template Negotiation** | Arbitrary metadata (a11y strings, business capabilities) | Mechanism over policy; flexible for host app developers. |
| **Zero Runtime Overhead & Dead Branch Pruning** | Host-side AST constant folding in `runtime.update()` | Prunes unselected branches and excises missing features upon loading. |
| **Preserve Host & Template DCE** | String-keyed dictionary queries; no template self-reflection | AOT tree-shaking strips unreferenced Dart code; templates can be minified. |
