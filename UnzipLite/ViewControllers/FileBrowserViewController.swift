//
//  FileBrowserViewController.swift
//  UnzipLite
//
//  文件浏览器 - 正常访问系统目录，支持导航、导入、新建文件夹、删除、重命名
//

import UIKit
import UniformTypeIdentifiers

class FileBrowserViewController: UIViewController {

    // MARK: - UI 元素

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        tv.register(FileCell.self, forCellReuseIdentifier: FileCell.reuseID)
        tv.rowHeight = 64
        return tv
    }()

    private lazy var emptyStateView: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true

        let icon = UIImageView(image: UIImage(systemName: "folder.badge.plus"))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = .systemGray3
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 48)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "暂无文件\n点击右上角导入文件或新建文件夹"
        label.textAlignment = .center
        label.textColor = .systemGray
        label.font = .systemFont(ofSize: 15)
        label.numberOfLines = 0

        container.addSubview(icon)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -30),
            icon.widthAnchor.constraint(equalToConstant: 60),
            icon.heightAnchor.constraint(equalToConstant: 60),
            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 16),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -40),
        ])
        return container
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.translatesAutoresizingMaskIntoConstraints = false
        ai.hidesWhenStopped = true
        return ai
    }()

    // MARK: - 数据

    private var currentURL: URL!
    private var items: [FileItem] = []
    private let fileManager = FileHideManager.shared

    // MARK: - 初始化

    init(rootURL: URL? = nil) {
        super.init(nibName: nil, bundle: nil)
        if let rootURL = rootURL {
            self.currentURL = rootURL
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        if currentURL == nil {
            currentURL = fileManager.currentRootURL
        }
        setupUI()
        setupNavigationBar()
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从设置页返回时，隐藏状态可能已切换，文件在 Documents/HiddenFiles 间移动
        // 如果当前目录已不存在（被移走了），回到根目录
        let currentPath = currentURL.path
        if !FileManager.default.fileExists(atPath: currentPath) {
            currentURL = fileManager.currentRootURL
            updateTitle()
        } else if currentURL == fileManager.documentsURL || currentURL == fileManager.hiddenFilesURL {
            // 在根目录级别时，同步到当前活动根目录
            currentURL = fileManager.currentRootURL
            updateTitle()
        }
        reloadData()
    }

    // MARK: - UI 设置

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupNavigationBar() {
        updateTitle()

        // 右侧：导入 + 新建文件夹
        let importAction = UIAction(title: "导入文件", image: UIImage(systemName: "square.and.arrow.down")) { [weak self] _ in
            self?.presentDocumentPicker()
        }
        let folderAction = UIAction(title: "新建文件夹", image: UIImage(systemName: "folder.badge.plus")) { [weak self] _ in
            self?.presentNewFolderAlert()
        }
        let menu = UIMenu(title: "", children: [importAction, folderAction])
        let moreButton = UIBarButtonItem(title: "＋", style: .plain, target: self, action: #selector(showAddMenu))
        moreButton.menu = menu
        navigationItem.rightBarButtonItem = moreButton

        // 大标题
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    private func updateTitle() {
        if currentURL == fileManager.documentsURL || currentURL == fileManager.hiddenFilesURL {
            title = "文件"
            navigationItem.largeTitleDisplayMode = .always
        } else {
            title = currentURL.lastPathComponent
            navigationItem.largeTitleDisplayMode = .never
        }
    }

    // MARK: - 数据加载

    private func reloadData() {
        items = fileManager.contentsOfDirectory(at: currentURL)
        tableView.reloadData()
        emptyStateView.isHidden = !items.isEmpty
    }

    // MARK: - 导入文件

    private func presentDocumentPicker() {
        let types: [UTType] = [
            .data, .folder, .archive, .image, .movie, .audio,
            .pdf, .text, .html, .xml, .json, .spreadsheet, .presentation,
            UTType("com.pkware.zip-archive") ?? .data,
            UTType("public.rar-archive") ?? .data,
            UTType("org.7-zip.7-zip-archive") ?? .data,
        ]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    // MARK: - 新建文件夹

    private func presentNewFolderAlert() {
        let alert = UIAlertController(title: "新建文件夹", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "文件夹名称"
            tf.clearButtonMode = .whileEditing
        }
        let cancel = UIAlertAction(title: "取消", style: .cancel)
        let confirm = UIAlertAction(title: "创建", style: .default) { [weak self] _ in
            guard let self = self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
            if self.fileManager.createFolder(named: name, at: self.currentURL) {
                self.reloadData()
            } else {
                self.showToast("创建失败，名称可能已存在")
            }
        }
        alert.addAction(cancel)
        alert.addAction(confirm)
        present(alert, animated: true)
    }

    // MARK: - 文件操作

    private func deleteItem(at indexPath: IndexPath) {
        let item = items[indexPath.row]
        let alert = UIAlertController(title: "删除", message: "确定删除「\(item.name)」吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            if self.fileManager.deleteItem(at: item.url) {
                self.items.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                self.emptyStateView.isHidden = !self.items.isEmpty
            } else {
                self.showToast("删除失败")
            }
        })
        present(alert, animated: true)
    }

    private func renameItem(at indexPath: IndexPath) {
        let item = items[indexPath.row]
        let alert = UIAlertController(title: "重命名", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = item.name
            tf.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let self = self, let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            if self.fileManager.renameItem(at: item.url, to: newName) {
                self.reloadData()
            } else {
                self.showToast("重命名失败")
            }
        })
        present(alert, animated: true)
    }

    private func shareItem(at indexPath: IndexPath) {
        let item = items[indexPath.row]
        let activityVC = UIActivityViewController(activityItems: [item.url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: indexPath)
        }
        present(activityVC, animated: true)
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension FileBrowserViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileCell.reuseID, for: indexPath) as! FileCell
        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]

        if item.isDirectory {
            // 进入子目录
            let subVC = FileBrowserViewController(rootURL: item.url)
            subVC.title = item.name
            navigationController?.pushViewController(subVC, animated: true)
        } else {
            // 预览文件
            let previewVC = FilePreviewViewController(fileItem: item)
            let nav = UINavigationController(rootViewController: previewVC)
            present(nav, animated: true)
        }
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "删除") { [weak self] (_, _, completion) in
            self?.deleteItem(at: indexPath)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")

        let rename = UIContextualAction(style: .normal, title: "重命名") { [weak self] (_, _, completion) in
            self?.renameItem(at: indexPath)
            completion(true)
        }
        rename.image = UIImage(systemName: "pencil")
        rename.backgroundColor = .systemOrange

        let share = UIContextualAction(style: .normal, title: "分享") { [weak self] (_, _, completion) in
            self?.shareItem(at: indexPath)
            completion(true)
        }
        share.image = UIImage(systemName: "square.and.arrow.up")
        share.backgroundColor = .systemBlue

        return UISwipeActionsConfiguration(actions: [delete, rename, share])
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if currentURL == fileManager.documentsURL || currentURL == fileManager.hiddenFilesURL {
            let totalSize = fileManager.directorySize(at: currentURL)
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "共 \(items.count) 个项目 · \(formatter.string(fromByteCount: totalSize))"
        }
        return nil
    }
}

// MARK: - UIDocumentPickerDelegate

extension FileBrowserViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        activityIndicator.startAnimating()
        let group = DispatchGroup()
        var successCount = 0

        for url in urls {
            group.enter()
            fileManager.importFile(from: url) { success, _ in
                if success { successCount += 1 }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.activityIndicator.stopAnimating()
            self?.reloadData()
            if successCount > 0 {
                self?.showToast("已导入 \(successCount) 个文件")
            }
        }
    }
}

// MARK: - Actions

extension FileBrowserViewController {
    @objc private func showAddMenu() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "导入文件", style: .default) { [weak self] _ in
            self?.presentDocumentPicker()
        })
        alert.addAction(UIAlertAction(title: "新建文件夹", style: .default) { [weak self] _ in
            self?.presentNewFolderAlert()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }
}
