//
//  FileItem.swift
//  UnzipLite
//
//  文件项模型 - 表示文件或目录
//

import Foundation
import UIKit

/// 文件类型枚举
enum FileType {
    case folder
    case archive        // zip, rar, 7z, tar 等
    case image
    case video
    case audio
    case document       // pdf, doc, xls, ppt, txt 等
    case ebook          // epub, chm, fb2
    case unknown

    /// 根据文件扩展名判断类型
    static func from(extension ext: String) -> FileType {
        let e = ext.lowercased()
        switch e {
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "lzma", "cab", "deb", "rpm", "ace", "arj", "lha", "lzh", "jar", "war", "ear":
            return .archive
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "ico", "webp", "psd":
            return .image
        case "mp4", "mov", "avi", "mkv", "wmv", "flv", "mpeg", "mpg", "m4v", "3gp":
            return .video
        case "mp3", "wav", "flac", "aac", "m4a", "ogg", "wma", "ape", "aiff":
            return .audio
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "html", "htm", "xml", "json", "csv", "md", "pages", "numbers", "keynote":
            return .document
        case "epub", "chm", "fb2", "mobi", "azw":
            return .ebook
        default:
            return .unknown
        }
    }

    /// 对应图标
    var icon: UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        switch self {
        case .folder:
            return UIImage(systemName: "folder.fill", withConfiguration: config)?
                .withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
        case .archive:
            return UIImage(systemName: "archivebox.fill", withConfiguration: config)?
                .withTintColor(.systemOrange, renderingMode: .alwaysOriginal)
        case .image:
            return UIImage(systemName: "photo.fill", withConfiguration: config)?
                .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        case .video:
            return UIImage(systemName: "film.fill", withConfiguration: config)?
                .withTintColor(.systemPurple, renderingMode: .alwaysOriginal)
        case .audio:
            return UIImage(systemName: "music.note", withConfiguration: config)?
                .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
        case .document:
            return UIImage(systemName: "doc.text.fill", withConfiguration: config)?
                .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        case .ebook:
            return UIImage(systemName: "book.fill", withConfiguration: config)?
                .withTintColor(.systemBrown, renderingMode: .alwaysOriginal)
        case .unknown:
            return UIImage(systemName: "doc.fill", withConfiguration: config)?
                .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        }
    }
}

/// 文件项模型
struct FileItem {
    let url: URL
    let name: String
    let type: FileType
    let size: Int64
    let modificationDate: Date
    let isDirectory: Bool

    /// 格式化文件大小
    var sizeString: String {
        if isDirectory { return "—" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// 格式化修改日期
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }

    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

        if self.isDirectory {
            self.type = .folder
        } else {
            self.type = FileType.from(extension: url.pathExtension)
        }

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        self.size = Int64(values?.fileSize ?? 0)
        self.modificationDate = values?.contentModificationDate ?? Date()
    }
}

// MARK: - 排序

extension FileItem: Comparable {
    static func < (lhs: FileItem, rhs: FileItem) -> Bool {
        // 文件夹排在前面
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory && !rhs.isDirectory
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
