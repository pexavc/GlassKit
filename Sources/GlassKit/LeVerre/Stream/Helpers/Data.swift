import Foundation

extension Data {
    // Introduced in Swift 5, withUnsafeBytes using UnsafePointers is deprecated
    // https://mjtsai.com/blog/2019/03/27/swift-5-released/
    func accessBytes<R>(_ body: (UnsafePointer<UInt8>) throws -> R) rethrows -> R {
        return try withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) -> R in
            let unsafeBufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
            guard let unsafePointer = unsafeBufferPointer.baseAddress else {
                Log.error("")
                var int: UInt8 = 0
                return try body(&int)
            }
            return try body(unsafePointer)
        }
    }
    
    mutating func accessMutableBytes<R>(_ body: (UnsafeMutablePointer<UInt8>) throws -> R) rethrows -> R {
        return try withUnsafeMutableBytes { (rawBufferPointer: UnsafeMutableRawBufferPointer) -> R in
            let unsafeMutableBufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
            guard let unsafeMutablePointer = unsafeMutableBufferPointer.baseAddress else {
                Log.error("")
                var int: UInt8 = 0
                return try body(&int)
            }
            return try body(unsafeMutablePointer)
        }
    }
}
