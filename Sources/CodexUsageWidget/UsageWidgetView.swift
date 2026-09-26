import AppKit
import SwiftUI

struct UsageWidgetView: View {
    @ObservedObject var controller: UsageController
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: isNarrow ? 2 : 5) {
            HStack(spacing: 7) {
                WindowDragHandle()
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .leading) {
                        if isHovered {
                            Image(systemName: "hand.draw")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .allowsHitTesting(false)
                        }
                    }
                    .help("Drag to move")
                if isHovered {
                    controlButton("arrow.clockwise", label: "Refresh usage", action: controller.refresh)
                    controlButton("slider.horizontal.3", label: "Settings") { controller.showSettings() }
                    controlButton("xmark", label: "Quit Codex Usage") { NSApp.terminate(nil) }
                }
            }
            .frame(height: 18)
            usageRow(title: "Weekly", window: snapshot?.weekly)
            usageRow(title: "5 hour", window: snapshot?.fiveHour)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isNarrow ? 4 : 6)
        .frame(width: controller.size.dimensions.width, height: controller.size.dimensions.height)
        .onHover { hovering in
            isHovered = hovering
            if hovering, canRefreshOnHover, let snapshot,
               Date().timeIntervalSince(snapshot.updatedAt) > controller.refreshInterval.seconds {
                controller.refresh()
            }
        }
        .background(Color.clear)
        .accessibilityElement(children: .contain)
    }

    private var snapshot: UsageSnapshot? {
        if case .available(let snapshot) = controller.state { return snapshot }
        return nil
    }

    private var isNarrow: Bool {
        controller.size == .tiny || controller.size == .small
    }

    private var canRefreshOnHover: Bool {
#if DEBUG
        !controller.isScreenshotPreview
#else
        true
#endif
    }

    @ViewBuilder
    private func usageRow(title: String, window: UsageWindow?) -> some View {
        VStack(spacing: isNarrow ? 2 : 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .shadow(color: .black.opacity(0.62), radius: 0.8, x: 0, y: 0.5)
                Text(window.map { "\(Int($0.remainingPercent.rounded()))% left" } ?? "—")
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color(for: window?.remainingPercent))
                    .shadow(color: .black.opacity(0.4), radius: 0.5, x: 0, y: 0.5)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(resetLabel(for: window))
                    .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .shadow(color: .black.opacity(0.62), radius: 0.8, x: 0, y: 0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.14))
                    Capsule()
                        .fill(color(for: window?.remainingPercent))
                        .frame(width: max(0, geometry.size.width * min(max((window?.remainingPercent ?? 0) / 100, 0), 1)))
                }
            }
            .frame(height: 5)
            .shadow(color: color(for: window?.remainingPercent).opacity(0.18), radius: 4, y: 1)
        }
        .frame(maxHeight: .infinity)
        .help(rowHelp(window: window))
    }

    private func controlButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
    }

    private func color(for percentage: Double?) -> Color {
        guard let percentage else { return Color.secondary.opacity(0.55) }
        if percentage <= 20 { return Color(red: 0.96, green: 0.38, blue: 0.36) }
        if percentage <= 50 { return Color(red: 0.96, green: 0.68, blue: 0.31) }
        return Color(red: 0.30, green: 0.78, blue: 0.56)
    }

    private func resetLabel(for window: UsageWindow?) -> String {
        guard let timestamp = window?.resetsAt else { return "Reset unavailable" }
        let date = Date(timeIntervalSince1970: timestamp)
        let interval = max(0, date.timeIntervalSinceNow)
        if interval < 24 * 60 * 60 {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            if hours == 0 { return isNarrow ? "in \(minutes)m" : "Resets in \(minutes)m" }
            return isNarrow ? "in \(hours)h \(minutes)m" : "Resets in \(hours)h \(minutes)m"
        }
        let time = date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        return isNarrow ? time : "Resets \(time)"
    }

    private func rowHelp(window: UsageWindow?) -> String {
        if let window, let date = window.resetsAt {
            let updated = snapshot?.updatedAt.formatted(date: .omitted, time: .shortened) ?? "unknown"
            return "\(Int(window.remainingPercent.rounded()))% remaining. Updated \(updated). Resets at \(Date(timeIntervalSince1970: date).formatted(date: .abbreviated, time: .shortened))"
        }
        if case .unavailable(let message) = controller.state { return message }
        return "Usage data unavailable. Use the refresh control to try again."
    }
}

private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ nsView: DragView, context: Context) {}

    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}
