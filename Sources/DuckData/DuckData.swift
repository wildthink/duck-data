import DuckDB
import Foundation
import StructuredQueries

public struct ColumnKey<Base, Value> {
    public let name: String
    public let index: Int
    public let keyPath: WritableKeyPath<Base, Value>
}

@frozen
public struct ColumnStorage<Value> {
    @usableFromInline let buffer: UnsafeBufferPointer<Value>

    @inlinable
    subscript(row: Int) -> Value {
        buffer.baseAddress!.advanced(by: row).pointee
    }
}

@frozen
public struct AnyColumnBinder<Base> {
    @usableFromInline
    let _assign: (inout Base, Int) -> Void

    @inlinable
    public init<Value>(key: ColumnKey<Base, Value>, storage: ColumnStorage<Value>) {
        self._assign = { base, row in
            base[keyPath: key.keyPath] = storage[row]
        }
    }

    // Optional-storage variant: assigns Optionals directly
    @inlinable
    init<Value>(key: ColumnKey<Base, Value?>, storage: ColumnStorage<Value?>) {
        self._assign = { base, row in
            base[keyPath: key.keyPath] = storage[row]
        }
    }

    // Defaulting variant: when storage is Optional but the destination is non-Optional
    @inlinable
    init<Value>(key: ColumnKey<Base, Value>, storage: ColumnStorage<Value?>, default defaultValue: @escaping () -> Value) {
        self._assign = { base, row in
            base[keyPath: key.keyPath] = storage[row] ?? defaultValue()
        }
    }

    @inlinable
    func assign(into base: inout Base, row: Int) {
        _assign(&base, row)
    }
}

struct DataTable<Base> {
    let binders: [AnyColumnBinder<Base>]

    @inlinable
    init(binders: [AnyColumnBinder<Base>]) {
        self.binders = binders
    }

    @inlinable
    func fill(_ base: inout Base, row: Int) {
        for binder in binders {
            binder.assign(into: &base, row: row)
        }
    }
}

struct DataTableBuilder<Base> {
    private var binders: [AnyColumnBinder<Base>] = []

    init() {}

    @inlinable
    mutating func addColumn<Value>(name: String, index: Int, keyPath: WritableKeyPath<Base, Value>, buffer: UnsafeBufferPointer<Value>) {
        let key = ColumnKey<Base, Value>(name: name, index: index, keyPath: keyPath)
        let storage = ColumnStorage(buffer: buffer)
        binders.append(AnyColumnBinder(key: key, storage: storage))
    }

    @inlinable
    mutating func addOptionalColumn<Value>(name: String, index: Int, keyPath: WritableKeyPath<Base, Value?>, buffer: UnsafeBufferPointer<Value?>) {
        let key = ColumnKey<Base, Value?>(name: name, index: index, keyPath: keyPath)
        let storage = ColumnStorage(buffer: buffer)
        binders.append(AnyColumnBinder(key: key, storage: storage))
    }

    @inlinable
    mutating func addColumnWithDefault<Value>(name: String, index: Int, keyPath: WritableKeyPath<Base, Value>, buffer: UnsafeBufferPointer<Value?>, default defaultValue: @autoclosure @escaping () -> Value) {
        let key = ColumnKey<Base, Value>(name: name, index: index, keyPath: keyPath)
        let storage = ColumnStorage(buffer: buffer)
        binders.append(AnyColumnBinder(key: key, storage: storage, default: defaultValue))
    }

    @inlinable
    func build() -> DataTable<Base> {
        DataTable(binders: binders)
    }
}

struct Person {
    var id: Int
    var name: String
    var height: Double
}

//func example() {
//    let idBuf: UnsafeBufferPointer<Int> = /* from your engine */
//    let nameBuf: UnsafeBufferPointer<String> = /* from your engine */
//    let heightBuf: UnsafeBufferPointer<Double> = /* from your engine */
//    
//    var builder = DataTableBuilder<Person>()
//    builder.addColumn(name: "id", index: 0, keyPath: \.id, buffer: idBuf)
//    builder.addColumn(name: "name", index: 1, keyPath: \.name, buffer: nameBuf)
//    builder.addColumn(name: "height", index: 2, keyPath: \.height, buffer: heightBuf)
//    
//    let table = builder.build()
//    
//    var p = Person(id: 0, name: "", height: 0)
//    table.fill(&p, row: 42)
//}


/*
struct DuckDBDecoder<Base> {
    var base: Base
    var row: Int
    var table: DataTable<Base>

    func decode(_ type: Base.Type) throws -> Base {
        var base = self.base
        table.fill(&base, row: row)
        return base
    }
}

extension PreparedStatement {
    func fetch<Base>(type: Base.Type = Base.self) -> [Base] {
        var base = Base()
        var results: [Base] = []
        let table = DataTable<Base>()
        while step() {
            table.fill(&base, row: row)
            results.append(base)
        }
        return results
    }
}

@dynamicMemberLookup
struct DataTableCursor<Base> {
    var table: DataTable<Base>
    
    subscript<Value>(dynamicMember keyPath: WritableKeyPath<Base, Value>) -> Value {
        get {
            fatalError("Not implemented")
        } nonmutating set {
            fatalError("Not implemented")
        }
    }
}
 */
