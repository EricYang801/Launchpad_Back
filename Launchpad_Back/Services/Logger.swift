//
//  Logger.swift
//  Launchpad_Back
//
//  Created by Eric Yang on 2025/1/14.
//

import Foundation

/// 日誌級別
enum LogLevel: String {
    case debug = "🔵 DEBUG"
    case info = "🟢 INFO"
    case warning = "🟡 WARNING"
    case error = "🔴 ERROR"
}

/// 簡單的日誌系統
struct Logger {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    /// 調試日誌
    static func debug(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: .debug, file: file, line: line)
    }
    
    /// 信息日誌
    static func info(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: .info, file: file, line: line)
    }
    
    /// 警告日誌
    static func warning(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: .warning, file: file, line: line)
    }
    
    /// 錯誤日誌
    static func error(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: .error, file: file, line: line)
    }
    
    /// 錯誤日誌（帶 Error 對象）
    static func error(_ error: Error, file: String = #file, line: Int = #line) {
        let message = "\(error.localizedDescription)"
        log(message, level: .error, file: file, line: line)
    }
    
    private static func log(_ message: String, level: LogLevel, file: String, line: Int) {
        #if DEBUG
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] \(level.rawValue) [\(fileName):\(line)] \(message)")
        #endif
    }
}
