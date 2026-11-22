import Bonsplit
import CmuxSidebar
import Foundation

/// Resolves the provider mark for a local terminal tab from the same agent
/// definitions used by process and hook detection.
struct TerminalTabAgentIconResolver {
    func assetName(forStatusKey statusKey: String) -> String? {
        let normalized = statusKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return CmuxTaskManagerCodingAgentDefinition.builtIns.first { definition in
            definition.id == normalized
                || definition.launchKinds.contains(normalized)
                || definition.directBasenames.contains(normalized)
        }?.assetName
    }
}

extension Workspace {
    /// Returns the current provider mark for one terminal panel, if known.
    func terminalTabAgentIconAsset(forPanelId panelId: UUID) -> String? {
        let resolver = TerminalTabAgentIconResolver()
        let statusKeys = agentPIDKeysByPanelId[panelId, default: []]
            .map(agentStatusKey(forAgentPIDKey:))
            .sorted()
        if let asset = statusKeys.compactMap(resolver.assetName(forStatusKey:)).first {
            return asset
        }
        // A restored snapshot outlives its agent (completed sessions stay for
        // history), so it only names the tab while that agent is running.
        if let restored = restoredAgentSnapshotsByPanelId[panelId],
           restoredAgentIsRunning(panelId: panelId),
           let asset = restored.registration?.iconAssetName ?? resolver.assetName(forStatusKey: restored.kind.rawValue) {
            return asset
        }
        return terminalTabProgramIconAssetsByPanelId[panelId]
    }

    /// Keeps the provider mark while the foreground agent waits for input.
    func updateTerminalTabProgramIcon(forPanelId panelId: UUID, store: ProgramStatusRecordStore) {
        guard panelShellActivityStates[panelId] != .promptIdle else { return }
        let resolver = TerminalTabAgentIconResolver()
        for record in store.records.sorted(by: { $0.updateOrder > $1.updateOrder }) {
            if let app = store.effectiveApp(for: record),
               let asset = resolver.assetName(forStatusKey: app) {
                terminalTabProgramIconAssetsByPanelId[panelId] = asset
                break
            }
        }
        syncTerminalTabAgentIconAsset(forPanelId: panelId)
    }

    func clearTerminalTabProgramIcon(forPanelId panelId: UUID) {
        guard terminalTabProgramIconAssetsByPanelId.removeValue(forKey: panelId) != nil else { return }
        syncTerminalTabAgentIconAsset(forPanelId: panelId)
    }

    private func restoredAgentIsRunning(panelId: UUID) -> Bool {
        switch restoredAgentResumeStatesByPanelId[panelId] {
        case .autoResumeCommandRunning, .observedAgentCommandRunning:
            return true
        case .manualResumeAvailable, .awaitingAutoResumeCommand, .completedAgentExit, nil:
            return false
        }
    }

    /// Reconciles a terminal tab's provider mark after agent lifecycle state changes.
    func syncTerminalTabAgentIconAsset(forPanelId panelId: UUID) {
        guard panels[panelId] is TerminalPanel,
              let tabID = surfaceIdFromPanelId(panelId),
              let tab = bonsplitController.tab(tabID) else { return }
        let asset = terminalTabAgentIconAsset(forPanelId: panelId)
        guard tab.iconAsset != asset else { return }
        bonsplitController.updateTab(tabID, iconAsset: .some(asset))
    }
}
