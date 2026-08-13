// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A driver-backed capability a mini-app exposes to an agent.
///
/// The expressive step past exposing templates: an agent that can invoke
/// `checkout` is better off than one that can only compose a checkout-looking
/// screen. How the action is implemented is the driver's business and invisible
/// to the agent.
final class InferenceAction {
  /// Declares an action named [name].
  const InferenceAction({
    required this.name,
    required this.description,
    this.parameters = const <String, Object?>{},
  });

  /// Parses one entry of a schema document's `actions` list.
  factory InferenceAction.fromJson(Map<String, Object?> json) {
    final Object? name = json['name'];
    if (name is! String) {
      throw ArgumentError("An action entry needs a string 'name'.");
    }
    final Object? description = json['description'];
    if (description is! String) {
      throw ArgumentError(
        "Action '$name' needs a 'description' — it is what an agent reads to "
        'decide whether to invoke it.',
      );
    }
    final Object? parameters = json['parameters'];
    return InferenceAction(
      name: name,
      description: description,
      parameters: parameters is Map
          ? Map<String, Object?>.from(parameters)
          : const <String, Object?>{},
    );
  }

  /// The event name the driver answers.
  final String name;

  /// What the action does, in the agent's terms.
  final String description;

  /// JSON Schema for the action's arguments; empty when it takes none.
  final Map<String, Object?> parameters;

  /// Encodes this entry back into its schema-document form.
  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'description': description,
        if (parameters.isNotEmpty) 'parameters': parameters,
      };
}

/// The agent-facing vocabulary a mini-app chooses to expose: a subset of its
/// templates, plus the actions its driver implements.
///
/// Deliberately **static** — declared in the project's `schema.json`, fixed for
/// the session — which is what makes it verifiable before anything runs. The
/// host app author can check the whole agent-facing surface against platform
/// rules at load time ([actionsOutside]); the mini-app author can check that the
/// driver implements every declared action and nothing undeclared
/// ([unimplementedActions], [undeclaredActions]); and the agent gets a
/// vocabulary that can be baked into a prompt once, with no mid-session churn.
///
/// A project with no driver degenerates to exactly the previous model: the
/// inference catalog is its templates.
final class InferenceCatalog {
  /// Creates a catalog exposing [components] and [actions].
  const InferenceCatalog({
    required this.catalogId,
    this.components = const <String>[],
    this.actions = const <InferenceAction>[],
  });

  /// Parses a project's schema document.
  ///
  /// Reads the same file the component catalog is parsed from, and only the
  /// keys it owns — a document with no `actions` list is a valid catalog with
  /// no actions.
  factory InferenceCatalog.parse(Map<String, Object?> json) {
    final Object? id = json['catalogId'];
    if (id is! String) {
      throw ArgumentError("A schema document needs a string 'catalogId'.");
    }
    final Object? components = json['components'];
    final Object? actions = json['actions'];
    if (actions != null && actions is! List) {
      throw ArgumentError("'actions' must be a list of action entries.");
    }
    final List<InferenceAction> parsed = <InferenceAction>[
      for (final Object? entry
          in (actions as List<Object?>?) ?? const <Object?>[])
        if (entry is Map)
          InferenceAction.fromJson(Map<String, Object?>.from(entry))
        else
          throw ArgumentError('Each action entry must be an object.'),
    ];
    final Set<String> seen = <String>{};
    for (final InferenceAction action in parsed) {
      if (!seen.add(action.name)) {
        throw ArgumentError("Duplicate action '${action.name}'.");
      }
    }
    return InferenceCatalog(
      catalogId: id,
      components: <String>[
        if (components is Map)
          for (final Object? key in components.keys) key.toString(),
      ],
      actions: parsed,
    );
  }

  /// The catalog this document describes.
  final String catalogId;

  /// The template names exposed to inference.
  final List<String> components;

  /// The driver-backed actions exposed to inference.
  final List<InferenceAction> actions;

  /// The declared action names.
  Set<String> get actionNames =>
      <String>{for (final InferenceAction a in actions) a.name};

  /// Declared actions that [implemented] does not cover.
  ///
  /// The mini-app author's check: an agent told it can `checkout` and then met
  /// with silence is worse off than one never told at all.
  List<String> unimplementedActions(Set<String> implemented) =>
      (actionNames.difference(implemented).toList())..sort();

  /// Implemented actions the catalog does not declare.
  ///
  /// Not an error by itself — a driver's internal events are its own business —
  /// but worth surfacing when [implemented] is meant to be exactly the
  /// agent-facing surface.
  List<String> undeclaredActions(Set<String> implemented) =>
      (implemented.difference(actionNames).toList())..sort();

  /// Declared actions outside the host's [allowed] set.
  ///
  /// The host app author's check, run at load time: nothing appears
  /// mid-session that was not vetted, because nothing *can* appear
  /// mid-session.
  List<String> actionsOutside(Set<String> allowed) =>
      (actionNames.difference(allowed).toList())..sort();

  /// Encodes the agent-facing portion of a schema document.
  Map<String, Object?> toJson() => <String, Object?>{
        'catalogId': catalogId,
        if (actions.isNotEmpty)
          'actions': <Object?>[
            for (final InferenceAction a in actions) a.toJson(),
          ],
      };
}
