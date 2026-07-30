import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var meterWindow: NSWindow?
    private var floatingPanel: NSPanel?
    private var floatingView: FloatingStatusView?
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: 54)
        super.init()
        configureStatusItem()
        configurePopover()
        bindState()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = nil
        button.imagePosition = .noImage
        button.title = "CM"
        button.font = .systemFont(ofSize: 13, weight: .semibold)
        button.toolTip = "Codex Meter"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 430, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: MeterPopoverView(appState: appState)
        )
    }

    private func bindState() {
        appState.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.statusItem.button?.title = self?.visibleMenuTitle ?? "CM"
                    self?.statusItem.button?.toolTip = "Codex Meter \(self?.appState.compactMenuTitle ?? "")"
                    self?.updateFloatingButton()
                }
            }
            .store(in: &cancellables)
    }

    private var visibleMenuTitle: String {
        let compact = appState.compactMenuTitle
        if compact.isEmpty || compact == "..." {
            return "CM"
        }
        return compact
    }

    func showFloatingStatus() {
        if let floatingPanel {
            floatingPanel.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 40),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true

        let view = FloatingStatusView(frame: NSRect(x: 0, y: 0, width: 320, height: 40))
        view.autoresizingMask = [.width, .height]
        view.onClick = { [weak self] in
            self?.showWindowFromFloatingStatus()
        }
        view.onDragEnded = { [weak self] in
            self?.saveFloatingPanelPosition()
        }
        view.toolTip = "拖动移动位置，点击打开详情"
        panel.contentView = view
        floatingPanel = panel
        floatingView = view
        updateFloatingButton()
        positionFloatingPanel(panel)
        panel.orderFrontRegardless()
    }

    private func updateFloatingButton() {
        guard let floatingView else { return }
        let display = floatingDisplay
        floatingPanel?.hasShadow = appState.floatingDisplayStyle != .circular
        let percentFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        let resetFont = NSFont.systemFont(ofSize: 12, weight: .regular)
        let nameFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        let separatorFont = NSFont.systemFont(ofSize: 12, weight: .regular)
        let percentWidth = ceil((display.percent as NSString).size(withAttributes: [.font: percentFont]).width) + 2
        let resetWidth = ceil((display.reset as NSString).size(withAttributes: [.font: resetFont]).width) + 2
        let nameWidth = ceil(("Codex" as NSString).size(withAttributes: [.font: nameFont]).width) + 2
        let separatorWidth = ceil(("·" as NSString).size(withAttributes: [.font: separatorFont]).width) + 1
        let separatorGap: CGFloat = 2
        let codexPartWidth = 6 + 8 + nameWidth
        let detailedWidth = 14
            + codexPartWidth
            + separatorGap + separatorWidth + separatorGap
            + percentWidth
            + separatorGap + separatorWidth + separatorGap
            + resetWidth
            + 14
        let targetSize = appState.floatingDisplayStyle == .circular
            ? NSSize(width: 90, height: 90)
            : NSSize(width: detailedWidth, height: 40)

        if let panel = floatingPanel,
           abs(panel.frame.width - targetSize.width) > 1 || abs(panel.frame.height - targetSize.height) > 1 {
            var newFrame = panel.frame
            let oldCenter = NSPoint(x: newFrame.midX, y: newFrame.midY)
            newFrame.size = targetSize
            newFrame.origin = NSPoint(
                x: oldCenter.x - targetSize.width / 2,
                y: oldCenter.y - targetSize.height / 2
            )

            if let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame {
                newFrame.origin.x = min(newFrame.origin.x, visibleFrame.maxX - newFrame.width)
                newFrame.origin.x = max(newFrame.origin.x, visibleFrame.minX)
                newFrame.origin.y = min(newFrame.origin.y, visibleFrame.maxY - newFrame.height)
                newFrame.origin.y = max(newFrame.origin.y, visibleFrame.minY)
            }

            panel.setFrame(newFrame, display: true)
            floatingView.frame = panel.contentView?.bounds ?? NSRect(origin: .zero, size: targetSize)
        }

        floatingView.configure(
            percent: display.percent,
            resetText: display.reset,
            circularResetText: display.circularReset,
            circularUsageText: display.circularUsage,
            progress: display.progress,
            accentColor: display.color,
            isStale: appState.isCachedDataStale,
            style: appState.floatingDisplayStyle
        )
        floatingView.toolTip = "Codex \(display.percent) · \(display.reset)"
    }

    private var floatingDisplay: (
        percent: String,
        reset: String,
        circularReset: String,
        circularUsage: String,
        progress: CGFloat,
        color: NSColor
    ) {
        guard let window = appState.fiveHourWindow ?? appState.weeklyWindow else {
            return ("同步中", "等待额度数据", "同步中", appState.compactLifetimeTokenText, 0, .systemGray)
        }

        let circularReset = window.resetDate
            .map { "\(CountdownFormatter.longString(until: $0))重置" }
            ?? "重置时间未知"
        return (
            window.remainingPercentText,
            window.resetLineText,
            circularReset,
            appState.compactLifetimeTokenText,
            CGFloat(window.remainingPercent / 100),
            appState.floatingQuotaColor
        )
    }

    private func positionFloatingPanel(_ panel: NSPanel) {
        if let saved = UserDefaults.standard.string(forKey: "floatingPanelOrigin") {
            let parts = saved.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 {
                panel.setFrameOrigin(NSPoint(x: parts[0], y: parts[1]))
                return
            }
        }

        guard let screen = NSScreen.main else {
            panel.center()
            return
        }
        let frame = screen.visibleFrame
        let x = frame.maxX - panel.frame.width - 16
        let y = frame.maxY - panel.frame.height - 10
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func saveFloatingPanelPosition() {
        guard let floatingPanel else { return }
        let origin = floatingPanel.frame.origin
        UserDefaults.standard.set("\(origin.x),\(origin.y)", forKey: "floatingPanelOrigin")
    }

    @objc private func showWindowFromFloatingStatus() {
        showMeterWindow()
    }

    func showMeterWindow() {
        if let meterWindow {
            meterWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Meter"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: MeterPopoverView(appState: appState))
        meterWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            appState.refreshIfNeededForPopover()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

final class FloatingStatusView: NSView {
    var onClick: (() -> Void)?
    var onDragEnded: (() -> Void)?

    private let materialView = NSVisualEffectView()
    private let circularGraphicView = NSView()
    private let dotView = NSView()
    private let nameLabel = NSTextField(labelWithString: "Codex")
    private let firstSeparatorLabel = NSTextField(labelWithString: "·")
    private let percentLabel = NSTextField(labelWithString: "")
    private let secondSeparatorLabel = NSTextField(labelWithString: "·")
    private let resetLabel = NSTextField(labelWithString: "")
    private let ringTrackLayer = CAShapeLayer()
    private let ringProgressLayer = CAShapeLayer()
    private let waterLayer = CALayer()
    private let waterMaskLayer = CAShapeLayer()
    private let backWaveLayer = CAShapeLayer()
    private let frontWaveLayer = CAShapeLayer()
    private let backWaveGradientLayer = CAGradientLayer()
    private let frontWaveGradientLayer = CAGradientLayer()
    private let borderGradientLayer = CAGradientLayer()
    private let borderMaskLayer = CAShapeLayer()
    private let circularPercentLabel = NSTextField(labelWithString: "")
    private let circularTitleLabel = NSTextField(labelWithString: "已用 --")
    private let circularResetLabel = NSTextField(labelWithString: "")
    private var displayStyle: FloatingDisplayStyle = .detailed
    private var circularAccentColor: NSColor = .systemGray
    private var ringProgress: CGFloat = 0
    private var wavePhase: CGFloat = 0
    private var waveTimer: Timer?

    private var mouseDownLocation: NSPoint?
    private var windowStartOrigin: NSPoint?
    private var didDrag = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1.25
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.12
        layer?.shadowRadius = 5
        layer?.shadowOffset = NSSize(width: 0, height: 2)

        materialView.material = .popover
        materialView.blendingMode = .withinWindow
        materialView.state = .active
        materialView.wantsLayer = true
        materialView.layer?.cornerRadius = 12
        materialView.layer?.masksToBounds = true
        addSubview(materialView)

        circularGraphicView.wantsLayer = true
        addSubview(circularGraphicView)

        dotView.wantsLayer = true
        dotView.layer?.cornerRadius = 3
        addSubview(dotView)

        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .left
        addSubview(nameLabel)

        for separatorLabel in [firstSeparatorLabel, secondSeparatorLabel] {
            separatorLabel.font = .systemFont(ofSize: 12, weight: .regular)
            separatorLabel.textColor = .tertiaryLabelColor
            separatorLabel.alignment = .center
            addSubview(separatorLabel)
        }

        percentLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        percentLabel.textColor = .labelColor
        percentLabel.alignment = .left
        addSubview(percentLabel)

        resetLabel.font = .systemFont(ofSize: 12, weight: .regular)
        resetLabel.textColor = .secondaryLabelColor
        resetLabel.alignment = .left
        resetLabel.lineBreakMode = .byClipping
        addSubview(resetLabel)

        for ringLayer in [ringTrackLayer, ringProgressLayer] {
            ringLayer.fillColor = NSColor.clear.cgColor
            ringLayer.lineWidth = 12
        }
        ringProgressLayer.lineCap = .round
        ringProgressLayer.transform = CATransform3DMakeRotation(-.pi / 2, 0, 0, 1)

        waterLayer.mask = waterMaskLayer
        backWaveGradientLayer.mask = backWaveLayer
        frontWaveGradientLayer.mask = frontWaveLayer
        backWaveLayer.fillColor = NSColor.black.cgColor
        frontWaveLayer.fillColor = NSColor.black.cgColor
        waterLayer.addSublayer(backWaveGradientLayer)
        waterLayer.addSublayer(frontWaveGradientLayer)
        borderGradientLayer.mask = borderMaskLayer
        circularGraphicView.layer?.addSublayer(waterLayer)
        circularGraphicView.layer?.addSublayer(ringTrackLayer)
        circularGraphicView.layer?.addSublayer(ringProgressLayer)
        circularGraphicView.layer?.addSublayer(borderGradientLayer)

        for gradientLayer in [backWaveGradientLayer, frontWaveGradientLayer, borderGradientLayer] {
            gradientLayer.startPoint = CGPoint(x: 0, y: 1)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0)
        }
        backWaveGradientLayer.opacity = 0.58
        frontWaveGradientLayer.opacity = 0.76
        borderMaskLayer.fillColor = NSColor.clear.cgColor
        borderMaskLayer.strokeColor = NSColor.black.cgColor
        borderMaskLayer.lineWidth = 2

        circularPercentLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        circularPercentLabel.alignment = .center
        addSubview(circularPercentLabel)

        circularTitleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        circularTitleLabel.textColor = .labelColor
        circularTitleLabel.alignment = .center
        addSubview(circularTitleLabel)

        circularResetLabel.font = .systemFont(ofSize: 9, weight: .medium)
        circularResetLabel.textColor = .secondaryLabelColor
        circularResetLabel.alignment = .center
        circularResetLabel.lineBreakMode = .byClipping
        addSubview(circularResetLabel)

        setCircularElementsHidden(true)
    }

    func configure(
        percent: String,
        resetText: String,
        circularResetText: String,
        circularUsageText: String,
        progress: CGFloat,
        accentColor: NSColor,
        isStale: Bool,
        style: FloatingDisplayStyle
    ) {
        displayStyle = style
        ringProgress = min(max(progress, 0), 1)
        percentLabel.stringValue = percent
        circularPercentLabel.stringValue = percent
        resetLabel.stringValue = isStale ? "缓存 · \(resetText)" : resetText
        circularResetLabel.stringValue = isStale ? "缓存 · \(circularResetText)" : circularResetText
        circularTitleLabel.stringValue = circularUsageText
        percentLabel.textColor = accentColor
        circularAccentColor = accentColor
        applyCircularTextColors()
        dotView.layer?.backgroundColor = accentColor.cgColor
        layer?.borderColor = accentColor.withAlphaComponent(0.9).cgColor
        ringTrackLayer.strokeColor = accentColor.withAlphaComponent(0.16).cgColor
        ringProgressLayer.strokeColor = accentColor.cgColor
        ringProgressLayer.strokeEnd = ringProgress
        let lightAccent = accentColor.blended(withFraction: 0.48, of: .white) ?? accentColor
        let darkAccent = accentColor.blended(withFraction: 0.2, of: .black) ?? accentColor
        let gradientColors = [
            lightAccent.cgColor,
            accentColor.cgColor,
            darkAccent.cgColor
        ]
        backWaveGradientLayer.colors = gradientColors
        frontWaveGradientLayer.colors = gradientColors
        borderGradientLayer.colors = gradientColors
        for gradientLayer in [backWaveGradientLayer, frontWaveGradientLayer, borderGradientLayer] {
            gradientLayer.locations = [0, 0.52, 1]
        }

        let isCircular = style == .circular
        materialView.blendingMode = isCircular ? .behindWindow : .withinWindow
        materialView.alphaValue = isCircular ? 0.82 : 1
        layer?.backgroundColor = isCircular
            ? NSColor.clear.cgColor
            : NSColor.windowBackgroundColor.withAlphaComponent(0.88).cgColor
        setDetailedElementsHidden(isCircular)
        setCircularElementsHidden(!isCircular)
        ringTrackLayer.isHidden = true
        ringProgressLayer.isHidden = true
        layer?.borderWidth = isCircular ? 0 : 1.25
        layer?.shadowOpacity = isCircular ? 0 : 0.12
        isCircular ? startWaveAnimation() : stopWaveAnimation()
        needsLayout = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyCircularTextColors()
    }

    private func applyCircularTextColors() {
        let accent = circularAccentColor.usingColorSpace(.sRGB) ?? circularAccentColor
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let primaryTarget = isDark ? NSColor.white : NSColor.black
        let primaryBlend: CGFloat = isDark ? 0.72 : 0.52
        let secondaryBlend: CGFloat = isDark ? 0.58 : 0.68
        let primary = accent.blended(withFraction: primaryBlend, of: primaryTarget) ?? primaryTarget
        let secondary = accent.blended(withFraction: secondaryBlend, of: primaryTarget) ?? primaryTarget

        circularPercentLabel.textColor = primary
        circularTitleLabel.textColor = secondary
        circularResetLabel.textColor = secondary
    }

    override func layout() {
        super.layout()
        materialView.frame = bounds

        if displayStyle == .circular {
            layer?.cornerRadius = bounds.height / 2
            materialView.frame = bounds.insetBy(dx: 1.5, dy: 1.5)
            materialView.layer?.cornerRadius = materialView.bounds.height / 2
            circularGraphicView.frame = bounds
            borderGradientLayer.frame = bounds
            borderMaskLayer.frame = bounds
            borderMaskLayer.path = CGPath(
                ellipseIn: bounds.insetBy(dx: 1.5, dy: 1.5),
                transform: nil
            )

            let ringFrame = bounds.insetBy(dx: 8, dy: 8)
            let ringPath = CGPath(ellipseIn: ringFrame, transform: nil)
            ringTrackLayer.frame = bounds
            ringTrackLayer.path = ringPath
            ringProgressLayer.frame = bounds
            ringProgressLayer.path = ringPath
            updateWavePaths()

            let groupHeight = 50.0
            let groupBottom = floor((bounds.height - groupHeight) / 2)
            circularTitleLabel.frame = NSRect(
                x: 8,
                y: groupBottom,
                width: bounds.width - 16,
                height: 16
            )
            circularResetLabel.frame = NSRect(
                x: 3,
                y: groupBottom + 16,
                width: bounds.width - 6,
                height: 14
            )
            circularPercentLabel.frame = NSRect(
                x: 8,
                y: groupBottom + 30,
                width: bounds.width - 16,
                height: 20
            )
            return
        }

        layer?.cornerRadius = 12
        materialView.layer?.cornerRadius = 12
        let nameWidth = ceil(nameLabel.intrinsicContentSize.width) + 2
        let firstSeparatorWidth = ceil(firstSeparatorLabel.intrinsicContentSize.width) + 1
        let percentWidth = ceil(percentLabel.intrinsicContentSize.width) + 2
        let secondSeparatorWidth = ceil(secondSeparatorLabel.intrinsicContentSize.width) + 1
        let resetWidth = ceil(resetLabel.intrinsicContentSize.width) + 2
        let separatorGap = 2.0
        let dotX = 14.0
        let nameX = dotX + 14
        let firstSeparatorX = nameX + nameWidth + separatorGap
        let percentX = firstSeparatorX + firstSeparatorWidth + separatorGap
        let secondSeparatorX = percentX + percentWidth + separatorGap
        let resetX = secondSeparatorX + secondSeparatorWidth + separatorGap

        dotView.frame = NSRect(x: dotX, y: floor(bounds.midY - 3), width: 6, height: 6)
        center(nameLabel, x: nameX, width: nameWidth)
        center(firstSeparatorLabel, x: firstSeparatorX, width: firstSeparatorWidth)
        center(percentLabel, x: percentX, width: percentWidth)
        center(secondSeparatorLabel, x: secondSeparatorX, width: secondSeparatorWidth)
        center(resetLabel, x: resetX, width: resetWidth)
    }

    private func startWaveAnimation() {
        guard waveTimer == nil else { return }
        let timer = Timer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(advanceWave(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        waveTimer = timer
    }

    @objc private func advanceWave(_ timer: Timer) {
        wavePhase += 0.09
        updateWavePaths()
    }

    private func stopWaveAnimation() {
        waveTimer?.invalidate()
        waveTimer = nil
    }

    private func updateWavePaths() {
        guard displayStyle == .circular, !bounds.isEmpty else { return }

        let waterBounds = bounds.insetBy(dx: 1.5, dy: 1.5)
        waterLayer.frame = bounds
        waterMaskLayer.frame = bounds
        waterMaskLayer.path = CGPath(ellipseIn: waterBounds, transform: nil)
        backWaveLayer.frame = bounds
        frontWaveLayer.frame = bounds
        backWaveGradientLayer.frame = bounds
        frontWaveGradientLayer.frame = bounds

        let waterLevel = waterBounds.minY + waterBounds.height * ringProgress
        backWaveLayer.path = wavePath(
            in: waterBounds,
            waterLevel: waterLevel,
            amplitude: 2,
            phase: wavePhase + .pi
        )
        frontWaveLayer.path = wavePath(
            in: waterBounds,
            waterLevel: waterLevel,
            amplitude: 2.8,
            phase: wavePhase
        )
    }

    private func wavePath(
        in rect: CGRect,
        waterLevel: CGFloat,
        amplitude: CGFloat,
        phase: CGFloat
    ) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: waterLevel))

        var x = rect.minX
        while x <= rect.maxX {
            let progress = (x - rect.minX) / rect.width
            let y = waterLevel + sin(progress * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }

    private func setDetailedElementsHidden(_ hidden: Bool) {
        dotView.isHidden = hidden
        nameLabel.isHidden = hidden
        firstSeparatorLabel.isHidden = hidden
        percentLabel.isHidden = hidden
        secondSeparatorLabel.isHidden = hidden
        resetLabel.isHidden = hidden
    }

    private func setCircularElementsHidden(_ hidden: Bool) {
        circularGraphicView.isHidden = hidden
        ringTrackLayer.isHidden = hidden
        ringProgressLayer.isHidden = hidden
        waterLayer.isHidden = hidden
        circularPercentLabel.isHidden = hidden
        circularTitleLabel.isHidden = hidden
        circularResetLabel.isHidden = hidden
    }

    private func center(_ label: NSTextField, x: CGFloat, width: CGFloat) {
        let height = ceil(label.intrinsicContentSize.height) + 4
        label.frame = NSRect(
            x: x,
            y: floor((bounds.height - height) / 2),
            width: width,
            height: height
        )
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        windowStartOrigin = window?.frame.origin
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownLocation, let windowStartOrigin, let window else { return }
        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - mouseDownLocation.x
        let deltaY = currentLocation.y - mouseDownLocation.y

        if abs(deltaX) > 2 || abs(deltaY) > 2 {
            didDrag = true
        }

        window.setFrameOrigin(NSPoint(x: windowStartOrigin.x + deltaX, y: windowStartOrigin.y + deltaY))
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onDragEnded?()
        } else {
            onClick?()
        }
        mouseDownLocation = nil
        windowStartOrigin = nil
        didDrag = false
    }
}
