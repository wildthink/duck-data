//
//  DataFrame.swift
//  SwiftFrames
//
//  Created by Tyler Maxwell on 6/4/25.
//

import Foundation

/// A simple in-memory tabular data structure, inspired by Python's pandas `DataFrame`.
/// Rows are stored in row-major format (each row is an array of optional values).
public struct DataFrame {
    /// The column names for the DataFrame, in order.
    public var columns: [String]
    
    /// The row data for the DataFrame, where each row is an array of values matching `columns`.
    public var data: [[Any?]] // row-major: each row = [value1, value2, ...]
    
    /// Returns the shape of the DataFrame as a tuple `(rows, columns)`.
    public var shape: (rows: Int, columns: Int) {
        return (data.count, columns.count)
    }
    
    /// Initializes a new DataFrame with a predefined set of columns and row values.
    ///
    /// - Parameters:
    ///    - columns: The ordered list of column names.
    ///    - rows: An array of rows, where each row is an array of optional values.
    public init(columns: [String], rows: [[Any?]]) {
        self.columns = columns
        self.data = rows
    }
    
    /// Returns the first `n` rows of the DataFrame.
    ///
    /// - Parameter n: The number of rows to return (default is 5).
    /// - Returns: An array of dictionaries, each representing a row.
    public func head(_ n: Int = 5) -> [[String: Any?]] {
        return (0..<min(n, data.count)).map { self[$0] }
    }
    
    /// Returns the last `n` rows of the DataFrame.
    ///
    /// - Parameter n: The number of rows to return (default is 5).
    /// - Returns: An array of dictionaries, each representing a row.
    public func tail(_ n: Int = 5) -> [[String: Any?]] {
        return ((data.count - min(n, data.count))..<data.count).map { self[$0] }
    }
    
    /// Saves the DataFrame contents as a CSV file at the specified file URL.
    ///
    /// - Parameter url: The local file URL to write the CSV data to.
    /// - Throws: An error if the file could not be written.
    public func toCSV(url: URL) throws {
        let csv = self.toCSV()
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Converts the DataFrame into a CSV string representation.
    ///
    /// - Returns: A single string representing the CSV output of the DataFrame.
    public func toCSV() -> String {
        var result = columns.joined(separator: ",") + "\n"
        for row in data {
            let line = row.map { ($0 != nil) ? String(describing: $0!) : "" }.joined(separator: ",")
            result += line + "\n"
        }
        return result
    }
    
    /// Returns a new DataFrame containing only rows for which the predicate returns true.
    /// - Parameter predicate: A closure that takes a row dictionary and returns a Bool.
    /// - Returns: A new filtered DataFrame.
    public func filter(_ predicate: ([String: Any?]) -> Bool) -> DataFrame {
        let filteredRows = data.enumerated().compactMap { index, row in
            let rowDict = Dictionary(uniqueKeysWithValues: zip(columns, row))
            return predicate(rowDict) ? row : nil
        }
        
        return DataFrame(columns: columns, rows: filteredRows)
    }
    
    /// Mutates the DataFrame by applying a transformation to all values in the specified column.
    /// - Parameters:
    ///   - column: The name of the column to transform.
    ///   - transform: A closure that maps an existing value to a new one.
    public mutating func mapColumn<T>(_ column: String, _ transform: (Any?) -> T?) {
        guard let colIndex = columns.firstIndex(of: column) else { return }
        for rowIndex in 0..<data.count {
            let originalValue = data[rowIndex][colIndex]
            data[rowIndex][colIndex] = transform(originalValue)
        }
    }
    
    /// Returns a new DataFrame with only the specified subset of columns.
    /// - Parameter columnNames: The list of column names to keep.
    /// - Returns: A new DataFrame with only selected columns.
    public func select(_ selectedColumns: [String]) -> DataFrame {
        let indices = selectedColumns.compactMap { columns.firstIndex(of: $0) }
        let selectedData = data.map { row in
            indices.map { row[$0] }
        }
        return DataFrame(columns: selectedColumns, rows: selectedData)
    }
    
    /// Returns a new DataFrame with all rows containing nil values removed.
    /// - Returns: A cleaned DataFrame without incomplete rows.
    public func dropna() -> DataFrame {
        let cleanedData = data.filter { row in
            !row.contains(where: { $0 == nil })
        }
        return DataFrame(columns: columns, rows: cleanedData)
    }
    
    /// Returns a new DataFrame where all nil values are replaced with a specified value.
    /// - Parameter value: The replacement value to use in place of nil.
    /// - Returns: A DataFrame with no nil values.
    public func fillna(_ value: Any) -> DataFrame {
        let filledData = data.map { row in
            row.map { $0 ?? value }
        }
        return DataFrame(columns: columns, rows: filledData)
    }
}

public extension DataFrame {
    /// Initializes a DataFrame from an array of dictionaries (rows).
    ///
    /// - Parameter rows: Each dictionary represents a row where keys are column names.
    init(rows: [[String: Any?]]) {
        let allColumns = Set(rows.flatMap { $0.keys })
        self.columns = Array(allColumns)
        
        self.data = rows.map { row in
            allColumns.map { row[$0] ?? nil }
        }
    }
    
    /// Initializes a DataFrame from a raw CSV string.
    ///
    /// The first line of the string must contain the header row.
    ///
    /// - Parameter csvString: A string in CSV format.
    init(csvString: String) {
        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        self.columns = lines.first!.components(separatedBy: ",")
        self.data = lines.dropFirst().map { line in
            line.components(separatedBy: ",").map { $0.isEmpty ? nil : $0 }
        }
    }
    
    /// Accesses a row by index and returns it as a `[column: value]` dictionary.
    ///
    /// - Parameter index: The row index (zero-based).
    subscript(_ index: Int) -> [String: Any?] {
        var result = [String: Any?]()
        for (i, column) in columns.enumerated() {
            result[column] = data[index][i]
        }
        return result
    }
    
    /// Accesses a column by name and returns an array of values for that column.
    ///
    /// - Parameter name: The name of the column.
    /// - Returns: An array of optional values for the column, or `nil` if the column does not exist.
    subscript(_ name: String) -> [Any?]? {
        guard let colIndex = columns.firstIndex(of: name) else { return nil }
        return data.map { $0[colIndex] }
    }
}

extension DataFrame: CustomStringConvertible {
    /// A string description of the DataFrame, formatted like a traditional table.
    ///
    /// Shows up to 10 rows of data and column headers with aligned spacing.
    public var description: String {
        let maxRows = min(10, data.count)
        let rowsToPrint = (0..<maxRows).map { self[$0] }
        let columnWidths = columns.map { col in
            max(col.count, rowsToPrint.compactMap { "\($0[col]! ?? "")".count }.max() ?? 0)
        }
        
        var lines: [String] = []
        
        // Header
        let headerLine = zip(columns, columnWidths)
            .map { name, width in name.padding(toLength: width, withPad: " ", startingAt: 0) }
            .joined(separator: " | ")
        lines.append(headerLine)
        lines.append(String(repeating: "-", count: headerLine.count))
        
        // Rows
        for row in rowsToPrint {
            let line = zip(columns, columnWidths)
                .map { key, width in
                    let cell = row[key] != nil ? "\(row[key]! ?? "")" : ""
                    return cell.padding(toLength: width, withPad: " ", startingAt: 0)
                }
                .joined(separator: " | ")
            lines.append(line)
        }
        
        if data.count > maxRows {
            lines.append("... (\(data.count - maxRows) more rows")
        }
        
        return lines.joined(separator: "\n")
    }
}