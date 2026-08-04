import AppKit
import MoveCore

enum WorkoutSoundService {
    static func play(_ cue: WorkoutSoundCue, mode: SoundMode) {
        guard WorkoutSoundPolicy.shouldPlay(cue, mode: mode) else { return }
        let name: String
        switch cue {
        case .start: name = "Tink"
        case .countdown: name = "Pop"
        case .change: name = "Glass"
        case .end: name = "Hero"
        }
        NSSound(named: name)?.play()
    }
}
