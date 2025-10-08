// Credits
// Random Generator
// https://gist.github.com/IanKeen/d3a22473a8f946bffce213a16e02dc2f
// EmptyDecoder
// https://gist.github.com/IanKeen/4348694dd62ac297ecf0d866164edb72
import Foundation

public protocol TopLevelDecoder {
    func decode<T: Decodable>(_: T.Type, from: Any) throws -> T
}

/// The `SafeDecoder` is designed to decode any "storage" that conforms
/// to `AnyDictionary` for keyed values, `AnyArray` for unkeyed containers
/// accessed by an Integer index, or `Decodable`. In addition, where reasonable
/// and possible, fundamental numeric, boolean, string, and Optional types are
/// always provided values when missing (or null) in the underlying storage value.
/// These being zero (0), false, "", and nil, respectively.
open class SafeDecoder: TopLevelDecoder {

    public let codingPath: [CodingKey]
    public let userInfo: [CodingUserInfoKey: Any]

    /// Instance-level custom decoders (checked before static decoders)
    private var instanceDecoders: [CustomValueDecoder] = []

    public init(userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.codingPath = []
        self.userInfo = userInfo
    }

    /// Register a custom decoder for this instance only
    /// Instance decoders are checked before static decoders
    /// - Returns: self for fluent chaining
    @discardableResult
    public func registerInstanceDecoder<T: Decodable>(
        _ type: T.Type,
        decoder: @escaping (Any, [CodingUserInfoKey: Any]) throws -> T
    ) -> Self {
        instanceDecoders.append(BuiltinValueDecoder(type, fn: decoder))
        return self
    }
    
    // TopLevelDecoder
    public func decode<D: Decodable>(_ type: D.Type = D.self, from top: Any) throws -> D {
        try decode(type, key: "root", from: top)
    }
    
    public func decode<D: Decodable>(_: D.Type = D.self, key: String, from top: Any) throws -> D {
        // Check instance decoders first, then static decoders
        if let xf = instanceDecoders.first(where: { $0.canDecode(D.self) }) {
            return try xf.decode(top, userInfo: userInfo)
        } else if let xf = SafeDecoder.decoders.first(where: { $0.canDecode(D.self) }) {
            return try xf.decode(top, userInfo: userInfo)
        } else if let raw = top as? any BinaryInteger,
                  let f = D.self as? any ExpressibleByIntegerLiteral.Type,
                  let value = f.make(raw) as? D
        {
            return value
        } else {
            return try D(from: singleValueContainer(key: key, value: top))
        }
    }

    func container<Key: CodingKey>(value: Any, keyedBy type: Key.Type
    ) throws -> KeyedDecodingContainer<Key> {
        guard let dict = value as? AnyDictionary
        else { throw SafeDecoderError.unsupported(Swift.type(of: value)) }
        return .init(KeyedContainer<Key>(decoder: self, value: dict))
    }
    
    func unkeyedContainer(value: Any) throws -> UnkeyedDecodingContainer {
        guard let array = (value as? AnyArray) ?? (value as? NSArray)
        else { throw SafeDecoderError.unsupported(type(of: value)) }
        return UnkeyedContainer(decoder: self, array: array)
    }
    func singleValueContainer(key: String, value: Any) throws -> SingleValueContainer {
        return SingleValueContainer(key: key, decoder: self, value: value)
    }
}

// MARK: - Integer Literal Conversion

extension ExpressibleByIntegerLiteral {
    static func make<I: BinaryInteger>(_ value: I) -> Self? {
        // NOTE: We do this little dance to hopefully be able to
        // cast the input value to an acceptable init value
        let v: any BinaryInteger = switch IntegerLiteralType.self {
        case let f as Int.Type:     f.init(value)
        case let f as Int64.Type:   f.init(value)
        case let f as Int32.Type:   f.init(value)
        case let f as UInt.Type:    f.init(value)
        case let f as UInt64.Type:  f.init(value)
        case let f as UInt32.Type:  f.init(value)
        default: {
            print("WARNING: Unsupported integer literal type: \(type(of: value))")
            return Int(value)
        }()
        }
        return if let x = v as? IntegerLiteralType {
            Self.init(integerLiteral: x)
        } else {
            nil
        }
    }
}

// MARK: associated public protocols
public protocol AnyDictionary {
    func value(forKey: String) -> Any?
}

public protocol AnyArray {
    var count: Int { get }
    func value(at: Int) throws -> Any?
}

public protocol ContainerValue {
    static func emptyValue() -> Self
}

extension Array: ContainerValue {
    public static func emptyValue() -> Array<Element> { [] }
}


extension Dictionary: ContainerValue {
    public static func emptyValue() -> Dictionary<Key, Value> { [:] }
}

extension Set: ContainerValue {
    public static func emptyValue() -> Set<Element> { .init() }
}

extension NSDictionary: AnyDictionary {}
extension Dictionary: AnyDictionary where Key == String {
    public func value(forKey key: String) -> Any? {
        self[key]
    }
}

extension NSArray: AnyArray {
    public func value(at ndx: Int) throws -> Any? {
        self.object(at: ndx)
    }
}

extension Array: AnyArray {
    public func value(at ndx: Int) -> Any? {
        self[ndx]
    }
}

extension Decodable {
    public static func empty() throws -> Self {
        switch Self.self {
            case is String.Type:
                "" as! Self
            case let f as ContainerValue.Type:
                f.emptyValue() as! Self
        default: try {
            print("WARNING: Unsupported type \(Self.self)")
            return try Self(from: SafeDecoder()
                .singleValueContainer(key: "<empty>", value: NSDictionary()))
        }()
        }
    }
}

public enum SafeDecoderError: Error, Sendable {
    case notImplemented
    case unsupported(Any.Type)
    case illegalTransform(of: String, as: Any.Type, to: Any.Type)
    case unsupportedNestingContainer
    case superDecoderUnsupported
}

typealias ValueDecoderFn<Value> = (Any, [CodingUserInfoKey: Any]) throws -> Value

protocol CustomValueDecoder {
    func canDecode<D: Decodable>(_ valueType: D.Type) -> Bool
    func decode<Value: Decodable>(value: Any, as: Value.Type,
    userInfo: [CodingUserInfoKey: Any]) throws -> Value
}

extension CustomValueDecoder {
    func decode<Value: Decodable>(
        _ value: Any,
        as t: Value.Type = Value.self,
        userInfo: [CodingUserInfoKey: Any] = [:]) throws -> Value {
            try self.decode(value: value, as: t, userInfo: userInfo)
        }
}

struct BuiltinValueDecoder: CustomValueDecoder {
    var valueType: Decodable.Type
    var _decode: ValueDecoderFn<Decodable>

    init<Value: Decodable>(_ valueType: Value.Type, fn: @escaping ValueDecoderFn<Value>) {
        _decode = fn
        self.valueType = Value.self
    }
    
    func canDecode<D: Decodable>(_ valueType: D.Type) -> Bool {
        valueType == self.valueType
    }
    
    func decode<Value: Decodable>(
        value: Any,
        as vt: Value.Type = Value.self,
        userInfo: [CodingUserInfoKey: Any] = [:]
    ) throws -> Value {
        guard let rv = try _decode(value, userInfo) as? Value
        else {
            throw SafeDecoderError.unsupported(Value.self)
        }
        return rv
    }
}

//extension SafeDecoder {
    /// A method  used to translate `DatabaseValue` into `Date`.
    public enum DateDecodingMethod {
        /// Defer to `Date` for decoding.
        case deferredToDate
        /// Decode the date as a floating-point number containing the interval between the date and 00:00:00 UTC on 1 January 1970.
        case timeIntervalSince1970
        /// Decode the date as a floating-point number containing the interval between the date and 00:00:00 UTC on 1 January 2001.
        case timeIntervalSinceReferenceDate
        /// Decode the date as ISO-8601 formatted text.
        case iso8601(ISO8601DateFormatter.Options)
        /// Decode the date as text parsed by the given formatter.
        case formatted(DateFormatter)
        /// Decode the date using the given closure.
        case custom((_ value: Any) throws -> Date)
    }
//}

extension DateDecodingMethod {
    enum DateDecodingError { case incompatableStorage(Any.Type) }
    
    func decodeDate(_ value: Any) throws -> Date {
        
        switch (self, value) {
            case (.deferredToDate, let v as any Decodable):
                return try Date(from: v as! Decoder)
                
            case (.timeIntervalSince1970, let v as Double):
                return Date(timeIntervalSince1970: v)
                
            case (.timeIntervalSinceReferenceDate, let v as Double):
                return Date(timeIntervalSinceReferenceDate: v)

            case (.custom(let closure), _):
                return try closure(value)
            default:
                throw SafeDecoderError.unsupported(Swift.type(of: value))
        }
    }
}

extension SafeDecoder {
    nonisolated(unsafe) static var decoders: [CustomValueDecoder] = [
        BuiltinValueDecoder(Date.self) { (v, info) in
            // TODO: Lookup Date options from UserInfo
            let dateDecodingMethod: DateDecodingMethod =
                info[.dateDecodingMethod] as? DateDecodingMethod
                ?? .deferredToDate

            return switch v {
                case let v as Date: v
                case let v as any FixedWidthInteger:
                    Date(timeIntervalSince1970: Double(v))
                case let v as TimeInterval:
                    Date(timeIntervalSince1970: v)
                default:
                    throw SafeDecoderError.unsupported(Date.self)
            }
        },

        BuiltinValueDecoder(URL.self) { (v, info) in
            return switch v {
                case let v as URL: v
                case let v as String:
                    URL(string: v) ?? URL(fileURLWithPath: v)
                default:
                    throw SafeDecoderError.unsupported(URL.self)
            }
        }
    ]

    /// Register a custom decoder for a type
    /// This allows adding domain-specific decoders without modifying SafeDecoder
    public static func registerDecoder<T: Decodable>(_ type: T.Type, decoder: @escaping (Any, [CodingUserInfoKey: Any]) throws -> T) {
        decoders.append(BuiltinValueDecoder(type, fn: decoder))
    }
}

public extension CodingUserInfoKey {
    static let dateDecodingMethod = CodingUserInfoKey(rawValue: "dateDecodingMethod")!
}

protocol DecodingContainer {
    associatedtype Decoded
    func decodeIfPresent(_ type: Decoded.Type) throws -> Decoded?
}

// MARK: - SafeDecoder Containers
extension SafeDecoder {
    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        var allKeys: [Key] = []
        var codingPath: [CodingKey] = []
        let value: AnyDictionary?
        let decoder: SafeDecoder

        init(decoder: SafeDecoder, value: AnyDictionary?) {
            self.decoder = decoder
            self.value = value
        }
                
        func contains(_ key: Key) -> Bool {
            value?.value(forKey: key.stringValue) != nil
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            // Return true if the value is missing or explicitly nil
            guard let val = value?.value(forKey: key.stringValue) else { return true }
            return val is NSNull
        }
        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
            if let val = value?.value(forKey: key.stringValue) {
                return try (val as? T) ?? decoder.decode(T.self, from: val)
            }
            return try T.empty()
        }
        
        func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
            let val = value?.value(forKey: key.stringValue) as? AnyDictionary
            ?? NSDictionary()
            return .init(KeyedContainer<NestedKey>(decoder: decoder, value: val))
        }
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            let val = value?.value(forKey: key.stringValue) as? AnyArray
            ?? NSArray()
            return UnkeyedContainer(decoder: decoder, array: val)
        }
        func superDecoder() throws -> Decoder {
            throw SafeDecoderError.superDecoderUnsupported
        }
        func superDecoder(forKey key: Key) throws -> Decoder {
            throw SafeDecoderError.superDecoderUnsupported
        }
    }
    
    struct SingleValueContainer: Decoder, SingleValueDecodingContainer {
        var key: String
        var userInfo: [CodingUserInfoKey : Any] { decoder.userInfo }
        
        func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
            try decoder.container(value: value, keyedBy: type)
        }
        
        func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
            try decoder.unkeyedContainer(value: value)
        }
        
        func singleValueContainer() throws -> any SingleValueDecodingContainer {
            try decoder.singleValueContainer(key: key, value: value)
        }
        
        let decoder: SafeDecoder
        let codingPath: [CodingKey] = []
        var value: Any
        
        init<A>(key: String, decoder: SafeDecoder, value: A) {
            self.key = key
            self.decoder = decoder
            self.value = value
        }

        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            switch value {
                case let v as T: return v
                case let v as Data:
                    return try JSONDecoder().decode(T.self, from: v)
                case let v as String:
                    if let data = v.data(using: .utf8) {
                        let dc = JSONDecoder()
                        return try dc.decode(T.self, from: data)
                    } else {
                        return try T.empty()
                    }
                default:
                    return try T.empty()
            }
        }

        func decodeNil() -> Bool { return true }
        func decode(_ type: Bool.Type)   throws -> Bool   { (value as? Bool) ?? false }
        func decode(_ type: String.Type) throws -> String { (value as? String) ?? "" }
        
        func decode(_ type: Double.Type) throws -> Double { (value as? Double) ?? 0 }
        func decode(_ type: Float.Type)  throws -> Float  { (value as? Float) ?? 0 }
        
        func decode(_ type: Int.Type)    throws -> Int    { try decodeInt(type) }
        func decode(_ type: Int8.Type)   throws -> Int8   { try decodeInt(type) }
        func decode(_ type: Int16.Type)  throws -> Int16  { try decodeInt(type) }
        func decode(_ type: Int32.Type)  throws -> Int32  { try decodeInt(type) }
        func decode(_ type: Int64.Type)  throws -> Int64  { try decodeInt(type) }
        func decode(_ type: UInt.Type)   throws -> UInt   { try decodeInt(type) }
        func decode(_ type: UInt8.Type)  throws -> UInt8  { try decodeInt(type) }
        func decode(_ type: UInt16.Type) throws -> UInt16 { try decodeInt(type) }
        func decode(_ type: UInt32.Type) throws -> UInt32 { try decodeInt(type) }
        func decode(_ type: UInt64.Type) throws -> UInt64 { try decodeInt(type) }
        
        // A convenience method - helpful when storing "all ints" in a common format
        func decodeInt<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
            if let ns = value as? NSNumber {
                return T(ns.int64Value)
            } else {
                return (value as? T) ?? T(0)
            }
        }
    }
}

extension SafeDecoder.KeyedContainer {
    
    func decodeOptionalInt<T: FixedWidthInteger>(
        _ type: T.Type, forKey key: Key
    ) throws -> T? {
        if let ns = value as? NSNumber {
            return T(ns.int64Value)
        } else {
            return value as? T
        }
    }

    func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        let val = value?.value(forKey: key.stringValue)
        return val as? String
    }
    
    func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T? where T : Decodable {
        let val = value?.value(forKey: key.stringValue)
        guard let val else { return nil }
        return try (val as? T) ?? decoder.decode(T.self, from: val)
    }
}

// MARK:
protocol SafeDecoderContainer: Decoder {
    var value: Any { get }
}

extension SafeDecoder.SingleValueContainer: SafeDecoderContainer {}

extension SafeDecoderContainer {
    
    func decodeOptionalInt<T: FixedWidthInteger>(_ type: T.Type) throws -> T? {
        if let ns = value as? NSNumber {
            return T(ns.int64Value)
        } else {
            return value as? T
        }
    }

    func decodeIfPresent(_ type: Bool.Type)   throws -> Bool?   { value as? Bool }
    func decodeIfPresent(_ type: String.Type) throws -> String? { value as? String }
    func decodeIfPresent(_ type: Double.Type) throws -> Double? { value as? Double }
    func decodeIfPresent(_ type: Float.Type)  throws -> Float?  { value as? Float }
    func decodeIfPresent(_ type: Int.Type)    throws -> Int?    { try decodeOptionalInt(type) }
    func decodeIfPresent(_ type: Int8.Type)   throws -> Int8?   { try decodeOptionalInt(type) }
    func decodeIfPresent(_ type: Int16.Type)  throws -> Int16?  { try decodeOptionalInt(type) }
    func decodeIfPresent(_ type: Int32.Type)  throws -> Int32?  { try decodeOptionalInt(type) }
    func decodeIfPresent(_ type: Int64.Type)  throws -> Int64?  { try decodeOptionalInt(type) }
    func decodeIfPresent(_ type: UInt.Type)   throws -> UInt?   { try decodeOptionalInt(type) }
    func decodeIfPresent(_ type: UInt8.Type)  throws -> UInt8?  { try decodeOptionalInt(type) }
    func decodeIfPresent(_ type: UInt16.Type) throws -> UInt16? { try decodeOptionalInt(type) }
    func decodeIfPresent(_ type: UInt32.Type) throws -> UInt32? { try decodeOptionalInt(type) }
    func decodeIfPresent(_ type: UInt64.Type) throws -> UInt64? { try decodeOptionalInt(type) }
}

struct UnkeyedContainer: UnkeyedDecodingContainer {
    
    var codingPath: [any CodingKey] = []
    var count: Int?
    var isAtEnd: Bool { currentIndex >= array.count - 1 }
    var currentIndex: Int
    var array: AnyArray
    var decoder: SafeDecoder
    var value: Any {
        (try? array.value(at: currentIndex)) as Any
    }
    var nextValue: Any {
        mutating get throws {
            defer { currentIndex += 1 }
            return try array.value(at: currentIndex) as Any
        }
    }
    
    init(decoder: SafeDecoder, array: AnyArray, codingPath: [any CodingKey] = []) {
        self.codingPath = codingPath
        self.array = array
        self.count = array.count
        self.currentIndex = 0
        self.decoder = decoder
    }
    
    func decodeNil() -> Bool {
        return false
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let v = try nextValue
        if let h = v as? T { return h }
        let h = try decoder.decode(T.self, from: v)
        if Swift.type(of: v) != Swift.type(of: h) {
            throw SafeDecoderError.illegalTransform(
                of: String(describing: v), as: Swift.type(of: v), to: Swift.type(of: h))
        }
        return h
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        throw SafeDecoderError.unsupportedNestingContainer
    }
    
    func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
        throw SafeDecoderError.unsupportedNestingContainer
    }
    
    func superDecoder() throws -> any Decoder {
        throw SafeDecoderError.superDecoderUnsupported
    }
}
