import SwiftUI

struct StartupErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("DishD non riesce ad aprire l’archivio locale")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Chiudi e riapri l’app. Se il problema continua, libera spazio sul dispositivo o reinstallala. Nessun dato viene inviato a servizi esterni.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
