// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CommissieWijzer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CommissieWijzer", targets: ["CommissieWijzer"])],
    targets: [
        .target(name: "CommissieCore"),
        .target(name: "SnowballDutch", path: "Sources/NativeSearchSupport/SnowballDutch", publicHeadersPath: "include",
                cSettings: [.headerSearchPath("runtime"), .headerSearchPath("src_c")]),
        .target(name: "RapidFuzzNative", path: "Sources/NativeSearchSupport/RapidFuzz", publicHeadersPath: "include",
                cxxSettings: [.headerSearchPath("vendor")]),
        .executableTarget(name: "CommissieWijzer", dependencies: ["CommissieCore", "SnowballDutch", "RapidFuzzNative"]),
        .testTarget(name: "CommissieCoreTests", dependencies: ["CommissieCore"]),
        .testTarget(name: "CommissieAppTests", dependencies: ["CommissieWijzer", "CommissieCore"])
    ],
    cxxLanguageStandard: .cxx17
)
