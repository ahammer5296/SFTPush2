import Cocoa
#if canImport(mft)
import mft
#endif

final class SFTPSettingsViewController: NSViewController {
    private let prefs = Preferences.shared

    private let hostField = NSTextField()
    private let portField = NSTextField()
    private let userField = NSTextField()
    private let passwordField = NSSecureTextField()
    private let remotePathField = NSTextField()
    private let baseURLField = NSTextField()
    private let testButton = NSButton(title: L("settings.sftp.test_connection"), target: nil, action: nil)

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        load()
        wire()
        // Live updates while typing to avoid losing values if user doesn't press Enter
        hostField.delegate = self
        portField.delegate = self
        userField.delegate = self
        passwordField.delegate = self
        remotePathField.delegate = self
        baseURLField.delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(onTextChanged(_:)), name: NSControl.textDidChangeNotification, object: hostField)
        NotificationCenter.default.addObserver(self, selector: #selector(onTextChanged(_:)), name: NSControl.textDidChangeNotification, object: portField)
        NotificationCenter.default.addObserver(self, selector: #selector(onTextChanged(_:)), name: NSControl.textDidChangeNotification, object: userField)
        NotificationCenter.default.addObserver(self, selector: #selector(onTextChanged(_:)), name: NSControl.textDidChangeNotification, object: passwordField)
        NotificationCenter.default.addObserver(self, selector: #selector(onTextChanged(_:)), name: NSControl.textDidChangeNotification, object: remotePathField)
        NotificationCenter.default.addObserver(self, selector: #selector(onTextChanged(_:)), name: NSControl.textDidChangeNotification, object: baseURLField)
    }

    private func row(_ title: String, field: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        // Fix label width so all fields start at same X
        label.widthAnchor.constraint(equalToConstant: 140).isActive = true

        field.translatesAutoresizingMaskIntoConstraints = false
        // Let field stretch to take remaining space
        if let c = (field as? NSControl) {
            c.setContentHuggingPriority(.defaultLow, for: .horizontal)
            c.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        let row = NSStackView(views: [label, field])
        row.spacing = 8
        row.alignment = .firstBaseline
        row.distribution = .fill
        return row
    }

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        hostField.placeholderString = L("settings.sftp.host.placeholder")
        portField.placeholderString = "22"
        userField.placeholderString = L("settings.sftp.username.placeholder")
        passwordField.placeholderString = String(repeating: "•", count: 8)
        remotePathField.placeholderString = "/files"
        baseURLField.placeholderString = "https://example.com/"

        testButton.bezelStyle = .rounded
        // Title correction and make the button visually shorter
        testButton.title = "Тест соединения"
        testButton.controlSize = .small

        stack.addArrangedSubview(row(L("settings.sftp.host"), field: hostField))
        stack.addArrangedSubview(row(L("settings.sftp.port"), field: portField))
        stack.addArrangedSubview(row(L("settings.sftp.username"), field: userField))
        stack.addArrangedSubview(row(L("settings.sftp.password"), field: passwordField))
        stack.addArrangedSubview(row(L("settings.sftp.folder"), field: remotePathField))
        stack.addArrangedSubview(row(L("settings.sftp.base_url"), field: baseURLField))

        let buttonRow = NSStackView(views: [testButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        stack.addArrangedSubview(buttonRow)

        view.addSubview(stack)
        // Equalize widths of all input fields and align them visually on the right
        NSLayoutConstraint.activate([
            hostField.widthAnchor.constraint(equalTo: portField.widthAnchor),
            hostField.widthAnchor.constraint(equalTo: userField.widthAnchor),
            hostField.widthAnchor.constraint(equalTo: passwordField.widthAnchor),
            hostField.widthAnchor.constraint(equalTo: remotePathField.widthAnchor),
            hostField.widthAnchor.constraint(equalTo: baseURLField.widthAnchor),
            // Make the button half the stack width and centered
            testButton.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.5),
            testButton.centerXAnchor.constraint(equalTo: stack.centerXAnchor)
        ])

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -24)
        ])
    }

    private func wire() {
        hostField.target = self; hostField.action = #selector(onHost)
        portField.target = self; portField.action = #selector(onPort)
        userField.target = self; userField.action = #selector(onUser)
        passwordField.target = self; passwordField.action = #selector(onPassword)
        remotePathField.target = self; remotePathField.action = #selector(onRemotePath)
        baseURLField.target = self; baseURLField.action = #selector(onBaseURL)
        testButton.target = self; testButton.action = #selector(onTest)
    }

    private func load() {
        hostField.stringValue = prefs.sftpHost
        portField.stringValue = String(prefs.sftpPort)
        userField.stringValue = prefs.sftpUsername
        passwordField.stringValue = prefs.sftpPassword
        remotePathField.stringValue = prefs.sftpRemotePath
        baseURLField.stringValue = prefs.sftpBaseURL
    }

    // MARK: - Actions
    @objc private func onHost() { prefs.sftpHost = hostField.stringValue }
    @objc private func onPort() { prefs.sftpPort = Int(portField.stringValue) ?? 22; portField.stringValue = String(prefs.sftpPort) }
    @objc private func onUser() { prefs.sftpUsername = userField.stringValue }
    @objc private func onPassword() { prefs.sftpPassword = passwordField.stringValue }
    @objc private func onRemotePath() { prefs.sftpRemotePath = remotePathField.stringValue }
    @objc private func onBaseURL() { prefs.sftpBaseURL = baseURLField.stringValue }
    @objc private func onTest() {
        let host = prefs.sftpHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = prefs.sftpUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = prefs.sftpPort
        let password = prefs.sftpPassword

        let originalTitle = testButton.title
        testButton.isEnabled = false

        func showResult(_ title: String) {
            self.testButton.title = title
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.testButton.title = originalTitle
                self.testButton.isEnabled = true
            }
        }

        // Quick input validation before attempting network
        guard !host.isEmpty, !user.isEmpty, !password.isEmpty else {
            showResult("Error Connection!")
            return
        }

        #if canImport(mft)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var ok = false
            do {
                let conn = MFTSftpConnection(hostname: host, port: port, username: user, password: password)
                do { try conn.connect() } catch { throw NSError(domain: "mft.connect", code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]) }
                do { try conn.authenticate() } catch { throw NSError(domain: "mft.auth", code: -2, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]) }
                ok = true
                conn.disconnect()
            } catch {
                ok = false
            }
            DispatchQueue.main.async {
                showResult(ok ? "Connection OK" : "Error Connection!")
            }
        }
        #else
        // No mft in this build: simulate as not available
        showResult("Error Connection!")
        #endif
    }
}

extension SFTPSettingsViewController: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        // Ensure final value is saved on end editing
        syncFieldToPreferences(obj.object as? NSTextField)
    }
    @objc private func onTextChanged(_ note: Notification) {
        syncFieldToPreferences(note.object as? NSTextField)
    }
    private func syncFieldToPreferences(_ field: NSTextField?) {
        guard let field = field else { return }
        switch field {
        case hostField:
            prefs.sftpHost = hostField.stringValue
        case portField:
            let trimmed = portField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let v = Int(trimmed), v > 0 { prefs.sftpPort = v }
        case userField:
            prefs.sftpUsername = userField.stringValue
        case passwordField:
            prefs.sftpPassword = passwordField.stringValue
        case remotePathField:
            prefs.sftpRemotePath = remotePathField.stringValue
        case baseURLField:
            prefs.sftpBaseURL = baseURLField.stringValue
        default:
            break
        }
    }
}
