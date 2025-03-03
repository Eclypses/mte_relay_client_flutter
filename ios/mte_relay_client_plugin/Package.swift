// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mte_relay_client_plugin",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .library(name: "mte-relay-client-plugin",
                 targets: ["mte_relay_client_plugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/Eclypses/eclypses-aws-mte-relay-client-ios.git", from: "4.0.0")
          ],
    targets: [
        .target(
            name: "mte_relay_client_plugin",
            dependencies: [
                .product(name: "MteRelay", package: "eclypses-aws-mte-relay-client-ios")
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it uses any required
                // reason APIs, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),

                // If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ]
        )
    ]
)
