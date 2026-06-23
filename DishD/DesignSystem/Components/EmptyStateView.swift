import SwiftUI

struct EmptyStateView: View {
    let title: String; let message: String; let buttonTitle: String; let action: () -> Void
    var body: some View { VStack(spacing: 18) { Image(systemName: "book.closed").font(.system(size: 56)).foregroundStyle(DishDColor.herb); Text(title).font(.title.bold()).multilineTextAlignment(.center); Text(message).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center); Button(buttonTitle, action: action).buttonStyle(.borderedProminent) }.padding(32) }
}
