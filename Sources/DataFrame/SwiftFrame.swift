// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public struct SwiftFrames {
    /// Asynchronously reads a CSV file from a local or remote URL and parses it into a `DataFrame`.
    ///
    /// This function automatically detects whether the URL is local (e.g., file://) or remote (e.g., http:// or https://)
    /// and handles downloading or reading the file accordingly.
    ///
    /// The CSV is expected to have a header row as the first line, and rows of comma-separated values following it.
    /// Each value will be automatically inferred as one of the following Swift types, in this order:
    /// - `Bool` (if the string is "true" or "false", case-insensitive)
    /// - `Int`
    /// - `Double`
    /// - `String` (fallback if no other match)
    ///
    /// - Parameter url: The `URL` of the CSV file to load. Can be either a local file URL or a remote HTTP(S) URL.
    /// - Returns: A `DataFrame` instance populated with the parsed CSV data.
    /// - Throws: Any `URLError` or file reading error, or a decoding error if the data could not be converted to a string.
    public static func readCSV(url: URL) async throws -> DataFrame {
        let isRemote = url.scheme?.starts(with: "http") ?? false
        
        let csvString: String
        if isRemote {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let string = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
            csvString = string
        } else {
            csvString = try String(contentsOf: url)
        }
        
        return DataFrame(csvString: csvString)
    }
}