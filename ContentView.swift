import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var sender = PayloadSender()
    @State private var ip: String = ""
    @State private var port: String = "9090"
    @State private var showFilePicker = false
    @State private var showIPHistory = false
    @State private var payloadURL: URL? = nil
    @State private var payloadName: String = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // ── Target ──────────────────────────────────
                        GroupBox {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "network")
                                        .foregroundColor(.blue)
                                    Text("Target").font(.headline)
                                    Spacer()
                                    if !RecentIPs.load().isEmpty {
                                        Button {
                                            showIPHistory = true
                                        } label: {
                                            Label("Recent", systemImage: "clock")
                                                .font(.caption)
                                        }
                                    }
                                }

                                TextField("PS5 IP Address", text: $ip)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()

                                HStack {
                                    Text("Port").foregroundColor(.secondary)
                                    Spacer()
                                    TextField("9090", text: $port)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 80)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        } label: {
                            EmptyView()
                        }

                        // ── Payload ──────────────────────────────────
                        GroupBox {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.orange)
                                    Text("Payload").font(.headline)
                                    Spacer()
                                }

                                Button {
                                    showFilePicker = true
                                } label: {
                                    HStack {
                                        Image(systemName: payloadURL == nil ? "plus.circle.dashed" : "checkmark.circle.fill")
                                            .foregroundColor(payloadURL == nil ? .secondary : .green)
                                        Text(payloadURL == nil ? "Select .bin file…" : payloadName)
                                            .foregroundColor(payloadURL == nil ? .secondary : .primary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(8)
                                }

                                if let url = payloadURL {
                                    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                                    HStack {
                                        Text("Size")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                        Spacer()
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                            .font(.caption.monospacedDigit())
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } label: {
                            EmptyView()
                        }

                        // ── Send Button ──────────────────────────────
                        Button {
                            guard let url = payloadURL else { return }
                            RecentIPs.save(ip: ip)
                            sender.send(to: ip, port: UInt16(port) ?? 9090, fileURL: url)
                        } label: {
                            HStack {
                                if sender.isSending {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text(sender.isSending ? "Sending…" : "Send Payload")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSend ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canSend)

                        // ── Status ───────────────────────────────────
                        if !sender.log.isEmpty {
                            GroupBox {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "terminal.fill")
                                            .foregroundColor(.green)
                                        Text("Log").font(.headline)
                                        Spacer()
                                        Button("Clear") { sender.log = [] }
                                            .font(.caption)
                                    }
                                    Divider()
                                    ForEach(sender.log.indices, id: \.self) { i in
                                        Text(sender.log[i])
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(logColor(sender.log[i]))
                                    }
                                }
                            } label: {
                                EmptyView()
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("PS5 Payload Sender")
            .navigationBarTitleDisplayMode(.large)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Security-scoped: keep access alive
                    _ = url.startAccessingSecurityScopedResource()
                    payloadURL = url
                    payloadName = url.lastPathComponent
                }
            case .failure(let err):
                sender.log.append("❌ File error: \(err.localizedDescription)")
            }
        }
        .confirmationDialog("Recent IPs", isPresented: $showIPHistory, titleVisibility: .visible) {
            ForEach(RecentIPs.load(), id: \.self) { saved in
                Button(saved) { ip = saved }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    var canSend: Bool {
        !sender.isSending && !ip.trimmingCharacters(in: .whitespaces).isEmpty && payloadURL != nil
    }

    func logColor(_ line: String) -> Color {
        if line.hasPrefix("✅") { return .green }
        if line.hasPrefix("❌") { return .red }
        if line.hasPrefix("⚡") { return .yellow }
        return .primary
    }
}
