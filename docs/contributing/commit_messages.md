# Writing Commit Messages

Naked Standup's commit log is an important artifact in the success of the
product. It is a living history that captures every change made to the product
and the evolutionary and technical decisions behind those changes, including
why they were made.

Naked Standup has adopted the
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
specification for writing commit messages for the repository's commit log.
Conventional Commits defines a standard layout that makes commit messages
usable by human developers and stakeholders, AI tools, and other automation
tools that use the commit log to manage the product.

## Commit Message Format

Commit messages for Naked Standup have the following form:

```plain
{type}[({scope})][!]: {description}

[{body}]

{footer}*
```

The square brackets indicate that the wrapped fields are optional and the `*`
after the `{footer}` field indicates that multiple `{footer}` fields can be
appended to the commit message.

## `{type}` field

The `{type}` field is used to communicate the intent or purpose of the commit.
The `{type}` field describes the nature of the changes in the commit and uses
one of the following values:

| `{type}` | Description |
| -------- | ----------- |
| `build` | The commit updates the build system or adds, updates, or removes external dependencies from the product. |
| `chore` | The commit is the result of a maintenance task that did not affect the product's behavior or functionality. |
| `ci` | The commit makes changes to the CI/CD workflows that automate building and releasing the product. |
| `docs` | The commit adds, updates, or removes technical documentation from the repository. |
| `feat` | The commit introduces a new user-visible feature. The `MINOR` version number is typically incremented when new features are introduced. |
| `fix` | The commit fixes a defect in the software, but does not add or remove any features. The `PATCH` version number is typically incremented when bug fixes are released. |
| `perf` | The commit improves the performance of the product. |
| `refactor` | The commit refactors the structure of the source code, but does not change the behavior or functionality of the product. |
| `revert` | The commit reverts a previous commit. |
| `style` | The commit changes or updates the formatting of source code, but does not change the behavior or functionality of the product. |
| `test` | The commit adds, updates, or removes automated tests. |

## `{scope}` field

The optional `{scope}` field conveys which component or subsystem of the Naked
Standup product was modified by the commit. No valid `{scope}` values are
currently defined, so omit this field from commit messages.

## `{description}` field

The `{description}` field is a short title or description that conveys the main
point of the commit. The `{description}` field should be written in an
imperative style (e.g., "create a class" instead of "created a class"). The
`{description}` field should start with a lowercase letter, but names or
abbreviations can use capital letters.

## `{body}` field

The `{body}` field is optional and is a human and AI-readable description of
the change. The `{body}` field should be written in a declarative style using
one or more sentences and paragraphs. The `{body}` content should describe what
change was made and why, but not necessarily how. Readers interested in the
full details of the change can look at the diff for the commit.

## `{footer}` field

A commit message can have one or more `{footer}` fields at the end of the commit
message. `{footer}` fields convey metadata about the commit or can be used to
link the commit to issues, pull requests, or reviewers who approved the commit.

The `{footer}` field has the following syntax:

```plain
{key}: {value}
```

### `BREAKING CHANGE` footer

A `BREAKING CHANGE` footer or the `!` symbol specified after the `{type}` and
`{scope}` field (if present) indicates that the commit introduces a breaking
change that is incompatible with previous releases of the product. For APIs,
this could mean compatibility changes that require code changes by the
integrating product.

The value for a `BREAKING CHANGE` footer is a description of the breaking change
that was made. This can be a short summary with a more precise description in
the `{body}` field.

A `BREAKING CHANGE` requires a `MAJOR` version number increment in the product.

### Issue and pull request footers

The following footers can be used to link the commit to a pull request or issue
that the commit closes or resolves:

* `Close`
* `Closed`
* `Closes`
* `Fix`
* `Fixed`
* `Fixes`
* `Resolve`
* `Resolved`
* `Resolves`

The value of the footer is a reference to the issue or pull request. For
example, a reference to a GitHub Issue that the commit fixes may appear in the
commit message as:

```plain
Fixes: #10
```

### `Related` and `References` footers

The `Related` and `References` footers link the commit to an issue or pull
request that it affects, but do not necessarily close it.

### `Co-authored-by` footer

The `Co-authored-by` footer credits multiple authors for a commit. Its value
should use Git user syntax:
`{name} <{email}>`.

For example:

```plain
Co-authored-by: Michael Collins <mfcollins3@me.com>
```

### `Reviewed-by` footer

The `Reviewed-by` footer acknowledges the person who reviewed and approved the
pull request. Its value should use Git user syntax, for example:

```plain
Reviewed-by: Michael Collins <mfcollins3@me.com>
```

### `Signed-off-by` footer

The `Signed-off-by` footer is used to indicate the original author of the
changes made in the commit and to verify that the author has the legal right to
contribute the changes to the product (e.g., meet licensing requirements,
ensure the changes have been scanned and formatted properly, and follow all
other rules).

The value of the footer should be in Git user syntax:

```plain
Signed-off-by: Michael Collins <mfcollins3@me.com>
```

### `See also` footer

The `See also` footer is used to reference websites, issues, or pull requests
that are related to or relevant for the commit.

For example:

```plain
See also: #10
See also: https://dev.to/mochafreddo/a-comprehensive-guide-to-using-footers-in-conventional-commit-messages-37g6
```

## Formatting commit messages

* The header (or first) line of the commit message containing the `{type}`,
  `{scope}`, and `{description}` fields should be no longer than 52 characters
  in length.
* Keep each line of the `{body}` field to 72 characters or fewer, wrapping
  longer lines.
  * URLs or long symbol names may extend past the 72-character limit.
  * If possible, break long symbol names across lines.
