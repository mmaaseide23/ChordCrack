// Create a new file: ViewExtensions.swift
import SwiftUI

extension View {
    func safeFrame(width: CGFloat? = nil, height: CGFloat? = nil) -> some View {
        self.frame(
            width: width.map { max(0, $0.isFinite ? $0 : 0) },
            height: height.map { max(0, $0.isFinite ? $0 : 0) }
        )
    }
    
    func debugFrame(_ label: String = "") -> some View {
        self.background(
            GeometryReader { geometry in
                Color.clear.onAppear {
                    #if DEBUG
                    if geometry.size.width < 0 || geometry.size.height < 0 ||
                       geometry.size.width.isNaN || geometry.size.height.isNaN ||
                       geometry.size.width.isInfinite || geometry.size.height.isInfinite {
                        print("⚠️ Invalid frame in \(label): \(geometry.size)")
                    }
                    #endif
                }
            }
        )
    }
}
