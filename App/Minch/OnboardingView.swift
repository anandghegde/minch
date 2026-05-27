import SwiftUI
import MinchUI

struct OnboardingView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.minchSurfaceWindow, Color.minchSurfacePrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: MinchSpacing.xl) {
                Spacer(minLength: MinchSpacing.xxl)

                MinchWordmark(size: 56)

                VStack(spacing: MinchSpacing.s) {
                    Text("Connect your TorBox account")
                        .font(.minchTitle)
                        .foregroundStyle(.primary)
                    Text("Paste your API key to get started. Minch stores it in your macOS Keychain — never on disk, never in logs.")
                        .font(.minchCallout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, MinchSpacing.xxl)

                form

                Link(destination: URL(string: "https://torbox.app/settings")!) {
                    HStack(spacing: MinchSpacing.xs) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Find your API key on torbox.app/settings")
                    }
                    .font(.minchCallout)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(MinchSpacing.xxl)
            .frame(maxWidth: 520)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var form: some View {
        VStack(spacing: MinchSpacing.m) {
            SecureField("API key", text: $model.pendingKey, prompt: Text("TorBox API key"))
                .textFieldStyle(.plain)
                .font(.minchMono)
                .padding(MinchSpacing.m)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: MinchRadius.m, style: .continuous))
                .disabled(isValidating)
                .onSubmit { submit() }

            if case let .signedOut(message?) = model.state {
                Text(message)
                    .font(.minchCallout)
                    .foregroundStyle(Color.minchDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: submit) {
                HStack(spacing: MinchSpacing.s) {
                    if isValidating {
                        ProgressView().controlSize(.small)
                    }
                    Text(isValidating ? "Validating…" : "Connect to TorBox")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.minch(.primary))
            .disabled(isValidating || model.pendingKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var isValidating: Bool {
        if case .validating = model.state { return true }
        return false
    }

    private func submit() {
        Task { await model.connect() }
    }
}

#Preview {
    OnboardingView(model: AppModel())
        .frame(width: 720, height: 560)
}
