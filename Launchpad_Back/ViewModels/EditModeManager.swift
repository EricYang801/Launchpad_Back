//
//  EditModeManager.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/15.
//

import SwiftUI
import Combine

/// 編輯模式管理器
/// 負責管理 Launchpad 的編輯模式狀態
final class EditModeManager: ObservableObject {
    /// 是否處於編輯模式
    @Published var isEditing = false
    
    /// 進入編輯模式
    func enterEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = true
        }
        Logger.info("Entered edit mode")
    }
    
    /// 退出編輯模式
    func exitEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isEditing = false
        }
        Logger.info("Exited edit mode")
    }
}
