import Foundation

/// Connects to the WeatherFlow real-time WebSocket stream.
/// Delivers `rapid_wind` (~3 s) and `obs_st` (~1 min) observations
/// via callbacks, always on the MainActor.
/// Reconnects with exponential back-off on drop.
@MainActor
final class TempestWebSocketService: NSObject {

    // MARK: - Callbacks

    var onRapidWind: ((_ speedMps: Double, _ directionDeg: Int) -> Void)?
    var onObsSt: ((_ obs: [Double?]) -> Void)?
    var onConnectionChange: ((_ connected: Bool) -> Void)?

    // MARK: - State

    private(set) var isConnected = false
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var active = false
    private var reconnectDelay: TimeInterval = 2
    private var storedToken = ""
    private var storedDeviceId = 0

    // MARK: - Public API

    func connect(token: String, deviceId: Int) {
        guard !token.isEmpty, deviceId > 0 else { return }
        storedToken = token
        storedDeviceId = deviceId
        active = true
        reconnectDelay = 2
        openSocket()
    }

    func disconnect() {
        active = false
        tearDown()
    }

    // MARK: - Socket lifecycle

    private func openSocket() {
        tearDown()
        guard let url = URL(string: "wss://ws.weatherflow.com/swd/data?token=\(storedToken)") else { return }
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        let task = session.webSocketTask(with: url)
        socket = task
        task.resume()
        startReceiveLoop()
        startPingLoop()
    }

    private func tearDown() {
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        if isConnected {
            isConnected = false
            onConnectionChange?(false)
        }
    }

    private func startReceiveLoop() {
        receiveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            await self?.subscribe()
            while !Task.isCancelled {
                guard let self, let socket = self.socket else { break }
                do {
                    let msg = try await socket.receive()
                    self.handle(msg)
                } catch {
                    guard !Task.isCancelled else { break }
                    self.scheduleReconnect()
                    break
                }
            }
        }
    }

    private func subscribe() async {
        let id = storedDeviceId
        try? await socket?.send(.string(#"{"type":"listen_rapid_start","device_id":\#(id)}"#))
        try? await socket?.send(.string(#"{"type":"listen_start","device_id":\#(id)}"#))
    }

    private func startPingLoop() {
        pingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                try? await self?.socket?.send(.string(#"{"type":"ping"}"#))
            }
        }
    }

    // MARK: - Message handling

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type_ = json["type"] as? String else { return }

        switch type_ {
        case "connection_opened":
            isConnected = true
            reconnectDelay = 2
            onConnectionChange?(true)

        case "rapid_wind":
            guard let ob = json["ob"] as? [Any], ob.count >= 3 else { return }
            let speedMps = numericValue(ob[1]) ?? 0
            guard let dir = numericValue(ob[2]).map(Int.init) else { return }
            onRapidWind?(speedMps, dir)

        case "obs_st":
            guard let rows = json["obs"] as? [[Any]], let row = rows.first else { return }
            onObsSt?(row.map { numericValue($0) })

        default:
            break
        }
    }

    private func numericValue(_ v: Any) -> Double? {
        switch v {
        case let d as Double: return d
        case let i as Int:    return Double(i)
        default:              return nil
        }
    }

    // MARK: - Reconnect

    private func scheduleReconnect() {
        guard active else { return }
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 60)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.active else { return }
            self.openSocket()
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension TempestWebSocketService: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Task { @MainActor [weak self] in
            self?.scheduleReconnect()
        }
    }
}
