import Foundation

extension Bundle {
    static let runBarResources: Bundle = {
        let fileManager = FileManager.default
        let bundleName = "RunBar_RunBar.bundle"
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(bundleName)"),
            Bundle.main.bundleURL.appendingPathComponent(bundleName),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent(bundleName),
            URL(fileURLWithPath: ".build/release/\(bundleName)")
        ]

        for candidate in candidates.compactMap({ $0 }) where fileManager.fileExists(atPath: candidate.path) {
            if let bundle = Bundle(path: candidate.path) {
                return bundle
            }
        }

        let searched = candidates.compactMap(\.?.path).joined(separator: " or ")
        fatalError("could not load RunBar resource bundle: from \(searched)")
    }()
}
