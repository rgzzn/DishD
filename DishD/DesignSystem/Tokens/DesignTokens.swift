import SwiftUI

enum DishDColor {
    static let canvas = Color("Canvas")
    static let surface = Color("Surface")
    static let surfaceElevated = Color("SurfaceElevated")
    static let ink = Color("Ink")
    static let secondaryInk = Color("SecondaryInk")
    static let herb = Color("Herb")
    static let herbStrong = Color("HerbStrong")
    static let tomato = Color("Tomato")
    static let saffron = Color("Saffron")
    static let blueberry = Color("Blueberry")
}

enum DishDSpacing {
    static let compact: CGFloat = 8
    static let standard: CGFloat = 16
    static let roomy: CGFloat = 24
}

enum DishDRadius {
    static let control: CGFloat = 14
    static let card: CGFloat = 24
}

extension View {
    func dishdCard() -> some View {
        self
            .padding(DishDSpacing.standard)
            .background(DishDColor.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DishDRadius.card, style: .continuous))
    }
}
