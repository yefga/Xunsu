//
//  DurationFormatter.swift
//  Xunsu
//
//  Created by Yefga on 29/03/26.
//

import Foundation

/// Formats time intervals into human-readable strings
public struct DurationFormatter {

    /// Format a duration with appropriate unit (ms, s, min)
    /// - Parameter duration: TimeInterval in seconds
    /// - Returns: Formatted string like "123ms", "4.5s", "2m 30s"
    public static func format(_ duration: TimeInterval) -> String {
        if duration < 0.001 {
            return "<1ms"
        } else if duration < 1.0 {
            // Show milliseconds
            let ms = Int(duration * 1000)
            return "\(ms)ms"
        } else if duration < 60.0 {
            // Show seconds with 1 decimal
            return String(format: "%.1fs", duration)
        } else if duration < 3600.0 {
            // Show minutes and seconds
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            if seconds == 0 {
                return "\(minutes)m"
            }
            return "\(minutes)m \(seconds)s"
        } else {
            // Show hours, minutes, seconds
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            let seconds = Int(duration) % 60
            if seconds == 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(hours)h \(minutes)m \(seconds)s"
        }
    }
}

/// Formats file sizes into human-readable strings
public struct FileSizeFormatter {

    /// Format file size with appropriate unit (B, KB, MB, GB)
    /// - Parameter bytes: Size in bytes
    /// - Returns: Formatted string like "1.5MB", "256KB", "2.3GB"
    public static func format(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1.0 {
            return String(format: "%.2fGB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.1fMB", mb)
        } else if kb >= 1.0 {
            return String(format: "%.0fKB", kb)
        } else {
            return "\(bytes)B"
        }
    }

    /// Get file size at path
    /// - Parameter path: File path
    /// - Returns: Formatted size string or nil if file doesn't exist
    public static func sizeOfFile(at path: URL) -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
              let size = attrs[.size] as? UInt64 else {
            return nil
        }
        return format(size)
    }

    /// Get total size of directory
    /// - Parameter path: Directory path
    /// - Returns: Formatted size string or nil if directory doesn't exist
    public static func sizeOfDirectory(at path: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var totalSize: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = attrs.fileSize {
                totalSize += UInt64(size)
            }
        }
        return format(totalSize)
    }
}
