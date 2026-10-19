//
//  FileHideManager.swift
//  UnzipLite
//
//  文件隐藏管理器 - 实现在「文件」应用中隐藏/显示文件
//
//  原理：
//  - iOS 的「文件」(Files) 应用通过 UIFileSharingEnabled 显示应用的 Documents 目录
//  - Documents 目录下的文件在 Files 应用中可见
//  - Library 目录下的文件在 Files 应用中不可见
//  - 开启"隐藏文件"时，将 Documents 中的文件移动到 Library/HiddenFiles/
//  - 关闭时，移回 Documents/
//  - 应用内文件浏览器始终合并显示两个目录的内容
//

import Foundation

/// 文件隐藏管理器（单例）
final class FileHideManager {

    static let shared = FileHideManager()

    let fileManager = FileManager.default
    private let defaults = UserDefaults.standard

    // MARK: - 目录路径

    /// Documents 目录（在 Files 应用中可见）
    var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 隐藏文件目录（在 Files 应用中不可见）
    var hiddenFilesURL: URL {
        let libraryURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return libraryURL.appendingPathComponent("HiddenFiles", isDirectory: true)
    }

    // MARK: - UserDefaults Keys

    private let kHideInFilesApp = "kHideInFilesApp"
    private let kHasMigratedInitialFiles = "kHasMigratedInitialFiles"

    // MARK: - 隐藏状态

    /// 是否在「文件」应用中隐藏文件
    var isHidingInFilesApp: Bool {
        get { defaults.bool(forKey: kHideInFilesApp) }
        set {
            defaults.set(newValue, forKey: kHideInFilesApp)
            defaults.synchronize()
        }
    }

    // MARK: - 初始化

    private init() {}

    /// 准备目录结构（应用启动时调用）
    func prepareDirectories() {
        // 确保隐藏目录存在
        if !fileManager.fileExists(atPath: hiddenFilesURL.path) {
            try? fileManager.createDirectory(at: hiddenFilesURL,
                                           withIntermediateDirectories: true,
                                           attributes: nil)
        }

        // 首次启动时，如果隐藏开关已开启，执行一次迁移
        if isHidingInFilesApp && !defaults.bool(forKey: kHasMigratedInitialFiles) {
            try? migrateToHidden()
            defaults.set(true, forKey: kHasMigratedInitialFiles)
        }
    }

    // MARK: - 隐藏/显示切换

    /// 开启隐藏：将 Documents 中的所有文件移动到隐藏目录
    func enableHiding(completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                try self.migrateToHidden()
                self.isHidingInFilesApp = true
                DispatchQueue.main.async {
                    completion?(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion?(false, error)
                }
            }
        }
    }

    /// 关闭隐藏：将隐藏目录中的文件移回 Documents
    func disableHiding(completion: ((Bool, Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                try self.migrateToVisible()
                self.isHidingInFilesApp = false
                DispatchQueue.main.async {
                    completion?(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion?(false, error)
                }
            }
        }
    }

    // MARK: - 文件迁移

    /// 将 Documents 中的文件移动到隐藏目录
    private func migrateToHidden() throws {
        let docs = try fileManager.contentsOfDirectory(at: documentsURL,
                                                        includingPropertiesForKeys: nil,
                                                        options: [.skipsHiddenFiles])
        for url in docs {
            let destURL = hiddenFilesURL.appendingPathComponent(url.lastPathComponent)
            // 如果目标已存在，先删除
            if fileManager.fileExists(atPath: destURL.path) {
                try? fileManager.removeItem(at: destURL)
            }
            try fileManager.moveItem(at: url, to: destURL)
        }
    }

    /// 将隐藏目录中的文件移回 Documents
    private func migrateToVisible() throws {
        let hidden = try fileManager.contentsOfDirectory(at: hiddenFilesURL,
                                                          includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles])
        for url in hidden {
            let destURL = documentsURL.appendingPathComponent(url.lastPathComponent)
            if fileManager.fileExists(atPath: destURL.path) {
                try? fileManager.removeItem(at: destURL)
            }
            try fileManager.moveItem(at: url, to: destURL)
        }
    }

    // MARK: - 文件操作（应用内统一接口）

    /// 获取当前应显示的根目录（应用内浏览用）
    /// 无论隐藏状态如何，应用内都能看到所有文件
    var currentRootURL: URL {
        return isHidingInFilesApp ? hiddenFilesURL : documentsURL
    }

    /// 列出指定目录下的文件项
    func contentsOfDirectory(at url: URL) -> [FileItem] {
        guard let urls = try? fileManager.contentsOfDirectory(at: url,
                                                               includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                                                               options: [.skipsHiddenFiles]) else {
            return []
        }
        return urls.map { FileItem(url: $0) }.sorted()
    }

    /// 在当前根目录下创建新文件夹
    @discardableResult
    func createFolder(named name: String, at directory: URL) -> Bool {
        let folderURL = directory.appendingPathComponent(name, isDirectory: true)
        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false, attributes: nil)
            return true
        } catch {
            return false
        }
    }

    /// 删除文件
    @discardableResult
    func deleteItem(at url: URL) -> Bool {
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    /// 重命名文件
    @discardableResult
    func renameItem(at url: URL, to newName: String) -> Bool {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try fileManager.moveItem(at: url, to: newURL)
            return true
        } catch {
            return false
        }
    }

    /// 导入外部文件到当前根目录
    func importFile(from sourceURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let destURL = self.currentRootURL.appendingPathComponent(sourceURL.lastPathComponent)
            do {
                // 确保源文件可访问
                let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if shouldStopAccessing {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                if self.fileManager.fileExists(atPath: destURL.path) {
                    try? self.fileManager.removeItem(at: destURL)
                }
                try self.fileManager.copyItem(at: sourceURL, to: destURL)
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error)
                }
            }
        }
    }

    /// 获取目录总大小
    func directorySize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: url,
                                                    includingPropertiesForKeys: [.fileSizeKey],
                                                    options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        return totalSize
    }
}
