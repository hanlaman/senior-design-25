//
//  WebSocketManager.swift
//  reMIND Watch App
//
//  WebSocket connection manager using URLSessionWebSocketTask.
//
//  Network path strategy:
//  - connect() requires a live WiFi path before opening the socket.
//    NWPathMonitor(requiredInterfaceType: .wifi) is used to gate the connection;
//    if WiFi is not available within the check timeout, connect() throws a clear error
//    instead of silently falling through to the iPhone Bluetooth relay.
//  - URLSession is used (not NWConnection) because URLSession handles TLS upgrade and
//    HTTP/1.1 WebSocket negotiation correctly on watchOS without requiring manual framing.
//  - Per Apple TN3135, an active AVAudioSession must be held before the socket is opened
//    on watchOS. The caller (VoiceConnectionCoordinator) activates audio before connecting.
//

import Foundation
import Network
import os

/// WebSocket connection manager using URLSessionWebSocketTask
actor WebSocketManager {
    // MARK: - Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var delegateHandler: WebSocketDelegateHandler?

    private let url: URL
    private let apiKey: String

    private var isConnected = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = WebSocketConfiguration.maxReconnectAttempts

    // Event stream
    private var eventContinuation: AsyncStream<Result<Data, Error>>.Continuation?
    let eventStream: AsyncStream<Result<Data, Error>>

    // Connection state stream (for propagating state to VoiceLiveConnection)
    private var connectionStateContinuation: AsyncStream<ConnectionState>.Continuation?
    let connectionStateStream: AsyncStream<ConnectionState>

    // Heartbeat tracking
    private var heartbeatTask: Task<Void, Never>?
    private var lastMessageTime = Date()
    private var receiveTask: Task<Void, Never>?

    // MARK: - Initialization

    init(url: URL, apiKey: String) {
        self.url = url
        self.apiKey = apiKey

        // Create event stream
        var eventContinuationHolder: AsyncStream<Result<Data, Error>>.Continuation?
        self.eventStream = AsyncStream { continuation in
            eventContinuationHolder = continuation
        }
        self.eventContinuation = eventContinuationHolder

        // Create connection state stream
        var stateContinuationHolder: AsyncStream<ConnectionState>.Continuation?
        self.connectionStateStream = AsyncStream { continuation in
            stateContinuationHolder = continuation
        }
        self.connectionStateContinuation = stateContinuationHolder
    }

    // MARK: - Connection Management

    /// Connect to WebSocket and wait for handshake to complete
    func connect() async throws {
        guard !isConnected else {
            AppLogger.network.warning("Already connected to WebSocket")
            return
        }

        AppLogger.network.info("Connecting to WebSocket: \(self.url.absoluteString)")
        connectionStateContinuation?.yield(.connecting)

        guard url.host != nil else {
            throw WebSocketError.invalidURL("Missing host in URL")
        }

        // Require WiFi before opening the socket. This prevents the system from silently
        // routing through the iPhone Bluetooth relay (companion tunnel) when the watch is
        // on WiFi but the relay path is selected first. Fails fast with a clear error if
        // WiFi is not available within the check timeout.
        try await requireWiFiPath()

        // Build URLRequest with API key header
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        request.timeoutInterval = WebSocketConfiguration.connectionTimeout

        // Configure URLSession for watchOS.
        // waitsForConnectivity = false: fail fast so the caller can surface a clear
        // error and retry rather than hanging indefinitely on a bad path.
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = WebSocketConfiguration.connectionTimeout
        config.timeoutIntervalForResource = WebSocketConfiguration.resourceTimeout
        config.waitsForConnectivity = false

        // .default service type is required — .responsiveData marks the WiFi path as
        // "expensive" on some watchOS versions and causes URLSession to reject it.
        config.networkServiceType = .default

        config.allowsCellularAccess = true
        if #available(watchOS 9.0, *) {
            config.allowsConstrainedNetworkAccess = true
            config.allowsExpensiveNetworkAccess = true
        }

        // Note: shouldUseExtendedBackgroundIdleMode is intentionally not set.
        // It requires background mode entitlements, and on watchOS it can cause
        // the system to reject connections when those entitlements are missing.

        // Create delegate handler, session, and task
        let delegate = WebSocketDelegateHandler()
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let task = session.webSocketTask(with: request)

        self.delegateHandler = delegate
        self.urlSession = session
        self.webSocketTask = task

        // Set up post-connection delegate handlers before resuming.
        // These detect connection loss after the connection is established.
        delegate.onClose = { [weak self] closeCode, reason in
            let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
            AppLogger.network.warning("WebSocket closed: code=\(closeCode.rawValue), reason=\(reasonStr)")
            Task { [weak self] in
                await self?.handleConnectionLost()
            }
        }
        delegate.onTaskComplete = { [weak self] error in
            if let error = error {
                AppLogger.network.error("WebSocket task error: \(error.localizedDescription)")
                Task { [weak self] in
                    await self?.handleConnectionLost()
                }
            }
        }

        // Start connection
        task.resume()

        // Verify connection by receiving the first message with a timeout.
        // Azure sends session.created immediately on WebSocket connect, so a
        // successful receive proves the connection is live. This is more reliable
        // than the didOpenWithProtocol delegate, which doesn't fire on watchOS.
        let firstMessage: Data
        do {
            firstMessage = try await withThrowingTaskGroup(of: Data.self) { group in
                group.addTask {
                    try await self.receiveMessage()
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(WebSocketConfiguration.connectionTimeout * 1_000_000_000))
                    throw WebSocketError.connectionFailed(
                        NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection timed out waiting for first message"])
                    )
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } catch {
            AppLogger.network.error("WebSocket connect failed: \(error.localizedDescription)")
            task.cancel(with: .goingAway, reason: nil)
            session.invalidateAndCancel()
            self.webSocketTask = nil
            self.urlSession = nil
            self.delegateHandler = nil
            throw error
        }

        // Connection is now established
        isConnected = true
        reconnectAttempts = 0
        lastMessageTime = Date()

        connectionStateContinuation?.yield(.connected)
        AppLogger.network.info("WebSocket connected via URLSession")

        // Deliver the first message (session.created) into the event stream
        handleReceivedData(firstMessage)

        // Start receiving remaining messages and heartbeat
        startReceiving()
        startHeartbeat()
    }

    /// Disconnect from WebSocket
    /// - Parameter preserveEventStream: If true, keeps the event stream alive for reconnection
    func disconnect(preserveEventStream: Bool = false) async {
        AppLogger.network.info("Disconnecting from WebSocket")

        // Cancel tasks
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil

        // Clear delegate closures to prevent callbacks during teardown
        delegateHandler?.onClose = nil
        delegateHandler?.onTaskComplete = nil

        // Send close frame and cancel task
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        // Invalidate URLSession to break strong delegate reference cycle
        urlSession?.invalidateAndCancel()
        urlSession = nil
        delegateHandler = nil

        isConnected = false

        connectionStateContinuation?.yield(.disconnected)

        // Only finish the event stream if not preserving for reconnection
        if !preserveEventStream {
            eventContinuation?.finish()
        }

        AppLogger.network.info("WebSocket disconnected (preserveEventStream: \(preserveEventStream))")
    }

    /// Send data over WebSocket
    func send(_ data: Data) async throws {
        guard isConnected, let task = webSocketTask else {
            throw WebSocketError.notConnected
        }

        do {
            try await task.send(.data(data))
        } catch {
            AppLogger.logError(error, category: AppLogger.network, context: "WebSocket send (data) failed")
            throw WebSocketError.sendFailed(error)
        }
    }

    /// Send text over WebSocket
    func send(_ text: String) async throws {
        guard isConnected, let task = webSocketTask else {
            throw WebSocketError.notConnected
        }

        do {
            try await task.send(.string(text))
        } catch {
            AppLogger.logError(error, category: AppLogger.network, context: "WebSocket send (text) failed")
            throw WebSocketError.sendFailed(error)
        }
    }

    // MARK: - Connection State Handling

    /// Called when delegate reports connection lost or receive loop detects failure
    private func handleConnectionLost() async {
        guard isConnected else { return }
        isConnected = false
        connectionStateContinuation?.yield(.disconnected)
        eventContinuation?.yield(.failure(WebSocketError.connectionFailed(
            NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection lost"])
        )))

        // Attempt automatic reconnection
        await attemptReconnection()
    }

    // MARK: - Private Methods

    /// Waits until a usable network path is available, or throws if none arrives within the timeout.
    ///
    /// On watchOS, direct WiFi can be reported as either `.wifi` OR `.other` by the Network
    /// framework depending on the hardware and OS version. Using
    /// `NWPathMonitor(requiredInterfaceType: .wifi)` is therefore too strict — it never fires
    /// on devices where WiFi registers as `.other`, blocking the connection entirely.
    ///
    /// Instead we use an unrestricted `NWPathMonitor` and accept any satisfied path that uses
    /// `.wifi` or `.other` (both indicate a direct local-network connection on watchOS).
    /// Pure cellular-only paths are rejected since Azure latency over cellular is unreliable
    /// for a real-time audio WebSocket.
    ///
    /// URLSession naturally prefers the fastest available path, so when WiFi and the Bluetooth
    /// relay are both present the socket will open over WiFi.
    private func requireWiFiPath() async throws {
        let timeout = WebSocketConfiguration.wifiPathCheckTimeout

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Unrestricted monitor — we inspect the interface types ourselves below.
            let monitor = NWPathMonitor()
            // OSAllocatedUnfairLock guards the single-resume invariant: the monitor
            // callback and the timeout task can both fire; only the first should resume.
            let lock = OSAllocatedUnfairLock(initialState: false)

            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                lock.withLock { alreadyResumed in
                    guard !alreadyResumed else { return }
                    alreadyResumed = true
                    monitor.cancel()
                    AppLogger.network.error("No usable network path within \(timeout)s — watch may not be on WiFi")
                    continuation.resume(throwing: WebSocketError.wifiNotAvailable)
                }
            }

            monitor.pathUpdateHandler = { path in
                guard path.status == .satisfied else { return }

                // usesInterfaceType() only returns true when that interface is the *active*
                // path interface. On a cellular Watch with WiFi connected, the unrestricted
                // monitor can return a path where cellular is active, causing usesInterfaceType(.wifi)
                // to return false even though WiFi IS available. The monitor won't re-fire because
                // the path hasn't changed, so we'd time out incorrectly.
                //
                // availableInterfaces lists every connected interface on the path (active or not),
                // so it correctly reflects that WiFi is present even when cellular is primary.
                // On watchOS, WiFi can appear as .wifi or .other depending on hardware/OS version.
                let availableTypes = Set(path.availableInterfaces.map { $0.type })
                let hasWifi = availableTypes.contains(.wifi)
                let hasOther = availableTypes.contains(.other)
                guard hasWifi || hasOther else {
                    let ifaceNames = path.availableInterfaces.map { $0.name }.joined(separator: ", ")
                    AppLogger.network.debug("Path satisfied but no WiFi/.other in available interfaces [\(ifaceNames)] — waiting for WiFi")
                    return
                }

                lock.withLock { alreadyResumed in
                    guard !alreadyResumed else { return }
                    alreadyResumed = true
                    timeoutTask.cancel()
                    monitor.cancel()

                    // Log which interface type was detected to help diagnose per-device behaviour.
                    let ifaceType = hasWifi ? "wifi (.wifi)" : "wifi (.other — watchOS reclassified)"
                    let ifaceNames = path.availableInterfaces.map { $0.name }.joined(separator: ", ")
                    AppLogger.network.info("Network path confirmed via \(ifaceType), interfaces: \(ifaceNames)")
                    continuation.resume()
                }
            }

            monitor.start(queue: DispatchQueue(label: "com.remind.wifi-path-check", qos: .userInitiated))
        }
    }

    private func startReceiving() {
        receiveTask?.cancel()

        receiveTask = Task { [weak self] in
            AppLogger.network.debug("Starting to receive WebSocket messages...")

            while let self = self, await self.isConnected, !Task.isCancelled {
                do {
                    let data = try await self.receiveMessage()
                    await self.handleReceivedData(data)
                } catch {
                    if await self.isConnected && !Task.isCancelled {
                        AppLogger.logError(error, category: AppLogger.network, context: "WebSocket receive failed")
                        await self.eventContinuation?.yield(.failure(error))
                        // Spawn reconnection in a separate task so that disconnect()
                        // cancelling receiveTask doesn't cancel the reconnection itself.
                        Task { [weak self] in
                            await self?.attemptReconnection()
                        }
                    }
                    break
                }
            }
        }
    }

    private func receiveMessage() async throws -> Data {
        guard let task = webSocketTask else {
            throw WebSocketError.notConnected
        }

        let message = try await task.receive()

        switch message {
        case .data(let data):
            return data
        case .string(let text):
            guard let data = text.data(using: .utf8) else {
                throw WebSocketError.receiveFailed(
                    NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode text as UTF-8"])
                )
            }
            return data
        @unknown default:
            throw WebSocketError.receiveFailed(
                NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown message type"])
            )
        }
    }

    private func handleReceivedData(_ data: Data) {
        lastMessageTime = Date()
        eventContinuation?.yield(.success(data))
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()

        heartbeatTask = Task {
            while !Task.isCancelled && isConnected {
                try? await Task.sleep(nanoseconds: UInt64(WebSocketConfiguration.heartbeatInterval * 1_000_000_000))

                guard isConnected && !Task.isCancelled else { break }

                let timeSinceLastMessage = Date().timeIntervalSince(lastMessageTime)
                if timeSinceLastMessage > WebSocketConfiguration.silenceThreshold {
                    AppLogger.network.warning("No messages received in \(WebSocketConfiguration.silenceThreshold)s, connection may be dead")
                    // Spawn in separate task so disconnect() cancelling heartbeatTask
                    // doesn't cancel the reconnection itself.
                    Task { [weak self] in
                        await self?.attemptReconnection()
                    }
                    break
                }

                // Send ping to keep connection alive
                sendPing()
            }
        }
    }

    private func sendPing() {
        guard let task = webSocketTask else { return }

        task.sendPing { error in
            if let error = error {
                AppLogger.network.error("Heartbeat ping failed: \(error.localizedDescription)")
            }
        }
    }

    private func attemptReconnection() async {
        while reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1

            // Emit reconnecting state
            connectionStateContinuation?.yield(.reconnecting(
                attempt: reconnectAttempts,
                maxAttempts: maxReconnectAttempts
            ))

            let delay = min(pow(2.0, Double(reconnectAttempts)), WebSocketConfiguration.maxReconnectDelay)
            AppLogger.network.info("Reconnecting in \(delay)s (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts))")

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            do {
                // Preserve event stream during reconnection so VoiceLiveConnection can keep listening
                await disconnect(preserveEventStream: true)
                try await connect()
                return // Success — exit the loop
            } catch {
                AppLogger.logError(error, category: AppLogger.network, context: "Reconnection failed")
                // Loop continues to next attempt
            }
        }

        // All attempts exhausted
        AppLogger.network.error("Max reconnection attempts reached")
        connectionStateContinuation?.yield(.error("Max reconnection attempts reached"))
        eventContinuation?.yield(.failure(WebSocketError.maxReconnectAttemptsReached))
        await disconnect()
    }

    // MARK: - State

    var connectionState: ConnectionState {
        if isConnected {
            return .connected
        } else if reconnectAttempts > 0 && reconnectAttempts < maxReconnectAttempts {
            return .reconnecting(attempt: reconnectAttempts, maxAttempts: maxReconnectAttempts)
        } else {
            return .disconnected
        }
    }
}

// MARK: - WebSocket Delegate Handler

/// Bridges URLSessionWebSocketDelegate callbacks into actor-isolated closures.
/// Must be a class (not actor) because URLSession delegates are @objc protocols.
final class WebSocketDelegateHandler: NSObject, URLSessionWebSocketDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    // Closures are only mutated from the owning WebSocketManager actor.
    // @unchecked Sendable is safe because mutation is serialized by the actor.
    var onClose: (@Sendable (URLSessionWebSocketTask.CloseCode, Data?) -> Void)?
    var onTaskComplete: (@Sendable (Error?) -> Void)?

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        onClose?(closeCode, reason)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        onTaskComplete?(error)
    }
}

// MARK: - WebSocket Errors

enum WebSocketError: LocalizedError {
    case notConnected
    case invalidURL(String)
    case sendFailed(Error)
    case receiveFailed(Error)
    case maxReconnectAttemptsReached
    case connectionCancelled
    case connectionFailed(Error)
    case connectionClosed(closeCode: URLSessionWebSocketTask.CloseCode, reason: String)
    case wifiNotAvailable

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "WebSocket is not connected"
        case .invalidURL(let detail):
            return "Invalid WebSocket URL: \(detail)"
        case .sendFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        case .receiveFailed(let error):
            return "Failed to receive message: \(error.localizedDescription)"
        case .maxReconnectAttemptsReached:
            return "Maximum reconnection attempts reached"
        case .connectionCancelled:
            return "Connection was cancelled"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .connectionClosed(let closeCode, let reason):
            return "Connection closed: code=\(closeCode.rawValue), reason=\(reason)"
        case .wifiNotAvailable:
            return "WiFi is not available. Connect the watch to WiFi and try again."
        }
    }
}
