import Foundation

@MainActor
final class PetStore: ObservableObject {
    @Published var focusedPet: PetKind = .codex
    @Published private(set) var moods: [PetKind: PetMood] = Dictionary(
        uniqueKeysWithValues: PetKind.allCases.map { ($0, .idle) }
    )
    @Published var claudeOnVacation: Bool {
        didSet {
            UserDefaults.standard.set(claudeOnVacation, forKey: Self.vacationKey)
            applyMoods()
        }
    }

    private static let vacationKey = "menuBarPets.claudeOnVacation"
    private var activity = PetActivitySnapshot()
    private var didProbe = false
    private var refreshTask: Task<Void, Never>?

    init() {
        claudeOnVacation = UserDefaults.standard.bool(forKey: Self.vacationKey)
    }

    func start() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func detailLine(_ kind: PetKind) -> String {
        if let date = activity.latest(for: kind) {
            return "最近活动 \(relativeText(date))"
        }
        if activity.present(for: kind) {
            return "本机有记录，最近三分钟没有新写入"
        }
        return "还没发现本机会话"
    }

    func statusSummary() -> String {
        PetKind.allCases.map { kind in
            let mood = moods[kind]?.title ?? "闲着"
            return "\(kind.menuTitle(vacation: claudeOnVacation)) \(mood)"
        }
        .joined(separator: " · ")
    }

    private func refresh() async {
        let snapshot = await Task.detached(priority: .utility) {
            PetActivityProbe.capture()
        }.value
        activity = snapshot
        didProbe = true
        applyMoods()
    }

    private func applyMoods() {
        let now = Date()
        var next: [PetKind: PetMood] = [:]
        for kind in PetKind.allCases {
            next[kind] = PetMood.resolve(
                kind: kind,
                latest: activity.latest(for: kind),
                present: activity.present(for: kind),
                vacation: claudeOnVacation,
                probed: didProbe,
                now: now
            )
        }
        if next != moods {
            moods = next
        }
    }

    private func relativeText(_ date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        if seconds < 60 {
            return "刚刚"
        }
        if seconds < 3600 {
            return "\(Int(seconds / 60)) 分钟前"
        }
        if seconds < 86_400 {
            return "\(Int(seconds / 3600)) 小时前"
        }
        return "\(Int(seconds / 86_400)) 天前"
    }
}
