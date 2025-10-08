//
//  SQLiteDecoder.swift
//  Freebase
//
//  Created by Jason Jobe on 4/27/25.
//

import Foundation
import SQLite3

struct ResultColumn {
    var ndx: Int32
    var name: String
}

//@usableFromInline
public struct SQLiteStatementReader: AnyDictionary {
    let ref: OpaquePointer
    let columns: [ResultColumn]
    
    public init(ref: OpaquePointer) {
        self.ref = ref
        var cols = [ResultColumn]()
        for ndx in 0..<Int32(sqlite3_column_count(ref)) {
            let name = String(cString: sqlite3_column_name(ref, ndx))
            cols.append(ResultColumn(ndx: ndx, name: name))
        }
        self.columns = cols
    }

    @inlinable
    public func value(forKey key: String) -> Any? {
        guard let ndx = index(forKey: key)
        else { return nil }
        return try? columnValue(at: ndx)
    }
    
    @usableFromInline
    func index(forKey key: String) -> Int32? {
        columns.filter { $0.name == key }.first?.ndx
    }
    
    @usableFromInline
    func columnName(at ndx: Int32) -> String? {
        return String(cString: sqlite3_column_name(ref, ndx))
    }
    
    @usableFromInline
    func columnValue(at index: Int32) throws -> Any? {
        let idx = Int32(index)
        guard idx >= 0, idx < sqlite3_column_count(ref)
        else { throw SQLError(code: 0, "Column Index Out of Bounds") }
        let cv = sqlite3_column_value(ref, idx)
        //        let val = sqlite3_value_dup(cv)
        return SQLiteValue(cv)
    }
    
}

extension SQLiteStatementReader: AnyArray {
//    @inlinable
    public var count: Int {
        Int(sqlite3_column_count(ref))
    }
    
    @inlinable
    public func value(at ndx: Int) throws -> Any? {
        try columnValue(at: Int32(ndx))
    }
}

// MARK:

struct SQLError: Error {
    var file: String
    var line: UInt
    var code: Int32
    var message: String
    
    init(
        file: String = #fileID, line: UInt = #line,
        code: Int32 = 0, _ message: String = "unknown"
    ) {
        self.file = file
        self.line = line
        self.code = code
        self.message = message
    }
}

// MARK:
func SQLiteValue(_ value: OpaquePointer?) -> Any? {
    let type = sqlite3_value_type(value)
    return switch type {
        case SQLITE_INTEGER:
            sqlite3_value_int64(value)
        case SQLITE_FLOAT:
            sqlite3_value_double(value)
        case SQLITE_TEXT:
            String(cString: sqlite3_value_text(value))
        case SQLITE_BLOB:
            Data(bytes: sqlite3_value_blob(value), count: Int(sqlite3_value_bytes(value)))
        case SQLITE_NULL:
            nil
        default:
            fatalError("Unknown SQLite value type \(type) encountered")
    }
}

#if SQL_STATEMENT
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public struct SQLStatement {
    let db: OpaquePointer
    let sql: String // Template
    let statement: OpaquePointer
    
    public init(db: OpaquePointer, sql: String) throws {
        self.db = db
        self.sql = sql
        
        var ptr: OpaquePointer?
        let code = sqlite3_prepare_v2(db, sql, -1, &ptr, nil)
        guard code == SQLITE_OK, let ptr
        else { throw SQLiteError(db: db) }

        self.statement = ptr
    }
    
    public func finalize() { sqlite3_finalize(statement) }
    public func reset() { sqlite3_reset(statement) }

    public func bind(values: [Any]) throws {
        let paramCount = sqlite3_bind_parameter_count(statement)
        guard paramCount != values.count else {
            throw SQLiteError(reason: "Wrong number of parameters")
        }
        for (index, value) in zip(Int32(1)..., values) {
            let result =
            switch value {
                case let blob as [UInt8]:
                    sqlite3_bind_blob(statement, index, Array(blob), Int32(blob.count), SQLITE_TRANSIENT)
                case let data as Data:
                    data.withUnsafeBytes { blob in
                        sqlite3_bind_blob(statement, index, Array(blob), Int32(blob.count), SQLITE_TRANSIENT)
                    }

                case let double as Double:
                    sqlite3_bind_double(statement, index, double)
                case let real as any BinaryFloatingPoint:
                    sqlite3_bind_double(statement, index, Double(real))

                case let int as Int:
                    sqlite3_bind_int64(statement, index, Int64(int))
                case let int as any FixedWidthInteger:
                    sqlite3_bind_int64(statement, index, Int64(int))

                case let text as String:
                    sqlite3_bind_text(statement, index, text, -1, SQLITE_TRANSIENT)
                case let str as Substring:
                    sqlite3_bind_text(statement, index, str.description, -1, SQLITE_TRANSIENT)

                case let it as Encodable:
                    bind(it, at: index)

                default:
                    sqlite3_bind_null(statement, index)
            }
            guard result == SQLITE_OK else { throw SQLiteError(db: db) }
        }
    }
    
    @usableFromInline
    func bind(_ value: Encodable, at index: Int32) -> Int32 {
        if let data = try? JSONEncoder().encode(value) {
            data.withUnsafeBytes { blob in
                sqlite3_bind_blob(statement, index, Array(blob), Int32(blob.count), SQLITE_TRANSIENT)
            }
        } else {
            SQLITE_ERROR
        }
    }
}
#endif
/*
 let count = Int(sqlite3_column_bytes(ref, idx))
 let data = Data(bytes: b.assumingMemoryBound(to: UInt8.self), count: count)
 return data
 */

