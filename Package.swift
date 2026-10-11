// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "LiftLogCore", platforms: [.iOS(.v17), .macOS(.v14)], products: [.library(name: "LiftLogCore", targets: ["LiftLogCore"])], targets: [.target(name: "LiftLogCore"), .testTarget(name: "LiftLogCoreTests", dependencies: ["LiftLogCore"])])
