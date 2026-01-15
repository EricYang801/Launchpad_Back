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
class EditModeManager: ObservableObject {
    /// 是否處於編輯模式
    @Published var isEditing = false
    
    /// 當前正在拖動的項目 ID
    @Published var draggingItemId: String?
    
    /// 當前拖動的位置
    @Published var dragLocation: CGPoint?
    
    /// 拖動懸停的目標項目 ID（用於創建文件夾）
    @Published var dropTargetId: String?
    
    /// 長按持續時間（秒）
    private let longPressDuration: TimeInterval = 0.5
    
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
            draggingItemId = nil
            dragLocation = nil
            dropTargetId = nil
        }
        Logger.info("Exited edit mode")
    }
    
    /// 開始拖動項目
    func startDragging(itemId: String, location: CGPoint) {
        draggingItemId = itemId
        dragLocation = location
        Logger.debug("Started dragging item: \(itemId)")
    }
    
    /// 更新拖動位置
    func updateDragLocation(_ location: CGPoint) {
        dragLocation = location
    }
    
    /// 設置放置目標
    func setDropTarget(_ itemId: String?) {
        if dropTargetId != itemId {
            withAnimation(.easeInOut(duration: 0.15)) {
                dropTargetId = itemId
            }
        }
    }
    
    /// 結束拖動
    func endDragging() {
        draggingItemId = nil
        dragLocation = nil
        dropTargetId = nil
        Logger.debug("Ended dragging")
    }
    
    /// 長按持續時間
    var longPressMinimumDuration: Double {
        longPressDuration
    }
}
