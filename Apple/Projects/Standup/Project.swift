// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms

import ProjectDescription

func standupApp() -> Target {
    .target(
        name: "Standup",
        destinations: [.iPad, .iPhone],
        product: .app,
        bundleId: "dev.michaelfcollins3.standup",
        deploymentTargets: .iOS("26.0"),
        infoPlist: .extendingDefault(with: [
            "UILaunchScreen": [:],
            "NSCameraUsageDescription": "Naked Standup uses your camera to record status videos.",
            "NSMicrophoneUsageDescription": "Naked Standup uses your microphone to record audio for your status videos."
        ]),
        sources: ["Sources/**"],
        resources: .resources(
            [
                "Resources/**"
            ],
            privacyManifest: .privacyManifest(
                tracking: false,
                trackingDomains: [],
                collectedDataTypes: [
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeName",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAppFunctionality"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeEmailAddress",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAppFunctionality"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeCoarseLocation",
                        "NSPrivacyCollectedDataTypeLinked": false,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAppFunctionality"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeCustomerSupport",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAppFunctionality"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeOtherUserContent",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAppFunctionality"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeUserID",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeProductPersonalization",
                            "NSPrivacyCollectedDataTypePurposeAppFunctionality"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeDeviceID",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAppFunctionality"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeProductInteraction",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAnalytics"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeOtherUsageData",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAnalytics"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeCrashData",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAppFunctionality"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypePerformanceData",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAppFunctionality"
                        ]
                    ],
                    [
                        "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeOtherDiagnosticData",
                        "NSPrivacyCollectedDataTypeLinked": true,
                        "NSPrivacyCollectedDataTypeTracking": false,
                        "NSPrivacyCollectedDataTypePurposes": [
                            "NSPrivacyCollectedDataTypePurposeAppFunctionality",
                            "NSPrivacyCollectedDataTypePurposeOther"
                        ]
                    ]
                ],
                accessedApiTypes: [
                    [
                        "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
                        "NSPrivacyAccessedAPITypeReasons": [
                            "CA92.1",
                            "1C8F.1"
                        ]
                    ]
                ]
            )
        ),
        settings: .settings(
            base: .init()
                .appleGenericVersioningSystem()
                .automaticCodeSigning(devTeam: "WTG7RTG947")
                .currentProjectVersion("1")
                .marketingVersion("0.0.1")
                .swiftVersion("6.2"),
            configurations: [
                .debug(
                    name: .debug,
                    settings: .init(),
                    xcconfig: .relativeToManifest("Config/Debug.xcconfig")
                ),
                .release(
                    name: "QA",
                    settings: .init(),
                    xcconfig: .relativeToManifest("Config/QA.xcconfig")
                ),
                .release(
                    name: .release,
                    settings: .init(),
                    xcconfig: .relativeToManifest("Config/Release.xcconfig")
                )
            ]
        ),
        additionalFiles: [
            "Config/Base.xcconfig"
        ]
    )

}
func standupTests() -> Target {
	.target(
		name: "StandupTests",
		destinations: [.iPad, .iPhone],
		product: .unitTests,
		bundleId: "dev.michaelfcollins3.standup.tests",
		deploymentTargets: .iOS("26.0"),
		sources: ["Tests/**"],
		dependencies: [
			.target(name: "Standup")
		],
		settings: .settings(
			base: .init()
				.automaticCodeSigning(devTeam: "WTG7RTG947")
				.swiftVersion("6.2"),
			configurations: [
				.debug(
					name: .debug,
					settings: .init(),
					xcconfig: .relativeToManifest("Config/Debug.xcconfig")
				),
				.release(
					name: "QA",
					settings: .init(),
					xcconfig: .relativeToManifest("Config/QA.xcconfig")
				),
				.release(
					name: .release,
					settings: .init(),
					xcconfig: .relativeToManifest("Config/Release.xcconfig")
				)
			]
		)
	)
}

let project = Project(
    name: "Standup",
    organizationName: "Michael Collins",
    options: .options(
        developmentRegion: "en-US",
        textSettings: .textSettings(
            usesTabs: true,
            indentWidth: 4,
            tabWidth: 4,
            wrapsLines: true
        )
    ),
    targets: [
		standupApp(),
		standupTests()
	]
)
