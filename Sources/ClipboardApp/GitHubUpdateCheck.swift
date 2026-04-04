import Foundation

/// Fetches the latest published GitHub release for [ClipBoard](https://github.com/MichaelMIL/ClipBoard).
enum GitHubUpdateCheck {
    private static let latestReleaseAPI = URL(string: "https://api.github.com/repos/MichaelMIL/ClipBoard/releases/latest")!

    enum Outcome: Equatable {
        case idle
        case checking
        case upToDate(latest: String)
        case updateAvailable(latest: String, pageURL: URL)
        case failed(message: String)
    }

    private struct ReleasePayload: Decodable {
        let tagName: String
        let htmlURL: String

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    static func check(currentVersion: String) async -> Outcome {
        var request = URLRequest(url: latestReleaseAPI)
        request.setValue("Clipboard/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .failed(message: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            return .failed(message: "Invalid response.")
        }

        if http.statusCode == 404 {
            return .failed(message: "No releases found on GitHub yet.")
        }

        guard (200 ... 299).contains(http.statusCode) else {
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
            let detail = snippet.isEmpty ? "HTTP \(http.statusCode)" : "HTTP \(http.statusCode): \(snippet)"
            return .failed(message: detail)
        }

        let decoded: ReleasePayload
        do {
            decoded = try JSONDecoder().decode(ReleasePayload.self, from: data)
        } catch {
            return .failed(message: "Could not read release info.")
        }

        let latest = decoded.tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pageURL = URL(string: decoded.htmlURL) else {
            return .failed(message: "Invalid release page URL.")
        }

        switch compareVersions(latest, currentVersion) {
        case .orderedDescending:
            return .updateAvailable(latest: latest, pageURL: pageURL)
        case .orderedAscending, .orderedSame:
            return .upToDate(latest: latest)
        }
    }

    /// Strips a leading `v` and compares dotted numeric segments (e.g. `1.10.0` vs `1.9.0`).
    private static func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
        let na = normalizedNumericParts(a)
        let nb = normalizedNumericParts(b)
        let count = max(na.count, nb.count)
        for i in 0 ..< count {
            let va = i < na.count ? na[i] : 0
            let vb = i < nb.count ? nb[i] : 0
            if va < vb { return .orderedAscending }
            if va > vb { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func normalizedNumericParts(_ raw: String) -> [Int] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutV = trimmed.hasPrefix("v") || trimmed.hasPrefix("V")
            ? String(trimmed.dropFirst())
            : trimmed
        let main = withoutV.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true).first
            ?? withoutV[...]
        return main.split(separator: ".").map { segment in
            let digits = segment.prefix { $0.isNumber }
            return Int(digits) ?? 0
        }
    }
}
