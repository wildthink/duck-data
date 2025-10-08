// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DuckData",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(
            name: "DuckData",
            targets: ["DuckData"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/duckdb/duckdb-swift",
            .upToNextMajor(from: .init(1, 0, 0))),
        .package(
            url: "https://github.com/pointfreeco/swift-structured-queries",
            from: "0.22.1"),
    ],
    targets: [
        .target(
            name: "DuckData",
            dependencies: [
                .product(name: "DuckDB", package: "duckdb-swift"),
                .product(name: "StructuredQueriesSQLite", package: "swift-structured-queries"),
            ]
        ),
        .testTarget(
            name: "DuckDataTests",
            dependencies: ["DuckData"]
        ),
    ]
)
