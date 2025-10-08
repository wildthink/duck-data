import Foundation

extension [QueryBinding] {
  fileprivate init(argumentCount: Int32, arguments: UnsafeMutablePointer<OpaquePointer?>?) {
    self = (0..<argumentCount).map { offset in
      let value = arguments?[Int(offset)]
      switch sqlite3_value_type(value) {
      case SQLITE_BLOB:
        if let blob = sqlite3_value_blob(value) {
          let count = Int(sqlite3_value_bytes(value))
          let buffer = UnsafeRawBufferPointer(start: blob, count: count)
          return .blob([UInt8](buffer))
        } else {
          return .blob([])
        }
      case SQLITE_FLOAT:
        return .double(sqlite3_value_double(value))
      case SQLITE_INTEGER:
        return .int(sqlite3_value_int64(value))
      case SQLITE_NULL:
        return .null
      case SQLITE_TEXT:
        return .text(String(cString: UnsafePointer(sqlite3_value_text(value))))
      default:
        return .invalid(UnknownType())
      }
    }
  }

  private struct UnknownType: Error {}
}

extension QueryBinding {
  fileprivate func result(db: OpaquePointer?) {
    switch self {
    case .blob(let blob):
      sqlite3_result_blob(db, Array(blob), Int32(blob.count), SQLITE_TRANSIENT)
    case .bool(let bool):
      sqlite3_result_int64(db, bool ? 1 : 0)
    case .double(let double):
      sqlite3_result_double(db, double)
    case .date(let date):
      sqlite3_result_text(db, date.iso8601String, -1, SQLITE_TRANSIENT)
    case .int(let int):
      sqlite3_result_int64(db, int)
    case .null:
      sqlite3_result_null(db)
    case .text(let text):
      sqlite3_result_text(db, text, -1, SQLITE_TRANSIENT)
    case .uint(let uint) where uint <= UInt64(Int64.max):
      sqlite3_result_int64(db, Int64(uint))
    case .uint(let uint):
      sqlite3_result_error(db, "Unsigned integer \(uint) overflows Int64.max", -1)
    case .uuid(let uuid):
      sqlite3_result_text(db, uuid.uuidString.lowercased(), -1, SQLITE_TRANSIENT)
    case .invalid(let error):
      sqlite3_result_error(db, error.underlyingError.localizedDescription, -1)
    }
  }
}
