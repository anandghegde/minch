import SwiftUI
import MinchUI

struct ContentView: View {
    @Bindable var model: AppModel

    var body: some View {
        switch model.state {
        case .unknown, .validating:
            SplashView()
                .task { if case .unknown = model.state { await model.bootstrap() } }
        case .signedOut:
            OnboardingView(model: model)
        case .signedIn(let account):
            LibraryView(model: model, account: account)
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.minchSurfaceWindow, Color.minchSurfacePrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: MinchSpacing.l) {
                MinchWordmark(size: 56)
                ProgressView().controlSize(.small)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview("Onboarding") {
    ContentView(model: AppModel())
        .frame(width: 1180, height: 740)
}
