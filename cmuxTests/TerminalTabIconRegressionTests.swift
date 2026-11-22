import Bonsplit
import CmuxSidebar
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

// Local terminal tabs use text labels even while an agent is running.
@Suite(.serialized)
struct TerminalTabIconRegressionTests {
    @MainActor
    @Test func newPlainTerminalTabHasNoIcon() throws {
        let workspace = Workspace()
        let panel = try #require(workspace.focusedTerminalPanel)
        let tabId = try #require(workspace.surfaceIdFromPanelId(panel.id))

        try expectNoTabIcon(workspace: workspace, tabId: tabId)
    }

    @MainActor
    @Test(arguments: ["claude_code", "codex"])
    func runningAgentLeavesTabIconHidden(statusKey: String) throws {
        let workspace = Workspace()
        let panel = try #require(workspace.focusedTerminalPanel)
        let tabId = try #require(workspace.surfaceIdFromPanelId(panel.id))

        workspace.updatePanelShellActivityState(panelId: panel.id, state: .commandRunning)
        workspace.recordAgentPID(
            key: "\(statusKey).terminal-icon-regression",
            pid: pid_t(ProcessInfo.processInfo.processIdentifier),
            panelId: panel.id,
            refreshPorts: false
        )
        workspace.applyProgramStatus(.init(state: .working, app: statusKey), panelId: panel.id)

        try expectNoTabIcon(workspace: workspace, tabId: tabId)
    }

    @MainActor
    @Test(arguments: [
        "claude_code",
        "codex",
        "opencode",
        "pi",
        "omp",
        "grok",
        "rovodev",
        "antigravity",
        "hermes-agent",
    ])
    func clearedAgentLeavesNoAgentMark(statusKey: String) throws {
        let workspace = Workspace()
        let panel = try #require(workspace.focusedTerminalPanel)
        let tabId = try #require(workspace.surfaceIdFromPanelId(panel.id))
        let key = "\(statusKey).terminal-icon-regression"

        workspace.updatePanelShellActivityState(panelId: panel.id, state: .commandRunning)
        workspace.recordAgentPID(
            key: key,
            pid: pid_t(ProcessInfo.processInfo.processIdentifier),
            panelId: panel.id,
            refreshPorts: false
        )
        #expect(workspace.clearAgentPID(key: key, panelId: panel.id, refreshPorts: false))

        try expectNoTabIcon(workspace: workspace, tabId: tabId)
    }

    @MainActor
    @Test func agentLookingTitleGetsNoAgentMark() throws {
        let workspace = Workspace()
        let panel = try #require(workspace.focusedTerminalPanel)
        let tabId = try #require(workspace.surfaceIdFromPanelId(panel.id))

        workspace.updatePanelShellActivityState(panelId: panel.id, state: .commandRunning)
        #expect(workspace.updatePanelTitle(panelId: panel.id, title: "codex --yolo"))

        try expectNoTabIcon(workspace: workspace, tabId: tabId)
    }

    @MainActor
    @Test func restoredAgentThatQuitToTheShellLeavesNoAgentMark() throws {
        let workspace = Workspace()
        let panel = try #require(workspace.focusedTerminalPanel)
        let tabId = try #require(workspace.surfaceIdFromPanelId(panel.id))

        workspace.restoredAgentLifecycle.setSnapshot(
            restoredAgentSnapshot(kind: .codex),
            panelId: panel.id
        )
        workspace.restoredAgentLifecycle.setResumeState(
            .awaitingAutoResumeCommand,
            panelId: panel.id
        )
        workspace.updatePanelShellActivityState(panelId: panel.id, state: .commandRunning)
        #expect(workspace.restoredAgentResumeStatesByPanelId[panel.id] == .autoResumeCommandRunning)
        try expectNoTabIcon(workspace: workspace, tabId: tabId)

        // The agent quits and the shell prompt returns.
        workspace.updatePanelShellActivityState(panelId: panel.id, state: .promptIdle)
        #expect(workspace.restoredAgentResumeStatesByPanelId[panel.id] == .completedAgentExit)

        try expectNoTabIcon(workspace: workspace, tabId: tabId)
    }

    // A restored tab that has not resumed its agent yet shows no agent mark:
    // after a relaunch, a tab waiting to auto-resume or offering a manual
    // resume looks like a plain terminal until the agent command runs.
    @MainActor
    @Test func restoredAgentThatHasNotResumedGetsNoAgentMark() throws {
        for state: Workspace.RestoredAgentResumeState in [.awaitingAutoResumeCommand, .manualResumeAvailable] {
            let workspace = Workspace()
            let panel = try #require(workspace.focusedTerminalPanel)
            let tabId = try #require(workspace.surfaceIdFromPanelId(panel.id))

            workspace.restoredAgentLifecycle.setSnapshot(
                restoredAgentSnapshot(kind: .codex),
                panelId: panel.id
            )
            workspace.restoredAgentLifecycle.setResumeState(state, panelId: panel.id)
            #expect(workspace.restoredAgentResumeStatesByPanelId[panel.id] == state)

            try expectNoTabIcon(workspace: workspace, tabId: tabId)
        }
    }

    @MainActor
    private func expectNoTabIcon(workspace: Workspace, tabId: TabID) throws {
        let tab = try #require(workspace.bonsplitController.tab(tabId))
        #expect(tab.iconAsset == nil)
        #expect(tab.iconImageData == nil)
        #expect(tab.icon == nil)
    }

    private func restoredAgentSnapshot(kind: RestorableAgentKind) -> SessionRestorableAgentSnapshot {
        SessionRestorableAgentSnapshot(
            kind: kind,
            sessionId: "\(kind.rawValue)-terminal-tab-icon-session",
            workingDirectory: "/tmp/cmux-terminal-tab-icon",
            launchCommand: AgentLaunchCommandSnapshot(
                launcher: kind.rawValue,
                executablePath: "/usr/local/bin/\(kind.rawValue)",
                arguments: ["/usr/local/bin/\(kind.rawValue)"],
                workingDirectory: "/tmp/cmux-terminal-tab-icon",
                environment: nil,
                capturedAt: 1_777_777_777,
                source: "test"
            )
        )
    }
}
