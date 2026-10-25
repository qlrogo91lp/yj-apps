import AVFoundation
import SwiftUI

/// 소리 없는 영상을 끝까지 틀고 처음부터 다시 반복한다. 앱 번들의 mp4 한 개를 받는다.
///
/// 소리 트랙이 없는 영상만 쓴다. 그래도 플레이어가 오디오 세션을 건드려 사용자의 음악을 끊지 않도록
/// 카테고리를 `ambient`(다른 소리와 섞임)로 둔다.
struct LoopingVideo: UIViewRepresentable {
    let url: URL
    /// false 면 멈춘다. 페이지를 넘겼는데 화면 밖에서 계속 도는 것을 막는다.
    let isPlaying: Bool

    func makeUIView(context _: Context) -> PlayerView {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        return PlayerView(url: url)
    }

    func updateUIView(_ view: PlayerView, context _: Context) {
        view.setPlaying(isPlaying)
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        private let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?

        init(url: URL) {
            super.init(frame: .zero)
            let playerLayer = layer as? AVPlayerLayer
            playerLayer?.player = player
            playerLayer?.videoGravity = .resizeAspect
            backgroundColor = .clear
            player.isMuted = true
            player.allowsExternalPlayback = false
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setPlaying(_ playing: Bool) {
            if playing {
                player.play()
            } else {
                player.pause()
            }
        }
    }
}
