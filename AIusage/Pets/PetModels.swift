import SwiftUI

enum PetKind: String, CaseIterable, Identifiable, Sendable {
    case codex
    case cursor
    case gemini
    case claude

    var id: String { rawValue }

    var meterProvider: MeterProvider? {
        switch self {
        case .codex:
            return .codex
        case .cursor:
            return .cursor
        case .claude:
            return .claude
        case .gemini:
            return nil
        }
    }

    var accent: Color {
        switch self {
        case .codex:
            return Color(red: 0.22, green: 0.86, blue: 0.49)
        case .cursor:
            return Color(red: 0.67, green: 0.48, blue: 0.98)
        case .gemini:
            return Color(red: 0.31, green: 0.72, blue: 1)
        case .claude:
            return Color(red: 1, green: 0.62, blue: 0.32)
        }
    }

    var symbolName: String {
        switch self {
        case .codex:
            return "square.stack.3d.up.fill"
        case .cursor:
            return "chevron.left.forwardslash.chevron.right"
        case .gemini:
            return "cube.fill"
        case .claude:
            return "umbrella.fill"
        }
    }

    func menuTitle(vacation: Bool) -> String {
        switch self {
        case .codex:
            return "Codex (架构师)"
        case .cursor:
            return "Cursor (开发 A)"
        case .gemini:
            return "Gemini (开发 B)"
        case .claude:
            return vacation ? "Claude (休假中)" : "Claude"
        }
    }

    func subtitle(vacation: Bool) -> String {
        switch self {
        case .codex:
            return "系统设计 · 架构规划 · 代码策略"
        case .cursor:
            return "功能实现 · 快速迭代 · 动手构建"
        case .gemini:
            return "技术助理 · 问题分析 · 多方协作"
        case .claude:
            return vacation ? "度假模式 · 放松充电 · 随时回归" : "长任务 · 深度处理 · 随时开工"
        }
    }
}

enum PetMood: String, Equatable, Sendable {
    case working
    case idle
    case vacation
    case offline

    var title: String {
        switch self {
        case .working:
            return "工作中"
        case .idle:
            return "闲着"
        case .vacation:
            return "休假中"
        case .offline:
            return "离线"
        }
    }

    var pillFill: Color {
        switch self {
        case .working:
            return Color(red: 0.18, green: 0.62, blue: 0.38)
        case .idle:
            return Color(red: 0.24, green: 0.27, blue: 0.36)
        case .vacation:
            return Color(red: 0.72, green: 0.42, blue: 0.22)
        case .offline:
            return Color(red: 0.28, green: 0.22, blue: 0.24)
        }
    }

    var pillText: Color {
        switch self {
        case .working, .vacation:
            return .white
        case .idle, .offline:
            return Color(red: 0.86, green: 0.88, blue: 0.93)
        }
    }

    static func resolve(
        kind: PetKind,
        latest: Date?,
        present: Bool,
        accountReady: Bool,
        vacation: Bool,
        probed: Bool,
        now: Date
    ) -> PetMood {
        if let latest, now.timeIntervalSince(latest) < 180 {
            return .working
        }
        if kind == .claude, vacation {
            return .vacation
        }
        if present || accountReady {
            return .idle
        }
        if !probed {
            return .idle
        }
        return .offline
    }
}

enum PetPalette {
    static let background = Color(red: 0.045, green: 0.05, blue: 0.11)
    static let card = Color(red: 0.075, green: 0.082, blue: 0.14)
    static let text = Color(red: 0.95, green: 0.96, blue: 0.99)
    static let muted = Color(red: 0.62, green: 0.67, blue: 0.78)
}
