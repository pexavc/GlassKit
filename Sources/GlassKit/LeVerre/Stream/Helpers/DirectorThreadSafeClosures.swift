import Foundation

enum DirectorError: Error {
    case closureIsDead
}

/**
 P for payload
 */
class DirectorThreadSafeClosures<P>  {
    typealias TypeClosure = (Key, P) throws -> Void
    private var queue: DispatchQueue = DispatchQueue(label: "SwiftAudioPlayer.thread_safe_map\(UUID().uuidString)", attributes: .concurrent)
    private var closures: [UInt: TypeClosure] = [:]
    private var cache: [Key: P] = [:]
    
    var count: Int {
        get {
            return closures.count
        }
    }
    
    func broadcast(key: Key, payload: P) {
        queue.sync {
            self.cache[key] = payload
            var iterator = self.closures.makeIterator()
            while let element = iterator.next() {
                do {
                    try element.value(key, payload)
                } catch {
                    helperRemove(withKey: element.key)
                }
            }
        }
    }
    
    //UInt is actually 64-bits on modern devices
    func attach(closure: @escaping TypeClosure) -> UInt {
        let id: UInt = Date.getUTC64()
        
        //The director may not yet have the status yet. We should only call the closure if we have it
        //Let the caller know the immediate value. If it's dead already then stop
        for (key, val) in cache {
            do {
                try closure(key, val)
            } catch {
                return id
            }
        }
        
        //Replace what's in the map with the new closure
        helperInsert(withKey: id, closure: closure)
        
        return id
    }
    
    func detach(id: UInt) {
        helperRemove(withKey: id)
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.closures.removeAll()
            self.cache.removeAll()
        }
    }
    
    private func helperRemove(withKey key: UInt) {
        queue.async(flags: .barrier) {
            self.closures[key] = nil
        }
    }
    
    private func helperInsert(withKey key: UInt, closure: @escaping TypeClosure) {
        queue.async(flags: .barrier) {
            self.closures[key] = closure
        }
    }
}
