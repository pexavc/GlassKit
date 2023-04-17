import Foundation

public typealias UTC = Int
extension Date {
    /**
     Finds the 64-bit representation of UTC. rand() uses UTC as a seed, so using the raw UTC should be sufficient for our case.
     
     - Returns: A 64-bit representation of time.
     */
    static func getUTC64() -> UInt {
        //"On 32-bit platforms, UInt is the same size as UInt32, and on 64-bit platforms, UInt is the same size as UInt64."
        
        if #available(iOS 11.0, *) {
            return UInt(Date().timeIntervalSince1970.bitPattern)
        } else {
            let time = Date().timeIntervalSince1970.bitPattern & 0xFFFFFFFF;
            return UInt(time)
        }
    }
    
    /**
     - Returns: UTC in seconds.
     */
    static func getUTC() -> UTC {
        return Int(Date().timeIntervalSince1970)
    }
}
