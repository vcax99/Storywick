import Foundation
import MediaPlayer

/// Lock-screen / Control Center now-playing info and remote transport commands.
final class NowPlaying {

    var onTogglePlayPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?

    private var wired = false

    func wire() {
        guard !wired else { return }
        wired = true
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in self?.onTogglePlayPause?(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.onTogglePlayPause?(); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.onTogglePlayPause?(); return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.onNext?(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.onPrevious?(); return .success }

        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = false
    }

    func update(title: String, chapter: String, sentence: Int, total: Int, playing: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "Storywick",
            MPMediaItemPropertyAlbumTitle: chapter,
            MPMediaItemPropertyPlaybackDuration: Double(max(total, 1)),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(min(sentence, max(total, 1))),
            MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0,
        ]
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
