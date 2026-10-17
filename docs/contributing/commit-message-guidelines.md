# Commit Message Guidelines

## Table of Contents

1. [Writing commit messages](#writing-commit-messages)
   1. [`{type}` field](#type-field)
   1. [`{scope}` field](#scope-field)
   1. [`{description}` field](#description-field)
   1. [`{body}` field](#body-field)
   1. [`{footer}` field](#footer-field)
1. [Commit footers](#commit-footers)
   1. [`BREAKING CHANGE` footer](#breaking-change-footer)
   1. [`GitHub footers](#github-footers)
   1. [`Co-authored-by`](#co-authored-by)
   1. [`Reviewed-by`](#reviewed-by)
   1. [`Signed-off-by`](#signed-off-by)
   1. [`See also`](#see-also)
1. [Formatting rules](#formatting-rules)

## Writing commit messages

Commit guidelines are intended to make the Git history readable, understandable,
and usable by both human developers and automated tools. Naked Standup has
adopted the [Conventional Commits specification](https://www.conventionalcommits.org/en/v1.0.0/#specification)
for documenting changes to the source code in the Git repository. Commit
messages are structured as follows:

```plain
{type}[{scope}][!]: {description}

[{body}]

[{footer}...]
```

(The `[]` brackets are used to indicate optional fields in the commit message.
The ellipses (`...`) in the footer is intended to indicate that multiple headers
can be specified.)

## `{type}` field

The `{type}` field is used to indicate the intent or purpose of the commit. The
`{type}` field can be one of the following values:

| `{type}` | Description |
| -------- | ----------- |
| `build` | The commit changes the build system or adds or updates dependencies. |
| `chore` | The commit performs other maintenance changes that do not modify source or test files. |
| `ci` | The commit changes the automated build and deployment (CI/CD) for the product. |
| `docs` | The commit changes or adds documentation. |
| `feat`   | Introduces a new feature. Adding a new feature typically results in an increment of the **MINOR** version number. |
| `fix` | Fixed a bug. A bug fix typically results in an increment of the **PATCH** version number. |
| `perf` | The commit improves the performance of the software. |
| `refactor` | The commit refactors existing code, but does not change any functionality or behavior. |
| `style`| The commit updated or fixed the code style (formatting changes), but did not change or introduce any behavior or features. |
| `test` | The commit adds or removes automated tests. |

## `{scope}` field

The `{scope}` field is optional and provides additional context about the area
of the codebase that was affected by the commit.

Naked Standup does not currently define and `{scope}` values and this field
should not be used in commits.

## `{description}` field

The `{description}` field is a human-readable title for the commit. The
`{description}` field should be written imperatively (e.g. "create a class",
"add an event handler"). The `{description}` should start with a lowercase
letter (e.g. "create a class" instead of "Create a class").

## `{body}` field

The `{body}` field is a human-readable description of the change. The `{body}`
text should be written declaratively and should explain what was changed and
why the change was needed. The `{body}` test should avoid describing how the
change was made. That information can be gathered by looking at the change in
the source code.

The `{body}` field can include multiple paragraphs, separated by a blank line.

## `{footer}` field

`{footer}` fields are optional and can be used to attach metadata to the commit
message. The metadata could be used either by automated tools or read by humans
to better understand the commit. A commit message can have multiple footers.

Footers have the following syntax:

```plain
{footer}: {value}
```

## Commit footers

### BREAKING CHANGE footer

The `BREAKING CHANGE` footer indicates that the commit introduces changes that
break compatibility with previous versions of the software. A breaking change
will often require changes to other software products that may integrate with
Naked Standup, or will require a change in how the user interacts with the
product.

Breaking changes can be documented either by adding the `BREAKING CHANGE` footer
to the commit or by adding the optional `!` to the header line following the
`{type}` and optional `{scope}` fields. The advantage of using the
`BREAKING CHANGE` field is that the value can be a description of what the
breaking change is and why it needed to be implemented.

Breaking changes require an increment of the **MAJOR** version number for the
product.

### GitHub footers

[GitHub](https://github.com) supports footer keywords that
[link a commit to a pull request or project issue](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue).
The following footer keywords are supported:

- `close`
- `closed`
- `closes`
- `fix`
- `fixed`
- `fixes`
- `resolve`
- `resolved`
- `resolves`

Keywords are case insensitive. Keywords can be specified either as all lowercase
or all uppercase.

For example, to link the commit to issue #10 that the commit fixes, add the
following footer:

```plain
CLOSES: #10
```

### `Co-authored-by`

The `Co-authored-by` footer is used to reference additional contributors to
your commit. The `Co-authored-by` footer can be specified multiple time, and
each instance should reference a single contributor. The format of the
`Co-authored-by` footer should follow this:

```plain
Co-authored-by: {full name} <{email}>
```

For example:

```plain
Co-authored-by: Michael Collins <mfcollins3@me.com>
```

### `Reviewed-by`

The `Reviewed-by` footer is used to acknowledge reviewers who reviewed, provided
feedback on, and approved the commit. The value of the `Reviewed-by` footer is
that it documents the approvers in the commit message, making it easier for
readers who are reviewing the Git log. Reviewers do not need to review the
pull request in GitHub to see who reviewed and approved the pull request.
The format of the `Reviewed-by` footer should reference the name and email of
the contributor:

```plain
Reviewed-by: {full name} <{email}>
```

### `Signed-off-by`

The `Signed-off-by` footer is used as a
[Developer Certificate of Origin](https://en.wikipedia.org/wiki/Developer_Certificate_of_Origin)
and is used as a statement of authenticity by the author of the commit. The
`Signed-off-by` footer is a statement by the developer that they created the
work and have the legal right to contribute its changes to the product. The
`Signed-off-by` footer has the following format:

```plain
Signed-off-by: {full name} <{email}>
```

[Git](https://git-scm.com) can add this footer to commits when using the
`git commit` command with the `-s` or `--signoff` flag on the command line.

### `See also`

The `See also` footer is used as a reference to a GitHub issue, PR, or website
or web page related to the commit. To reference a GitHub issue or PR, add a
footer like this:

```plain
See also: #10
```

To reference a website or web page, create a footer like this:

```plain
See also: https://www.geeksforgeeks.org/dsa/introduction-to-log-structured-merge-lsm-tree/
```

## Formatting rules

Commit messages should follow these formatting rules for readability across all
tools or environments:

- The first or header line of the commit message containing the `{type}`,
  optional `{scope}` and `{description}` fields must be a maximum length of 52
  characters and must be a single line.
- The lines of the `{body}` field should be 72 characters or less and should
  wrap to the next line on word or hyphen boundaries. Lines containing long
  symbol names or URLs may extend past the 72-character boundary, but should
  be the only content on the line.
