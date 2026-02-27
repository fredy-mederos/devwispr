//
//  AVAudioRecorderService.swift
//  DevWispr
//

import AVFoundation
import Combine
import Foundation

final class AVAudioRecorderService: NSObject, AudioRecorder {
    // Mutable so it can be recreated when the engine enters an irrecoverable
    // zombie state (e.g. after multiple rapid Bluetooth route changes that
    // leave the HAL IO thread stale).
    private var engine = AVAudioEngine()
    private var outputFile: AVAudioFile?
    private var recordingURL: URL?
    private var isRecordingActive: Bool = false
    private(set) var isEngineRunning: Bool = false
    private var preRollBuffers: [AVAudioPCMBuffer] = []
    private var preRollFrameCount: AVAudioFrameCount = 0
    private let preRollDuration: TimeInterval = 1.0
    private let lock = NSLock()

    // MARK: - AudioRecorder typed publishers
    private let _audioLevelSubject = PassthroughSubject<Double, Never>()
    private let _recordingReadySubject = PassthroughSubject<Void, Never>()
    private let _recordingStoppedSubject = PassthroughSubject<Void, Never>()

    var audioLevelPublisher: AnyPublisher<Double, Never> {
        _audioLevelSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    var recordingReadyPublisher: AnyPublisher<Void, Never> {
        _recordingReadySubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    var recordingStoppedPublisher: AnyPublisher<Void, Never> {
        _recordingStoppedSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    // Timestamp of the most recent tap callback — used to detect a zombie
    // engine that claims to be running but isn't delivering audio (e.g. after
    // a Bluetooth route change where the HAL proxy hasn't fully recovered).
    // Written on the audio tap thread and read on the main thread, so all
    // access is serialised through `lock`.
    private var _lastTapTime: Date?
    private var lastTapTime: Date? {
        get { lock.lock(); defer { lock.unlock() }; return _lastTapTime }
        set { lock.lock(); defer { lock.unlock() }; _lastTapTime = newValue }
    }
    // Incremented each time the engine is recreated. Pending retry closures
    // capture the generation at scheduling time and bail if it has changed,
    // so stale retries from the old engine don't interfere with the new one.
    private var engineGeneration: Int = 0
    // Periodic timer that checks whether the tap is still delivering buffers.
    // If the engine enters a zombie state (isRunning=true but no audio),
    // the timer detects it and triggers full engine recreation.
    private var healthCheckTimer: Timer?
    // Timer that stops the engine after an idle timeout to release the microphone.
    private var napTimer: Timer?
    // Set to true when the engine is intentionally stopped (napping). Prevents
    // the route-change recovery path from restarting an engine we chose to stop.
    private var isNapping: Bool = false

    private(set) var isRecording: Bool = false
    private var recordingStartTime: Date?

    func startEngine() throws {
        cancelEngineNap()
        isNapping = false
        guard !isEngineRunning else { return }

        try startEngineInternal()
        registerEngineObserver()
    }

    // Register the configuration-change observer on whatever engine instance
    // is current. Called after startEngine() and after engine recreation.
    private func registerEngineObserver() {
        NotificationCenter.default.removeObserver(self, name: .AVAudioEngineConfigurationChange, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEngineConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
    }

    private func startEngineInternal() throws {
        let input = engine.inputNode

        // Always remove any existing tap first. If a previous startEngineInternal()
        // call failed after installTap but before/during engine.start(), or if a
        // retry fires without a preceding removeTap, calling installTap again
        // crashes with "nullptr == Tap()".
        input.removeTap(onBus: 0)

        // Pass nil for the format so AVAudioEngine uses the hardware's native
        // format directly. Specifying a format explicitly causes a mismatch
        // error after route changes (e.g. AirPods connecting/negotiating a new
        // sample rate like 24000 Hz).
        input.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            guard let self else { return }
            self.handleTap(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
        isEngineRunning = true
        let fmt = engine.inputNode.outputFormat(forBus: 0)
        infoLog("Audio engine started (gen \(engineGeneration)) — format: \(fmt.sampleRate) Hz, \(fmt.channelCount) ch, isRunning=\(engine.isRunning)")
        startHealthCheckTimer()
    }

    @objc private func handleEngineConfigurationChange(_ notification: Notification) {
        // The engine has already stopped itself at this point.
        // Per Apple docs, do NOT deallocate the engine from this callback.
        debugLog("AVAudioEngineConfigurationChange received (gen \(engineGeneration)) — isRunning=\(engine.isRunning), lastTapTime=\(lastTapTime?.description ?? "nil")")
        // Do NOT cancel the nap timer here. If a nap was scheduled (or already
        // fired), we want it to remain active so the mic is still released after
        // recovery. Cancelling it here would leave the engine running forever
        // after route changes (e.g. AirPods connect/disconnect).
        isEngineRunning = false
        lastTapTime = nil
        engine.inputNode.removeTap(onBus: 0)

        // Debounce: wait a short moment so rapid successive notifications
        // (common during Bluetooth reconnection) collapse into one recovery.
        // The recreation path handles the case where the engine instance is
        // truly irrecoverable (stale HAL IO thread after AirPods close/reopen).
        let gen = engineGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.engineGeneration == gen, !self.isEngineRunning else { return }
            self.recoverEngine()
        }
    }

    // Attempt a fast in-place restart first. If that fails, tear the instance
    // down and create a fresh one. The continuous health-check timer will detect
    // a zombie engine (started OK but tap goes silent) and trigger recreation.
    private func recoverEngine() {
        guard !isNapping else {
            debugLog("Engine recovery skipped — engine is intentionally napping")
            return
        }
        debugLog("Attempting in-place engine restart (gen \(engineGeneration))…")
        do {
            try startEngineInternal()
            debugLog("In-place restart succeeded — waiting for health check timer to confirm")
        } catch {
            debugLog("In-place restart failed: \(error) — recreating engine")
            recreateEngine()
        }
    }

    // Tear down the current engine instance and create a brand-new one.
    // This is the nuclear option for when the HAL IO thread is stale and
    // no amount of stop/start on the same instance will fix it.
    private func recreateEngine() {
        debugLog("Recreating AVAudioEngine (gen \(engineGeneration) → \(engineGeneration + 1))")

        // Do NOT cancel the nap timer here — if one is pending, we want it to
        // fire and stop the engine after recovery too.
        stopHealthCheckTimer()

        // Detach observer from the dying instance before replacing it.
        NotificationCenter.default.removeObserver(self, name: .AVAudioEngineConfigurationChange, object: engine)

        // Stop and clean up the old instance while we still hold a reference.
        // Do this on the main thread (we already are) so it's not inside the
        // notification callback (Apple's constraint).
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }

        // Replace the instance — the old one will be released here.
        engineGeneration += 1
        engine = AVAudioEngine()
        isEngineRunning = false
        lastTapTime = nil

        // Bluetooth devices need time for the HAL proxy to settle after the
        // route change before the new engine can start successfully.
        restartEngineWithRetry(attempts: 6, delay: 1.0, generation: engineGeneration)
    }

    // MARK: - Health check timer

    private func startHealthCheckTimer() {
        stopHealthCheckTimer()
        let gen = engineGeneration
        // Check every 3 s. The tap fires ~46 times/sec at 48 kHz / 1024 frames,
        // so 3 s without a buffer means the engine is definitely dead.
        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self, self.engineGeneration == gen else { return }
            guard self.isEngineRunning else { return }
            if !self.isEngineHealthy {
                debugLog("Health check: engine (gen \(gen)) not delivering audio — recreating")
                self.recreateEngine()
            } else {
                let age = self.lastTapTime.map { Date().timeIntervalSince($0) } ?? -1
                debugLog("Health check: engine (gen \(gen)) OK — lastTapAge=\(String(format: "%.2f", age))s")
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        healthCheckTimer = timer
        debugLog("Health check timer started (gen \(gen))")
    }

    private func stopHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    // MARK: - Engine Nap (idle mic release)

    /// Schedules the engine to stop after the idle timeout, releasing the microphone.
    /// Cancels any previously scheduled nap. No-op if the timeout is 0.
    private func scheduleEngineNap() {
        cancelEngineNap()
        let timeout = AppConfig.engineIdleTimeoutSeconds
        guard timeout > 0 else { return }

        debugLog("Engine nap scheduled in \(timeout)s")
        let timer = Timer(timeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            guard !self.isRecording else { return }
            infoLog("Engine idle timeout expired — stopping engine to release microphone")
            self.isNapping = true
            self.stopEngine()
        }
        RunLoop.main.add(timer, forMode: .common)
        napTimer = timer
    }

    /// Cancels any pending nap, keeping the engine running.
    private func cancelEngineNap() {
        if napTimer != nil {
            debugLog("Engine nap cancelled")
        }
        napTimer?.invalidate()
        napTimer = nil
    }

    private func restartEngineWithRetry(attempts: Int, delay: TimeInterval, generation: Int) {
        debugLog("Scheduling engine restart in \(delay)s (gen \(generation), attempts remaining: \(attempts))")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.engineGeneration == generation, !self.isEngineRunning else {
                debugLog("Engine restart skipped — generation changed or already running")
                return
            }
            guard !self.isNapping else {
                debugLog("Engine restart skipped — engine is intentionally napping")
                return
            }
            debugLog("Attempting engine restart (gen \(generation), attempts remaining: \(attempts))…")
            do {
                try self.startEngineInternal()
                // Re-register so we continue to track future route changes on this instance.
                self.registerEngineObserver()
                debugLog("Engine restart succeeded (gen \(generation)) — healthy=\(self.isEngineHealthy), isRunning=\(self.engine.isRunning)")
            } catch {
                debugLog("Engine restart attempt failed (gen \(generation), \(attempts) left): \(error)")
                if attempts > 1 {
                    self.restartEngineWithRetry(attempts: attempts - 1, delay: delay + 0.5, generation: generation)
                } else {
                    // All retry attempts exhausted. The HAL may still be
                    // settling (e.g. after a long sleep/wake or coreaudiod
                    // restart). Schedule a full recreation after 30 s so the
                    // app can self-heal without requiring a relaunch.
                    debugLog("All restart attempts failed (gen \(generation)) — will retry via full recreation in 30 s")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
                        guard let self, self.engineGeneration == generation, !self.isEngineRunning else { return }
                        debugLog("30 s recovery: recreating engine (gen \(generation))")
                        self.recreateEngine()
                    }
                }
            }
        }
    }

    func stopEngine() {
        cancelEngineNap()
        stopHealthCheckTimer()
        NotificationCenter.default.removeObserver(self, name: .AVAudioEngineConfigurationChange, object: nil)
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        isEngineRunning = false

        lock.lock()
        preRollBuffers.removeAll()
        preRollFrameCount = 0
        lock.unlock()

        debugLog("Audio engine stopped")
    }

    /// Returns true if the engine is running AND the tap has delivered a buffer
    /// recently, confirming the HAL is actually providing audio data.
    var isEngineHealthy: Bool {
        guard isEngineRunning else { return false }
        guard let last = lastTapTime else { return false }
        return Date().timeIntervalSince(last) < 2.0
    }

    func startRecording() throws {
        cancelEngineNap()
        guard !isRecording else { return }

        // Track whether the engine was just started so we can skip the health
        // check on a cold start — the first tap buffer hasn't arrived yet but
        // will within milliseconds, and the pre-roll will simply be empty.
        var coldStart = false
        if !isEngineRunning {
            try startEngine()
            coldStart = true
        }

        let tapAge = lastTapTime.map { Date().timeIntervalSince($0) }
        debugLog("startRecording — isEngineRunning=\(isEngineRunning), engine.isRunning=\(engine.isRunning), lastTapAge=\(tapAge.map { String(format: "%.2fs", $0) } ?? "never"), healthy=\(isEngineHealthy), coldStart=\(coldStart)")

        if !coldStart {
            guard isEngineHealthy else {
                debugLog("Engine not healthy — throwing engineNotReady")
                throw AudioRecorderError.engineNotReady
            }
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        outputFile = try AVAudioFile(forWriting: url, settings: format.settings)
        recordingURL = url
        lock.lock()
        isRecording = true
        lock.unlock()
        recordingStartTime = Date()

        activateRecording()
    }

    func stopRecording() throws -> URL {
        guard isRecording else {
            throw AudioRecorderError.notRecording
        }

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        debugLog("Recording duration: \(String(format: "%.2f", duration))s")
        lock.lock()
        isRecording = false
        isRecordingActive = false
        lock.unlock()
        recordingStartTime = nil

        // Keep engine running briefly for pre-roll on rapid re-recordings,
        // then nap (stop) to release the microphone indicator.
        scheduleEngineNap()

        _recordingStoppedSubject.send()
        guard let url = recordingURL else {
            throw AudioRecorderError.noRecordingURL
        }

        outputFile = nil
        recordingURL = nil
        return url
    }

    private func handleTap(buffer: AVAudioPCMBuffer) {
        let copy = copyBuffer(buffer)

        lock.lock()
        let wasNil = _lastTapTime == nil
        _lastTapTime = Date()
        let shouldWrite = isRecordingActive

        if !shouldWrite {
            // Not actively recording — fill pre-roll buffer
            preRollBuffers.append(copy)
            preRollFrameCount += copy.frameLength
            trimPreRoll(for: buffer.format)
        } else {
            // Serialize all writes under the lock so they cannot interleave
            // with pre-roll flushes happening on the main thread.
            do {
                try outputFile?.write(from: copy)
            } catch {
                // Recording write errors are surfaced on stop.
            }
        }
        lock.unlock()

        if wasNil {
            infoLog("First tap buffer received — engine is delivering audio (\(buffer.format.sampleRate) Hz, \(buffer.format.channelCount) ch)")
        }

        let level = rmsLevel(buffer)
        _audioLevelSubject.send(level)
    }

    private func activateRecording() {
        lock.lock()
        guard isRecording else {
            lock.unlock()
            return
        }
        isRecordingActive = true
        _recordingReadySubject.send()
        let buffers = preRollBuffers
        preRollBuffers.removeAll()
        preRollFrameCount = 0
        let file = outputFile

        // Flush pre-roll buffers while still holding the lock so that
        // concurrent tap writes cannot interleave with these writes.
        // AVAudioFile is not thread-safe, so all writes must be serialised.
        debugLog("Flushing \(buffers.count) pre-roll buffers to recording file")
        for buffer in buffers {
            do {
                try file?.write(from: buffer)
            } catch {
                // Recording write errors are surfaced on stop.
            }
        }
        lock.unlock()
    }

    private func trimPreRoll(for format: AVAudioFormat) {
        let maxFrames = AVAudioFrameCount(format.sampleRate * preRollDuration)
        while preRollFrameCount > maxFrames, !preRollBuffers.isEmpty {
            let removed = preRollBuffers.removeFirst()
            preRollFrameCount = max(0, preRollFrameCount - removed.frameLength)
        }
    }

    private func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) ?? buffer
        copy.frameLength = buffer.frameLength
        if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
            let channels = Int(buffer.format.channelCount)
            let frames = Int(buffer.frameLength)
            for channel in 0..<channels {
                dst[channel].assign(from: src[channel], count: frames)
            }
        }
        return copy
    }

    private func rmsLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let data = buffer.floatChannelData else { return 0 }
        let channel = data[0]
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frames {
            let v = channel[i]
            sum += v * v
        }
        let rms = sqrt(sum / Float(frames))
        return Double(min(max(rms * 4, 0), 1))
    }
}
