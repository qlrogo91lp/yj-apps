#if canImport(WatchConnectivity)
    import Combine
    import Foundation
    import WatchConnectivity

    /// WCSession 래퍼. 전송(3가지 Delivery)·수신 라우팅·콜드런치 컨텍스트 채택·sentAt 스탬프만 담당한다.
    /// 메시지 정의는 앱 몫. macOS에는 WatchConnectivity가 없어 이 파일 전체가 제외된다.
    public final class ConnectivityService: NSObject, ObservableObject {
        @Published public private(set) var isCounterpartReachable: Bool = false

        /// clearSessionContext가 쓰는 예약 타입. 수신 측엔 등록이 없으므로 라우터가 자연히 무시한다.
        static let sessionClearedType = "sessionCleared"

        private let router = MessageRouter()

        override public init() {
            dispatchPrecondition(condition: .onQueue(.main))
            super.init()
            guard WCSession.isSupported() else { return }
            WCSession.default.delegate = self
            WCSession.default.activate()
        }

        /// 핸들러는 main queue에서 호출된다.
        /// ⚠️ 서비스를 생성한 그 main-queue turn 안에서 등록을 마칠 것 — 활성화 콜백(콜드런치
        /// 컨텍스트 배달)은 다음 turn에 main으로 들어오므로, 그 전에 등록되어 있으면 유실이 없다.
        public func onReceive<M: ConnectivityMessage>(
            _: M.Type,
            maxAge: TimeInterval? = nil,
            handler: @escaping @MainActor (M) -> Void
        ) {
            dispatchPrecondition(condition: .onQueue(.main))
            router.register(type: M.messageType, maxAge: maxAge) { dict in
                guard let message = M(from: dict) else { return }
                MainActor.assumeIsolated { handler(message) }
            }
        }

        public func send(_ message: some ConnectivityMessage, via delivery: Delivery) {
            guard WCSession.default.activationState == .activated else { return }
            let dict = MessageEnvelope.stamp(
                message.toDictionary(),
                type: type(of: message).messageType,
                sentAt: Date().timeIntervalSince1970
            )
            switch delivery {
            case .realtimeOnly:
                #if os(iOS)
                    guard WCSession.default.isWatchAppInstalled else { return }
                #endif
                guard WCSession.default.isReachable else { return }
                WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
            case .reliable:
                // 원본 sendReliably와 가드 파리티 유지 — iOS isWatchAppInstalled 가드 없음
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
                } else {
                    WCSession.default.transferUserInfo(dict)
                }
            case .context:
                #if os(iOS)
                    guard WCSession.default.isWatchAppInstalled else { return }
                #endif
                if WCSession.default.isReachable {
                    WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
                } else {
                    try? WCSession.default.updateApplicationContext(dict)
                }
            }
        }

        /// 드라이버가 운동/매치를 끝낼 때 자기 outgoing applicationContext를 비운다.
        /// 상대가 콜드 런치할 때 끝난 세션의 sessionStart를 읽어 잘못 진입하지 않게 한다.
        public func clearSessionContext() {
            guard WCSession.default.activationState == .activated else { return }
            #if os(iOS)
                guard WCSession.default.isWatchAppInstalled else { return }
            #endif
            try? WCSession.default.updateApplicationContext(["type": Self.sessionClearedType])
        }

        private func routeOnMain(_ dict: [String: Any]) {
            DispatchQueue.main.async { self.router.route(dict) }
        }
    }

    extension ConnectivityService: WCSessionDelegate {
        public func session(_ session: WCSession,
                            activationDidCompleteWith _: WCSessionActivationState,
                            error _: Error?)
        {
            DispatchQueue.main.async { self.isCounterpartReachable = session.isReachable }
            // 콜드 런치 함정: 앱이 꺼져 있는 동안 updateApplicationContext로 도착한 값은
            // didReceiveApplicationContext가 불리지 않고 receivedApplicationContext에만 남는다.
            // 활성화 직후 직접 읽어 같은 라우팅으로 배달한다. staleness는 등록된 maxAge와
            // 앱 핸들러(sessionStart의 workoutStartDate 검사)가 거른다.
            let context = session.receivedApplicationContext
            guard !context.isEmpty else { return }
            routeOnMain(context)
        }

        public func sessionReachabilityDidChange(_ session: WCSession) {
            DispatchQueue.main.async { self.isCounterpartReachable = session.isReachable }
        }

        public func session(_: WCSession, didReceiveMessage message: [String: Any]) {
            routeOnMain(message)
        }

        public func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
            routeOnMain(applicationContext)
        }

        public func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
            routeOnMain(userInfo)
        }

        #if os(iOS)
            public func sessionDidBecomeInactive(_: WCSession) {}
            public func sessionDidDeactivate(_: WCSession) {
                WCSession.default.activate()
            }
        #endif
    }
#endif
