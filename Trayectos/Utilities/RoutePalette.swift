import SwiftUI
import UIKit

enum RoutePalette {
    private static let colors: [UIColor] = [
        UIColor(red: 0.357, green: 0.361, blue: 0.886, alpha: 1),
        UIColor(red: 0.255, green: 0.722, blue: 0.651, alpha: 1),
        UIColor(red: 0.961, green: 0.620, blue: 0.196, alpha: 1),
        UIColor(red: 0.925, green: 0.337, blue: 0.545, alpha: 1),
        UIColor(red: 0.541, green: 0.376, blue: 0.792, alpha: 1),
        UIColor(red: 0.929, green: 0.420, blue: 0.267, alpha: 1),
        UIColor(red: 0.176, green: 0.627, blue: 0.788, alpha: 1),
        UIColor(red: 0.482, green: 0.702, blue: 0.286, alpha: 1)
    ]

    static func uiColor(for index: Int) -> UIColor {
        colors[index % colors.count]
    }

    static func color(for index: Int) -> Color {
        Color(uiColor: uiColor(for: index))
    }
}

