import Foundation

/// Turns user-facing names into safe, unique file and directory names.
enum FileNaming {
    static let maxLength = 80

    /// Removes characters that are not allowed (or are awkward) in file names.
    static func sanitized(_ name: String, fallback: String) -> String {
        var result = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A leading dot would make the file hidden.
        while result.hasPrefix(".") {
            result.removeFirst()
        }
        if result.count > maxLength {
            result = String(result.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        }
        return result.isEmpty ? fallback : result
    }

    /// Returns `base` (plus extension) or `base 2`, `base 3`, … so that the
    /// name does not clash with an existing item in `directory` or with
    /// `reserved`. The comparison is case-insensitive like the default APFS
    /// volume. `current` is the item's own name, which never counts as a clash.
    static func unique(
        _ base: String,
        extension ext: String?,
        in directory: URL,
        reserved: Set<String> = [],
        current: String? = nil
    ) -> String {
        let existing = Set(
            ((try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? [])
                .map { $0.lowercased() }
        )
        .union(reserved.map { $0.lowercased() })
        .subtracting([current?.lowercased()].compactMap { $0 })

        func name(_ suffix: Int) -> String {
            let stem = suffix == 1 ? base : "\(base) \(suffix)"
            return ext.map { "\(stem).\($0)" } ?? stem
        }

        var suffix = 1
        while existing.contains(name(suffix).lowercased()) {
            suffix += 1
        }
        return name(suffix)
    }
}
