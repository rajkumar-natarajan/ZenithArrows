// GridOverlayManager.swift
// ZenithArrows
//
// Feature: Grid coordinate overlay — shows row/column numbers on cells.
// Requested by Arrow Out users to help with fat-finger accuracy.
// Toggled per-session (not persisted); resets each game launch.

import Foundation
import Combine

@MainActor
final class GridOverlayManager: ObservableObject {

    static let shared = GridOverlayManager()

    /// When true, GridNode renders row/col index labels in each cell.
    @Published var showCoordinates: Bool = false

    /// When true, moveable arrows show a subtle green ring indicator.
    @Published var showMoveableIndicators: Bool = true

    private let moveableKey = "zenith_moveable_indicators_v1"

    private init() {
        showMoveableIndicators = UserDefaults.standard.object(forKey: moveableKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: moveableKey)
    }

    func toggleCoordinates() {
        showCoordinates.toggle()
    }

    func toggleMoveableIndicators() {
        showMoveableIndicators.toggle()
        UserDefaults.standard.set(showMoveableIndicators, forKey: moveableKey)
    }
}
