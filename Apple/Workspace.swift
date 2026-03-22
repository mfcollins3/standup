// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms

import ProjectDescription

let workspace = Workspace(
    name: "Standup",
    projects: [
        "Projects/**"
    ],
    fileHeaderTemplate: """
        // Copyright 2026 Michael F. Collins, III
        // Licensed under the Naked Standup Source-Available Temporary License
        // See LICENSE.md for license terms
        """,
    additionalFiles: [
        "README.md",
        "LICENSE.md"
    ],
    generationOptions: .options(renderMarkdownReadme: true)
)
