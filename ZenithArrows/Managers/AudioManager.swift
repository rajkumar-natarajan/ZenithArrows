// AudioManager.swift
// ZenithArrows
//
// Manages background music and sound effects via AVFoundation.
//
// ## Music
//
// - Loops `music_ambient.mp3` at volume 0.35.
// - `fadeOutMusic(duration:)` — smooth fade for level-complete transitions.
// - Music toggle persisted via `zenith_music` UserDefaults key.
//
// ## SFX Events
//
// | Event       | Trigger                           |
// |-------------|-----------------------------------|
// | slide       | Successful arrow tap              |
// | wrongTap    | Invalid tap                       |
// | success     | Level complete                    |
// | failure     | Level failed                      |
// | buttonTap   | Any UI button press               |
// | hint        | Hint or free hint used            |
// | star        | Each star earned in EndLevelView  |
//
// All SFX are pre-loaded at init; missing assets fall back to
// `AudioServicesPlaySystemSound`.
//
// ## Session Category
//
// `.ambient` with `.mixWithOthers` so background music (e.g. Spotify)
// continues playing beneath game audio.

import AVFoundation
import Combine

enum SFXEvent: String {
    case slide      = "sfx_slide"
    case wrongTap   = "sfx_wrong"
    case success    = "sfx_success"
    case failure    = "sfx_failure"
    case buttonTap  = "sfx_tap"
    case hint       = "sfx_hint"
    case star       = "sfx_star"
}

@MainActor
final class AudioManager: ObservableObject {

    static let shared = AudioManager()

    @Published var isMusicEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMusicEnabled, forKey: "zenith_music")
            isMusicEnabled ? resumeMusic() : pauseMusic()
        }
    }
    @Published var isSFXEnabled: Bool {
        didSet { UserDefaults.standard.set(isSFXEnabled, forKey: "zenith_sfx") }
    }

    private var musicPlayer: AVAudioPlayer?
    private var sfxPlayers: [SFXEvent: AVAudioPlayer] = [:]

    private init() {
        isMusicEnabled = UserDefaults.standard.object(forKey: "zenith_music") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "zenith_music")
        isSFXEnabled = UserDefaults.standard.object(forKey: "zenith_sfx") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "zenith_sfx")

        configureAudioSession()
        preloadSFX()
        if isMusicEnabled { playMusic(track: "music_ambient") }
    }

    // MARK: - Session

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient, mode: .default, options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { /* silent */ }
    }

    // MARK: - Music

    func playMusic(track: String) {
        guard isMusicEnabled,
              let url = Bundle.main.url(forResource: track, withExtension: "mp3") else { return }
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = -1
            musicPlayer?.volume = 0.35
            musicPlayer?.play()
        } catch { /* silent */ }
    }

    private func pauseMusic() { musicPlayer?.pause() }
    private func resumeMusic() { musicPlayer?.play() }

    func fadeOutMusic(duration: TimeInterval = 1.5) {
        guard let player = musicPlayer else { return }
        let steps = 20
        let interval = duration / Double(steps)
        let volumeStep = player.volume / Float(steps)
        var step = 0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            step += 1
            player.volume = max(0, player.volume - volumeStep)
            if step >= steps { timer.invalidate() }
        }
    }

    // MARK: - SFX

    private func preloadSFX() {
        let events: [SFXEvent] = [.slide, .wrongTap, .success, .failure,
                                   .buttonTap, .hint, .star]
        for event in events {
            guard let url = Bundle.main.url(forResource: event.rawValue,
                                             withExtension: "mp3") else { continue }
            sfxPlayers[event] = try? AVAudioPlayer(contentsOf: url)
            sfxPlayers[event]?.prepareToPlay()
        }
    }

    func play(_ event: SFXEvent) {
        guard isSFXEnabled else { return }
        if let player = sfxPlayers[event] {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback: system sound for missing assets
            playSystemSound(for: event)
        }
    }

    private func playSystemSound(for event: SFXEvent) {
        switch event {
        case .buttonTap:
            AudioServicesPlaySystemSound(1104)
        case .success:
            AudioServicesPlaySystemSound(1016)
        case .failure:
            AudioServicesPlaySystemSound(1053)
        default:
            AudioServicesPlaySystemSound(1306)
        }
    }
}

import AudioToolbox
