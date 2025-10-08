import Foundation
import DuckDB

//public extension Database {
// 
//    @inlinable
//    func insert<T: Encodable>(as t: T.Type = T.self
//    ) throws {
//    }
//
//    @inlinable
//    func update<T: Encodable>(as t: T.Type = T.self
//    ) throws {
//    }
//    
//    @inlinable
//    func select<T: Decodable>(as t: T.Type = T.self, _ query: some SelectStatement
//    ) throws -> [T] {
//        print(query._selectClauses)
//        return []
//    }
//    
//    @inlinable
//    func select<T: Decodable, QueryValue>(
//        _ query: some SelectStatementOf<QueryValue>
//    ) throws -> [T] {
//        print(#function, type(of: QueryValue.self))
//        let q2 = query.asSelect().select { _ in "okay" }
//        print(q2)
//        print(query._selectClauses)
//       return []
//    }
//    
//
//  @inlinable
//  func execute<QueryValue: QueryRepresentable>(
//    _ query: some Statement<QueryValue>
//  ) throws -> [QueryValue.QueryOutput] {
//    let query = query.query
//    guard !query.isEmpty else { return [] }
//    return try withStatement(query) { statement in
//      var results: [QueryValue.QueryOutput] = []
//      var decoder = SQLiteQueryDecoder(statement: statement)
//      loop: while true {
//        let code = sqlite3_step(statement)
//        switch code {
//        case SQLITE_ROW:
//          try results.append(decoder.decodeColumns(QueryValue.self))
//          decoder.next()
//        case SQLITE_DONE:
//          break loop
//        default:
//                break
////          throw SQLiteError(db: storage.handle)
//        }
//      }
//      return results
//    }
//  }
//
//  @inlinable
//  func execute<each V: QueryRepresentable>(
//    _ query: some Statement<(repeat each V)>
//  ) throws -> [(repeat (each V).QueryOutput)] {
//    let query = query.query
//    guard !query.isEmpty else { return [] }
//    return try withStatement(query) { statement in
//      var results: [(repeat (each V).QueryOutput)] = []
//      var decoder = SQLiteQueryDecoder(statement: statement)
//      loop: while true {
//        let code = sqlite3_step(statement)
//        switch code {
//        case SQLITE_ROW:
//          try results.append(decoder.decodeColumns((repeat each V).self))
//          decoder.next()
//        case SQLITE_DONE:
//          break loop
//        default:
//          throw SQLiteError()
//        }
//      }
//      return results
//    }
//  }
//
//  @inlinable
//  func execute<QueryValue>(
//    _ query: some SelectStatementOf<QueryValue>
//  ) throws -> [QueryValue.QueryOutput] {
//    let query = query.query
//    guard !query.isEmpty else { return [] }
//    return try withStatement(query) { statement in
//      var results: [QueryValue.QueryOutput] = []
//      var decoder = SQLiteQueryDecoder(statement: statement)
//      loop: while true {
//        let code = sqlite3_step(statement)
//        switch code {
//        case SQLITE_ROW:
//          try results.append(QueryValue(decoder: &decoder).queryOutput)
//          decoder.next()
//        case SQLITE_DONE:
//          break loop
//        default:
//          throw SQLiteError()
//        }
//      }
//      return results
//    }
//  }
//
//  @inlinable
//  public func execute<S: SelectStatement, each J: Table>(
//    _ query: S
//  ) throws -> [(S.From.QueryOutput, repeat (each J).QueryOutput)]
//  where S.QueryValue == (), S.Joins == (repeat each J) {
//    try execute(query.selectStar())
//  }
//
//  @usableFromInline
//  func withStatement<R>(
//    _ query: QueryFragment, body: (OpaquePointer) throws -> R
//  ) throws -> R {
//    let (sql, bindings) = query.prepare { _ in "?" }
//    var statement: OpaquePointer?
//    let code = sqlite3_prepare_v2(storage.handle, sql, -1, &statement, nil)
//    guard code == SQLITE_OK, let statement
//    else { throw SQLiteError(db: storage.handle) }
//    defer { sqlite3_finalize(statement) }
//    for (index, binding) in zip(Int32(1)..., bindings) {
//      let result =
//        switch binding {
//        case .blob(let blob):
//          sqlite3_bind_blob(statement, index, Array(blob), Int32(blob.count), SQLITE_TRANSIENT)
//        case .bool(let bool):
//          sqlite3_bind_int64(statement, index, bool ? 1 : 0)
//        case .date(let date):
//          sqlite3_bind_text(statement, index, date.iso8601String, -1, SQLITE_TRANSIENT)
//        case .double(let double):
//          sqlite3_bind_double(statement, index, double)
//        case .int(let int):
//          sqlite3_bind_int64(statement, index, Int64(int))
//        case .null:
//          sqlite3_bind_null(statement, index)
//        case .text(let text):
//          sqlite3_bind_text(statement, index, text, -1, SQLITE_TRANSIENT)
//        case .uint(let uint) where uint <= UInt64(Int64.max):
//          sqlite3_bind_int64(statement, index, Int64(uint))
//        case .uint(let uint):
//          throw Int64OverflowError(unsignedInteger: uint)
//        case .uuid(let uuid):
//          sqlite3_bind_text(statement, index, uuid.uuidString.lowercased(), -1, SQLITE_TRANSIENT)
//        case .invalid(let error):
//          throw error.underlyingError
//        }
//      guard result == SQLITE_OK else { throw SQLiteError(db: storage.handle) }
//    }
//    return try body(statement)
//  }
//
//  @usableFromInline
//    enum Storage : @unchecked Sendable {
//    case owned(Autoreleasing)
//    case unowned(OpaquePointer)
//
//    @usableFromInline
//    var handle: OpaquePointer {
//      switch self {
//      case .owned(let storage):
//        return storage.handle
//      case .unowned(let handle):
//        return handle
//      }
//    }
//
//    @usableFromInline
//    final class Autoreleasing {
//      fileprivate var handle: OpaquePointer
//
//      init(_ handle: OpaquePointer) {
//        self.handle = handle
//      }
//
//      deinit {
//        sqlite3_close_v2(handle)
//      }
//    }
//  }
//}

extension Database {
    public enum Location: Sendable, CustomStringConvertible {
        case inMemory
        case url(URL)
        case file(String)
        
        public var description: String {
            switch self {
                case .inMemory: ":memory:"
                case .url(let url): url.absoluteString
                case .file(let path): path
            }
        }
    }
}

struct Int64OverflowError: Error { let unsignedInteger: UInt64 }

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

@usableFromInline
struct SQLiteError: LocalizedError {
  var message: String = "SQLite error"


//  init(db handle: OpaquePointer?) {
//    self.message = String(cString: sqlite3_errmsg(handle))
//  }
//
  @usableFromInline
  init(code: Int32 = 0) {
    self.message = String(cString: sqlite3_errstr(code))
  }

  @usableFromInline
  var errorDescription: String? {
    message
  }
}
