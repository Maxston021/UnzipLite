//
//  SettingsViewController.swift
//  UnzipLite
//
//  设置页 - 包含「在文件应用中隐藏文件」核心开关
//

import UIKit

class SettingsViewController: UITableViewController {

    // MARK: - Section 定义

    private enum Section: Int, CaseIterable {
        case fileVisibility  // 文件可见性
        case general         // 通用
        case about           // 关于

        var title: String? {
            switch self {
            case .fileVisibility: return "文件可见性"
            case .general: return "通用"
            case .about: return "关于"
            }
        }

        var footer: String? {
            switch self {
            case .fileVisibility:
                return "开启后，本应用的文件将从 iOS「文件」应用中隐藏，但在本应用内仍可正常访问和管理所有文件。文件会被移动到应用内部目录，不会在系统「文件」应用中显示。"
            case .general:
                return nil
            case .about:
                return "解压助手 v1.0\n基于 Unzip 基础功能复刻"
            }
        }
    }

    // MARK: - 属性

    private let fileManager = FileHideManager.shared
    private let hideSwitch = UISwitch()
    private var isProcessing = false

    // MARK: - 生命周期

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupSwitch()
    }

    private func setupTableView() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.register(SwitchCell.self, forCellReuseIdentifier: SwitchCell.reuseID)
    }

    private func setupSwitch() {
        hideSwitch.isOn = fileManager.isHidingInFilesApp
        hideSwitch.onTintColor = .systemOrange
        hideSwitch.addTarget(self, action: #selector(hideSwitchChanged(_:)), for: .valueChanged)
    }

    // MARK: - 开关事件

    @objc private func hideSwitchChanged(_ sender: UISwitch) {
        guard !isProcessing else {
            sender.isOn = !sender.isOn // 回滚
            return
        }
        isProcessing = true

        let willHide = sender.isOn
        let statusText = willHide ? "正在隐藏文件…" : "正在恢复文件…"

        // 显示处理中的 HUD
        let alert = UIAlertController(title: nil, message: statusText, preferredStyle: .alert)
        present(alert, animated: true)

        let completion: (Bool, Error?) -> Void = { [weak self] success, error in
            guard let self = self else { return }
            alert.dismiss(animated: true) {
                self.isProcessing = false
                if success {
                    let msg = willHide ? "文件已在「文件」应用中隐藏" : "文件已恢复到「文件」应用中可见"
                    self.showToast(msg)
                } else {
                    sender.isOn = !sender.isOn // 回滚开关
                    self.showToast("操作失败：\(error?.localizedDescription ?? "未知错误")")
                }
            }
        }

        if willHide {
            fileManager.enableHiding(completion: completion)
        } else {
            fileManager.disableHiding(completion: completion)
        }
    }

    private func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            alert.dismiss(animated: true)
        }
    }

    // MARK: - UITableView DataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sec = Section(rawValue: section) else { return 0 }
        switch sec {
        case .fileVisibility: return 1
        case .general: return 2
        case .about: return 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return Section(rawValue: section)?.footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sec = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch sec {
        case .fileVisibility:
            let cell = tableView.dequeueReusableCell(withIdentifier: SwitchCell.reuseID, for: indexPath) as! SwitchCell
            cell.configure(
                title: "在「文件」应用中隐藏文件",
                icon: UIImage(systemName: "eye.slash.fill"),
                iconBackgroundColor: .systemOrange,
                switchView: hideSwitch
            )
            cell.selectionStyle = .none
            return cell

        case .general:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            var config = cell.defaultContentConfiguration()
            if indexPath.row == 0 {
                config.text = "默认下载目录"
                config.secondaryText = fileManager.isHidingInFilesApp ? "应用内部（已隐藏）" : "Documents（可见）"
                config.image = UIImage(systemName: "arrow.down.circle.fill")
                config.imageProperties.tintColor = .systemBlue
            } else {
                config.text = "清理缓存"
                config.image = UIImage(systemName: "trash.fill")
                config.imageProperties.tintColor = .systemRed
                config.secondaryText = nil
            }
            cell.contentConfiguration = config
            cell.accessoryType = .disclosureIndicator
            return cell

        case .about:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            var config = cell.defaultContentConfiguration()
            if indexPath.row == 0 {
                config.text = "版本"
                config.secondaryText = "1.0 (1)"
                config.image = UIImage(systemName: "info.circle.fill")
                config.imageProperties.tintColor = .systemGray
            } else {
                config.text = "隐私政策"
                config.image = UIImage(systemName: "hand.raised.fill")
                config.imageProperties.tintColor = .systemGreen
            }
            cell.contentConfiguration = config
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let sec = Section(rawValue: indexPath.section) else { return }

        switch sec {
        case .general:
            if indexPath.row == 1 {
                clearCache()
            }
        case .about:
            if indexPath.row == 1 {
                showPrivacyPolicy()
            }
        default:
            break
        }
    }

    // MARK: - 操作

    private func clearCache() {
        let alert = UIAlertController(title: "清理缓存", message: "将清理临时文件和缓存，不会删除您的文件。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "清理", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            let cacheURL = self.fileManager.fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            if let files = try? self.fileManager.fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil) {
                for file in files {
                    try? self.fileManager.fileManager.removeItem(at: file)
                }
            }
            self.showToast("缓存已清理")
        })
        present(alert, animated: true)
    }

    private func showPrivacyPolicy() {
        let alert = UIAlertController(
            title: "隐私政策",
            message: "本应用不会收集您的个人数据。所有文件均存储在您的设备本地，不会上传到任何服务器。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - SwitchCell

class SwitchCell: UITableViewCell {
    static let reuseID = "SwitchCell"

    private let iconContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 8
        v.clipsToBounds = true
        return v
    }()

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .white
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 16)
        l.numberOfLines = 0
        return l
    }()

    private var switchView: UISwitch?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(iconContainer)
        iconContainer.addSubview(iconView)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 30),
            iconContainer.heightAnchor.constraint(equalToConstant: 30),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -80),
        ])
    }

    func configure(title: String, icon: UIImage?, iconBackgroundColor: UIColor, switchView: UISwitch) {
        titleLabel.text = title
        iconView.image = icon
        iconContainer.backgroundColor = iconBackgroundColor
        self.switchView = switchView
        accessoryView = switchView
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        accessoryView = nil
        switchView = nil
    }
}
