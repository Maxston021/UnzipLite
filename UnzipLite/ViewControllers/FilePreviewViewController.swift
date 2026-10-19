//
//  FilePreviewViewController.swift
//  UnzipLite
//
//  文件预览控制器 - 支持图片、文档、文本等预览
//

import UIKit
import QuickLook

class FilePreviewViewController: UIViewController {

    private let fileItem: FileItem
    private var previewView: UIView?

    init(fileItem: FileItem) {
        self.fileItem = fileItem
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupNavigationBar()
        setupPreview()
    }

    private func setupNavigationBar() {
        title = fileItem.name
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(close)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(share)
        )
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func share() {
        let activityVC = UIActivityViewController(activityItems: [fileItem.url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(activityVC, animated: true)
    }

    private func setupPreview() {
        switch fileItem.type {
        case .image:
            setupImagePreview()
        case .document where fileItem.url.pathExtension.lowercased() == "txt":
            setupTextPreview()
        default:
            setupQuickLookPreview()
        }
    }

    // MARK: - 图片预览

    private func setupImagePreview() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.delegate = self

        let imageView = UIImageView(image: UIImage(contentsOfFile: fileItem.url.path))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
        previewView = scrollView
    }

    // MARK: - 文本预览

    private func setupTextPreview() {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        if let data = try? Data(contentsOf: fileItem.url),
           let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .gbk) {
            textView.text = text
        } else {
            textView.text = "无法读取文件内容"
        }

        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - QuickLook 预览（PDF、Office 等）

    private func setupQuickLookPreview() {
        let previewVC = QLPreviewController()
        previewVC.dataSource = self
        addChild(previewVC)
        previewVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewVC.view)
        previewVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
            previewVC.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            previewVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

// MARK: - UIScrollViewDelegate

extension FilePreviewViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView.subviews.first
    }
}

// MARK: - QLPreviewControllerDataSource

extension FilePreviewViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return fileItem.url as QLPreviewItem
    }
}
