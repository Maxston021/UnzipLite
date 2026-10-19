//
//  MainTabBarController.swift
//  UnzipLite
//
//  主标签栏 - 文件页 + 设置页
//

import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        setupAppearance()
    }

    private func setupViewControllers() {
        // 文件页
        let fileBrowserVC = FileBrowserViewController()
        fileBrowserVC.title = "文件"
        let fileNav = UINavigationController(rootViewController: fileBrowserVC)
        fileNav.tabBarItem = UITabBarItem(
            title: "文件",
            image: UIImage(systemName: "folder"),
            selectedImage: UIImage(systemName: "folder.fill")
        )

        // 设置页
        let settingsVC = SettingsViewController()
        settingsVC.title = "设置"
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(
            title: "设置",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        viewControllers = [fileNav, settingsNav]
    }

    private func setupAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = .systemOrange
    }
}
