import Foundation

/// Debug-only logging. Compiles to nothing in Release builds.
/// Usage: `debugLog("[AudioManager] Playing chord")` instead of `print(...)`
@inline(__always)
func debugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}
