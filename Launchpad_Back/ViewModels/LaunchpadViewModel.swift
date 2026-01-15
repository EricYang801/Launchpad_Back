//
//  LaunchpadViewModel.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import SwiftUI
import Combine

/// 主要的 Launchpad ViewModel
/// 負責應用程式列表的管理和狀態
class LaunchpadViewModel: ObservableObject {
    @Published var apps: [AppItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let scannerService: AppScannerService
    private let launcherService: AppLauncherService
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        scannerService: AppScannerService = AppScannerService(),
        launcherService: AppLauncherService = AppLauncherService()
    ) {
        self.scannerService = scannerService
        self.launcherService = launcherService
        Logger.info("LaunchpadViewModel initialized")
    }
    
    deinit {
        Logger.debug("LaunchpadViewModel deinitialized")
    }
    
    /// 加載已安裝的應用程式
    func loadInstalledApps() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        Logger.info("Starting app loading...")
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            do {
                let apps = self?.scannerService.scanInstalledApps() ?? []
                
                DispatchQueue.main.async {
                    self?.apps = apps
                    self?.isLoading = false
                    Logger.info("App loading completed. Found \(apps.count) applications")
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "Failed to load apps: \(error.localizedDescription)"
                    Logger.error(error)
                }
            }
        }
    }
    
    /// 啟動應用程式
    /// - Parameter app: 要啟動的應用程式
    func launchApp(_ app: AppItem) {
        Logger.info("Launching app: \(app.name)")
        
        launcherService.launchAsync(app) { [weak self] success in
            if success {
                Logger.info("Successfully launched: \(app.name)")
            } else {
                let errorMsg = "Failed to launch: \(app.name)"
                Logger.error(errorMsg)
                self?.errorMessage = errorMsg
            }
        }
    }
    
    /// 刷新應用程式列表
    func refreshApps() {
        Logger.info("Refreshing app list...")
        apps.removeAll()
        AppIconCache.shared.clearCache()
        loadInstalledApps()
    }
    
    /// 清除錯誤訊息
    func clearError() {
        errorMessage = nil
    }
}
