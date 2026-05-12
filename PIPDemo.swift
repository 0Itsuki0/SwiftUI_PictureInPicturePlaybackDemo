
import AVKit
import SwiftUI

struct PIPDemoView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var player: AVQueuePlayer = .init()
    @State private var playerLoop: AVPlayerLooper?

    private var url: URL? = Bundle.main.url(
        forResource: "pipVideo",
        withExtension: "mov"
    )

    var body: some View {
        VStack {
            Button(
                action: {
                    Task {
                        self.player.isMuted = false
                        if let url = URL(
                            string: UIApplication
                                .openSettingsURLString
                        ) {
                            self.openURL(url)
                        }
                    }
                },
                label: {
                    Text("Go to settings")
                }
            )
        }
        .overlay(content: {
            VideoPlayer(player: $player)
                .frame(width: 150, height: 100)
                .opacity(0.0)
        })
        .onAppear {
            guard AVPictureInPictureController.isPictureInPictureSupported()
            else {
                print("PIP not supported")
                return
            }
            self.playerLoop?.disableLooping()
            self.playerLoop = nil
            self.player.removeAllItems()

            if let url {
                let playerItem = AVPlayerItem(url: url)
                self.playerLoop = AVPlayerLooper(
                    player: player,
                    templateItem: playerItem
                )
                self.player.replaceCurrentItem(with: playerItem)
            }
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playback, mode: .moviePlayback)
                try audioSession.setActive(true)
                self.player.isMuted = true
                self.player.play()
            } catch (let error) {
                print("error on audio session", error)
            }
        }
        .onChange(
            of: self.scenePhase,
            initial: true,
            { old, new in
                print(old.description, new.description)
                // scene phase cycle
                // on view appear: inactive (old) -> inactive (new) and then inactive -> active
                // on leaving the app: active -> inactive and then inactive -> background
                // on coming back to the app: background -> inactive and then inactive -> active
                if old == .background, new == .inactive {
                    self.playerLoop = nil
                    self.player.removeAllItems()
                    if let url {
                        let playerItem = AVPlayerItem(url: url)
                        self.playerLoop = AVPlayerLooper(
                            player: player,
                            templateItem: playerItem
                        )
                        self.player.replaceCurrentItem(with: playerItem)
                    }
                    return
                }

                // start player while scene is not active will fail (sometimes)
                if old == .inactive, new == .active {
                    self.player.isMuted = true
                    self.player.play()
                }
            }
        )
    }
}

struct VideoPlayer: UIViewControllerRepresentable {

    @Binding var player: AVQueuePlayer

    private let playerController = AVPlayerViewController()

    func makeUIViewController(context: Context) -> AVPlayerViewController {

        playerController.showsPlaybackControls = true
        playerController.allowsPictureInPicturePlayback = true
        playerController.canStartPictureInPictureAutomaticallyFromInline = true

        playerController.player = player

        playerController.delegate = context.coordinator
        return playerController
    }

    func updateUIViewController(
        _ playerController: AVPlayerViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        func playerViewControllerWillStartPictureInPicture(
            _ playerViewController: AVPlayerViewController
        ) {
            playerViewController.player?.seek(to: .zero)
        }
    }
}
