import Foundation
import AppKit
import Combine

class OAuthManager: NSObject, ObservableObject {
    static let shared = OAuthManager()

    @Published var isAuthenticating = false
    @Published var errorMessage: String?

    private let codexCLIPath = "/Applications/Codex.app/Contents/Resources/codex"
    private let chatGPTSettingsURL = URL(string: "https://chatgpt.com/#settings")

    private var completionHandler: ((Result<OAuthTokens, Error>) -> Void)?
    private var loginProcess: Process?
    private var loginHomeURL: URL?
    private var outputPipe: Pipe?
    private var capturedOutput = ""
    private var didPresentDeviceAuthPrompt = false

    func startOAuth(completion: @escaping (Result<OAuthTokens, Error>) -> Void) {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        errorMessage = nil
        completionHandler = completion
        capturedOutput = ""
        didPresentDeviceAuthPrompt = false

        let tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexbar-login-\(UUID().uuidString)", isDirectory: true)
        let tempCodexDir = tempHome.appendingPathComponent(".codex", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: tempCodexDir, withIntermediateDirectories: true)
        } catch {
            fail(error)
            return
        }

        loginHomeURL = tempHome

        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexCLIPath)
        process.arguments = ["login", "--device-auth"]

        var env = ProcessInfo.processInfo.environment
        env["HOME"] = tempHome.path
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        outputPipe = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            self.handleCLIOutput(chunk)
        }

        process.terminationHandler = { [weak self] task in
            guard let self else { return }
            self.outputPipe?.fileHandleForReading.readabilityHandler = nil
            self.outputPipe = nil
            self.loginProcess = nil

            if task.terminationStatus == 0,
               let authFileURL = self.loginHomeURL?.appendingPathComponent(".codex/auth.json"),
               let tokens = Self.readTokens(fromAuthFile: authFileURL) {
                self.finish(.success(tokens))
            } else {
                let message = self.capturedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallback = self.localizedFailureMessage(from: message)
                self.fail(OAuthError.serverError(fallback))
            }
        }

        do {
            try process.run()
            loginProcess = process
        } catch {
            fail(error)
        }
    }

    func cancel() {
        loginProcess?.terminate()
        cleanupTemporaryLoginHome()
        loginProcess = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        isAuthenticating = false
        completionHandler = nil
    }

    private func handleCLIOutput(_ chunk: String) {
        capturedOutput += chunk

        guard !didPresentDeviceAuthPrompt,
              let instructions = Self.extractDeviceAuthInstructions(from: capturedOutput) else { return }

        didPresentDeviceAuthPrompt = true
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(instructions.code, forType: .string)
            NSWorkspace.shared.open(instructions.url)

            let alert = NSAlert()
            alert.messageText = L.deviceAuthTitle
            alert.informativeText = L.deviceAuthPrompt(instructions.code)
            alert.alertStyle = .informational
            alert.addButton(withTitle: L.gotIt)
            alert.addButton(withTitle: L.openChatGPTSettings)
            let response = alert.runModal()
            if response == .alertSecondButtonReturn, let settingsURL = self.chatGPTSettingsURL {
                NSWorkspace.shared.open(settingsURL)
            }
        }
    }

    private func finish(_ result: Result<OAuthTokens, Error>) {
        DispatchQueue.main.async {
            self.cleanupTemporaryLoginHome()
            self.isAuthenticating = false
            self.completionHandler?(result)
            self.completionHandler = nil
        }
    }

    private func fail(_ error: Error) {
        DispatchQueue.main.async {
            self.cleanupTemporaryLoginHome()
            self.isAuthenticating = false
            self.errorMessage = error.localizedDescription
            self.completionHandler?(.failure(error))
            self.completionHandler = nil
        }
    }

    private func cleanupTemporaryLoginHome() {
        if let loginHomeURL {
            try? FileManager.default.removeItem(at: loginHomeURL)
        }
        loginHomeURL = nil
    }

    private func localizedFailureMessage(from output: String) -> String {
        guard !output.isEmpty else {
            return "Codex 登录未成功完成"
        }

        let lowered = output.lowercased()
        if lowered.contains("device code authorization")
            || output.contains("ChatGPT 安全设置")
            || output.contains("设备代码授权")
            || lowered.contains("security settings") {
            return L.deviceAuthSecurityBlocked
        }

        return output
    }

    static func extractDeviceAuthInstructions(from output: String) -> DeviceAuthInstructions? {
        guard let urlMatch = output.range(of: #"https://auth\.openai\.com/codex/device"#, options: .regularExpression),
              let codeMatch = output.range(of: #"[A-Z0-9]{4,}-[A-Z0-9]{4,}"#, options: .regularExpression) else {
            return nil
        }

        let urlString = String(output[urlMatch])
        let code = String(output[codeMatch])

        guard let url = URL(string: urlString) else { return nil }
        return DeviceAuthInstructions(url: url, code: code)
    }

    static func readTokens(fromAuthFile url: URL) -> OAuthTokens? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              let refreshToken = tokens["refresh_token"] as? String,
              let idToken = tokens["id_token"] as? String else {
            return nil
        }

        return OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken
        )
    }
}

struct OAuthTokens {
    let accessToken: String
    let refreshToken: String
    let idToken: String
}

struct DeviceAuthInstructions {
    let url: URL
    let code: String
}

enum OAuthError: LocalizedError {
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .serverError(let msg):
            return "授权失败: \(msg)"
        }
    }
}
