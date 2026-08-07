# Create Method Code Action Design

## Goal

Make `<leader>cm` apply Dart LSP's `Create method 'fromMap'` action when the
cursor is on an unresolved static member invocation such as
`SwaggerParameter.fromMap(parameter)`.

## Behavior

`forge.actions.create_method` will select only code actions whose title matches
`Create method '…'`, case-insensitively. The quoted name may contain any
non-quote characters, allowing the action to create methods with arbitrary
identifiers.

The matching action is requested and applied at the current cursor position.
Consequently, Dart Analysis Server determines the owning type and creates
`fromMap` on `SwaggerParameter`.

If no matching action exists:

- inside a class, Forge inserts its existing language-specific method snippet;
- outside a class, Forge opens the normal filtered LSP code-action picker.

## Scope

Only the create-method filter changes. Existing keymaps, LSP request handling,
code-action application, and snippet insertion remain unchanged.

## Tests

Add focused tests for the title filter:

- accepts `Create method 'fromMap'`;
- accepts case variations;
- rejects `Create function 'fromMap'`, `Create class 'SwaggerParameter'`,
  `Implement members`, and other broad create actions.
