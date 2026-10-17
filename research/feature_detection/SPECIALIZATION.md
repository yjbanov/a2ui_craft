# Load-time specialization — open design questions

> **Status: open (2026-10-16).** The load-time specialization pass
> (`specializeLibrary` in `packages/a2ui_craft/lib/src/specialization.dart`)
> was built as part of the feature-detection work
> ([FEATURE_DETECTION_DESIGN.md](FEATURE_DETECTION_DESIGN.md) §6.4) and has
> since needed a run of point fixes. They worked, but they showed that the pass
> was added in passing rather than designed. This note records what we found so
> specialization can be taken up as its own focused effort. It is not a plan
> yet.

## 1. What the pass does today

When a remote library is loaded (`Runtime.update`), or when anything it depends
on changes (local libraries, registered functions, `appVersion`), both adapters
re-run `specializeLibrary` over the original ("raw") remote libraries. The pass:

- resolves static symbol references (`Location.args.latLong`,
  `Foo.meta.label`) against host widget and function metadata;
- evaluates the introspection functions (`hasWidget`, `hasWidgetArg`,
  `hasFunction`, `hasFunctionArg`, `hasArg`, `meta`, `runtimeVersion`,
  `appVersion`) when their arguments are constants;
- applies boolean identities to `and`/`or`, and folds `equals`/`notEquals`
  with constant operands;
- calls any other registered function whose arguments are all constants, and
  substitutes the result;
- replaces a `Switch` whose input became a constant with the selected branch.

The intent in FEATURE_DETECTION_DESIGN.md §6.4 is two-fold: performance
("zero-overhead render tree") and safety (dead branches holding unsupported
widgets or functions are removed before binding, described there as a
"complete structural defense").

## 2. The framing question: optimization or correctness mechanism?

This should be settled first, because most of what follows depends on it.

Since the pass was written, the runtime has gained its own safety net. It is
easy to misdescribe, so precisely: `_bindArguments` binds **every** branch of a
`Switch` up front (`node.outputs.map(...)` in both adapters' `runtime.dart`).
Only the selected branch is then **resolved and built**
(`_CurriedWidget._resolveFrom`, `_CurriedSwitch.buildChild`). Unselected
branches are safe because binding never throws:

- a missing widget binds to an error placeholder (`_CurriedLocalWidget.error`);
- an unknown function falls through to the same placeholder;
- a registered function with bad arguments binds to a `_FunctionCall` that
  carries its validation error, which only throws if that call is evaluated.

So the safety net rests on **binding being non-throwing for every node kind**,
not on binding being lazy. That property is what makes the optimization
framing possible, and it should be pinned by a test of its own.

If it holds, specialization is **not needed for correctness**: it is an
optimization, and it must be **semantics-preserving**. Any template whose
behavior differs with the pass on versus off is a bug in the pass.

The current docs still say otherwise. DESIGN.md §14 and
FEATURE_DETECTION_DESIGN.md §3.4 present the pass as the defense. If we accept
the optimization framing, those docs should say the runtime is the defense and
the pass is a speed-up.

The performance benefit has also never been measured. Before investing
further, it is worth knowing what the pass actually buys: fewer bindings,
fewer function calls per rebuild, smaller trees.

## 3. Intrinsified functions are matched by name

The pass rewrites `and`, `or`, `equals` and `notEquals` based only on their
**names**. Nothing guarantees that the registered function with that name is
the core one:

- The core functions are opt-in. A host registers them with
  `registerFunctions(createCoreFunctions())`.
- `registerFunctions` is a plain `addAll`, so a host can register its own
  `and` with different semantics: truthy instead of strict, variadic, logging.
- The guard in `specializeNode` only checks that *some* function with that name
  is registered (`functions.containsKey(node.name)`), then applies the core
  semantics regardless. With a custom `and`, `and(a: false, b: x)` still
  becomes `false` at load time.

Not every rewrite needs to know what a function means:

- **Calling a function whose arguments are all constants is sound for any
  registered function**, because `LocalFunction` is pure by contract. That is
  the generic path (`fn.implementation(args)`).
- **The `equals`/`notEquals` branches, and the both-operands-bool cases of
  `and`/`or`, add nothing.** The generic path gives the same result for the
  core functions and the correct result for custom ones.
- **Only the half-constant identities need knowledge of the function**:
  `and(false, x) → false`, `and(true, x) → x`, and the `or` duals. These are
  what make "prune the `Location` branch even when GPS is present" work.

The introspection functions have a related problem. They belong to the engine,
and the runtime registers them in its constructor. But:

- `registerFunctions` can overwrite them afterwards.
- A later `appVersion` change re-registers them (`_initIntrospectionFunctions`)
  and silently undoes the host's override.
- The pass has its own copy of their logic in `specialization.dart`, and folds
  them even when they are not in `functions`. The copies can drift, and they
  already have, in small ways:
  - `hasWidgetArg` treats an arg whose metadata is `false` as absent;
    `hasFunctionArg` does not.
  - For `meta(f: …, path: "args.…")`, the pass (and symbol lookup) only treats
    the path as an argument check when it is exactly `args.<name>`. The
    runtime's `_getMeta` accepts any path starting with `args.` and checks the
    rest as one argument name. They disagree only for names containing a dot,
    so the effect is negligible, but it is the same kind of drift.

### Options

1. **Fold by identity, not name.** Make the core `and`/`or` single shared
   `LocalFunction` instances (today `_binaryBoolean` builds a new one on every
   `createCoreFunctions()` call), and apply the identities only when
   `identical(functions['and'], coreAnd)`. Small change. Custom overrides are
   simply not simplified.
2. **Move the simplification rule onto the function.** Add an optional hook to
   `LocalFunction`, for example `simplify(args)`, which returns a replacement
   node or "no rewrite". The pass calls whatever is registered. The identities
   live next to their implementation, custom functions can opt in, and the pass
   stops matching names.
3. **Reserve names.** Make the introspection functions non-overridable, by
   registering them last or rejecting them in `registerFunctions`, and have the
   pass and the runtime share one implementation of each. This fits the
   engine-owned introspection set. It is too restrictive for `and`/`or`, which
   are ordinary library functions.

Leaning: 2 for library functions, 3 for introspection, and delete the
redundant named branches either way.

## 4. Other weaknesses found so far

Found during the review of the feature-detection branch (2026-10-09 →
2026-10-11). Items marked *patched* have interim fixes on that branch. The
rest are open.

**Node kinds after folding.** The pass assumed a folded child keeps a usable
kind, and it does not.
- *Patched:* a widget declaration's root, and a builder body, fall back to the
  original node unless the result is a `ConstructorCall` or `Switch`.
- *Patched:* a `set state` value and a loop's input or output fall back to the
  original node when they fold to `null`.
- These are four separate guards for one rule ("a fold must yield a node that
  is valid in this position"). The pass should state per-position rules once,
  instead of discovering them crash by crash.
- The root fallback keeps the **unspecialized** root, which also throws away
  any useful specialization inside it.

**No single representation for "absent".** The parser and the pass disagree on
how an absent value appears in the tree:
- The parser uses `missing` (a `BlobNode`), and drops map keys whose value is
  `missing` (`text.dart`, `_readMapBody`). It never puts Dart `null` into a map
  or list.
- The pass returns Dart `null` when a symbol reference, `meta()`, or a
  function folds to nothing, and writes that `null` straight into maps and
  lists. Inside a loop body this crashes at render time: `_bindLoopVariable`
  does `value!` on map entries and `node[index]!` on list entries. The interim
  `?? node.output` patch covers a loop's output as a whole, not `null` nested
  inside it.
- The pass returns `missing` when a `Switch` with no `default` matches nothing.
  Because `missing` is a `BlobNode`, the "is this a constant?" checks
  (`is! BlobNode`) treat it as a dynamic value, so enclosing expressions are not
  folded. That is a missed optimization rather than a wrong result.
- Neither form can be re-encoded: the binary encoder throws on `null` and
  asserts against `missing`. Specialized output is never re-encoded today, so
  this only matters if it is ever cached in binary form.

**Boolean folding differs from the runtime.**
- *Patched:* a constant non-bool operand now folds `and`/`or` to `null`,
  matching the runtime.
- Still open: the identities apply when the other operand is a value only known
  at render time. If that value turns out not to be a bool,
  `and(false, data.x)` folds to `false` while the runtime gives `null`. This
  is accepted today and tested as intended. It should be an explicit decision.

**Widget-vs-function precedence.**
- *Patched:* remote widget names now stop a same-named call from being folded
  as a function (`remoteWidgets`).
- Still open: loading a new remote library does not re-run the pass over
  libraries already loaded, so an earlier library can still have a call folded
  that the new library's widget should shadow. The runtime's actual rule is
  per-scope (the call's library and its imports); the pass uses every remote
  widget name it knows, which is conservative but not the same rule.

**Generic folding skips argument validation.** An all-constant call with an
unknown argument, or a missing required one, is folded to whatever the
implementation returns. In debug mode the runtime would report a validation
error for the same call. So the pass hides authoring mistakes.

**`Switch` pruning.**
- Branches whose value folds to `null` are dropped, so that branch silently
  falls through to `default`. The runtime would have returned `null`.
- If a branch *key* is not a constant, matching a constant input against the
  constant keys can wrongly pick `default`.
- Keys are matched with Dart `==` (`containsKey`), so `Map`/`List` inputs
  match by identity, not by value.
- `Switch.outputs` uses the `null` key for `default`. A case key that folds to
  `null` (for example `Foo.meta.bar` with no such metadata) silently becomes
  the `default` branch, or overwrites the existing one. Unlikely, since keys
  are almost always literals, but wrong when it happens.

**Metadata values put into the tree.** `meta(...)` and symbol references
substitute the host's metadata values directly into the template tree. Those
are arbitrary `Object?`s, and possibly the host's own mutable maps. Nothing
checks that they are valid template values, or that they can be encoded in the
binary format, or copies them.

**`hasWidget` can differ from the runtime.** The pass answers from
`knownWidgets ∪ widgetMetadata.keys`. The runtime's `_hasWidget` answers from
local widget libraries only. They differ if metadata is registered for a name
that has no widget.

## 5. How to verify it

The tests so far check the *shape* of the folded tree, one case at a time. What
would catch this whole class of bug is **differential testing**: render every
conformance and sample template with the pass on and with it off, and require
identical output, including after changes to data, media, and `appVersion`.
That makes "semantics-preserving" something we can check rather than assume,
and it needs to run against both adapters.

A switch to turn specialization off in `Runtime` would also help debugging, and
it is how the "is it worth it" measurement in §2 would be taken.

Separately, the property the optimization framing rests on (§2: binding never
throws, for any node kind, in any branch) deserves its own test: bind templates
whose unselected branches hold every kind of unsupported construct, with
specialization off, and require no exception.

## 6. The structural fix: one evaluator in the core

Most of the drift in §3 and §4 has one cause: there are **three** copies of
expression semantics. Each adapter's `runtime.dart` evaluates functions,
introspection, and symbol lookups, and the pass re-implements them to fold at
load time. The conformance suite holds the adapters together, but nothing holds
the pass to them.

[ROADMAP.md](../../ROADMAP.md) already flags moving evaluation into
`package:a2ui_craft` as a likely prerequisite for blocks and user-defined
functions ("Template computation"). If that happens, the pass and the runtime
can share function dispatch, argument validation, symbol lookup, and the
introspection functions. Folding then means running the shared evaluator on
constant inputs, which removes most of the drift by construction, along with
the need to keep matching behavior by hand.

That makes the two threads one decision: the specialization rework should
either follow the move into the core, or be done as its first slice.

## 7. Proposed scope for the dedicated effort

1. Decide the framing (§2) and update DESIGN.md §14 and
   FEATURE_DETECTION_DESIGN.md §3.4/§6.4 to match.
2. Measure what the pass buys. If it is little, consider shrinking it to the
   rewrites that pay for themselves.
3. Add the specialization-off switch, the binding-never-throws test, and the
   differential tests (§5) before changing the pass further.
4. Decide the ordering against moving evaluation into the core (§6). If that
   comes first, items 5 and 6 largely become "use the shared evaluator".
5. Replace name-matched intrinsics (§3) and fix the introspection override
   problem.
6. Write down one representation for "absent" and the per-position rules for
   what a fold may produce, then fix the remaining items in §4 against them.
