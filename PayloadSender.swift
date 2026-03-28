import Foundation
import Network
import Combine

@MainActor
class PayloadSender: ObservableObject {
    @Published var isSending = false
    @Published var log: [String] = []

    func send(to host: String, port: UInt16, fileURL: URL) {
        guard !isSending else { return }
        isSending = true
        log.append("⚡ Connecting to \(host):\(port)…")

        Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performSend(host: host, port: port, fileURL: fileURL)
        }
    }

    private func performSend(host: String, port: UInt16, fileURL: URL) async {
        defer {
            Task { @MainActor [weak self] in self?.isSending = false }
        }

        // Load payload
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
            await appendLog("📦 Loaded \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
        } catch {
            await appendLog("❌ Read failed: \(error.localizedDescription)")
            return
        }

        // Connect
        let nwHost = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            await appendLog("❌ Invalid port")
            return
        }

        let conn = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        let connected = await withCheckedContinuation { cont in
            var resumed = false
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !resumed { resumed = true; cont.resume(returning: true) }
                case .failed(let err), .waiting(let err):
                    if !resumed { resumed = true; cont.resume(returning: false) }
                    Task { [weak self] in await self?.appendLog("❌ \(err.localizedDescription)") }
                default: break
                }
            }
            conn.start(queue: .global(qos: .userInitiated))
            // Timeout
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !resumed { resumed = true; cont.resume(returning: false) }
            }
        }

        guard connected else {
            await appendLog("❌ Connection failed — is the PS5 in payload mode?")
            conn.cancel()
            return
        }

        await appendLog("✅ Connected — sending \(data.count) bytes…")

        // Send
        let sent = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error {
                    Task { [weak self] in await self?.appendLog("❌ Send error: \(error.localizedDescription)") }
                    cont.resume(returning: false)
                } else {
                    cont.resume(returning: true)
                }
            })
        }

        if sent {
            await appendLog("✅ Payload sent successfully!")
        }

        conn.cancel()
    }

    private func appendLog(_ msg: String) async {
        await MainActor.run { log.append(msg) }
    }
}
