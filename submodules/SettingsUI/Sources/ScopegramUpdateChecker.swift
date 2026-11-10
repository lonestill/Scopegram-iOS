import Foundation
import UIKit
import Display

public struct ScopegramReleaseInfo {
    public let tagName: String
    public let name: String
    public let body: String
    public let htmlUrl: String
    public let downloadUrl: String?
    
    public init(tagName: String, name: String, body: String, htmlUrl: String, downloadUrl: String?) {
        self.tagName = tagName
        self.name = name
        self.body = body
        self.htmlUrl = htmlUrl
        self.downloadUrl = downloadUrl
    }
}

public final class ScopegramUpdateChecker {
    public static let shared = ScopegramUpdateChecker()
    
    public static let currentVersion = "1.0.0"
    public static let repo = "lonestill/Scopegram-iOS"
    
    private init() {}
    
    public static func isVersionNewer(remote: String, local: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocal = local.trimmingCharacters(in: CharacterSet(charactersIn: "vV")).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let remoteParts = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let localParts = cleanLocal.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(remoteParts.count, localParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l {
                return true
            } else if r < l {
                return false
            }
        }
        return false
    }
    
    public func fetchLatestRelease(completion: @escaping (Result<ScopegramReleaseInfo, Error>) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
            completion(.failure(NSError(domain: "Scopegram", code: -1, userInfo: [NSLocalizedDescriptionKey: "Неверный URL репозитория"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Scopegram-iOS", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                let err = NSError(domain: "Scopegram", code: -2, userInfo: [NSLocalizedDescriptionKey: "Не удалось прочитать данные о релизе"])
                DispatchQueue.main.async { completion(.failure(err)) }
                return
            }
            
            let name = json["name"] as? String ?? tagName
            let body = json["body"] as? String ?? ""
            let htmlUrl = json["html_url"] as? String ?? "https://github.com/\(Self.repo)/releases"
            
            var downloadUrl: String? = nil
            if let assets = json["assets"] as? [[String: Any]] {
                for asset in assets {
                    if let assetName = asset["name"] as? String,
                       (assetName.hasSuffix(".ipa") || assetName.hasSuffix(".zip")),
                       let browserDownloadUrl = asset["browser_download_url"] as? String {
                        downloadUrl = browserDownloadUrl
                        break
                    }
                }
            }
            
            let release = ScopegramReleaseInfo(
                tagName: tagName,
                name: name,
                body: body,
                htmlUrl: htmlUrl,
                downloadUrl: downloadUrl
            )
            DispatchQueue.main.async { completion(.success(release)) }
        }
        task.resume()
    }
    
    public func checkOnLaunch() {
        let now = Date().timeIntervalSince1970
        let lastCheck = UserDefaults.standard.double(forKey: "ScopegramLastUpdateCheck")
        if now - lastCheck < 6 * 3600 {
            return
        }
        
        fetchLatestRelease { [weak self] result in
            guard let self = self else { return }
            UserDefaults.standard.set(now, forKey: "ScopegramLastUpdateCheck")
            
            switch result {
            case .success(let release):
                if Self.isVersionNewer(remote: release.tagName, local: Self.currentVersion) {
                    let lastAlertedTag = UserDefaults.standard.string(forKey: "ScopegramAlertedTag")
                    if lastAlertedTag != release.tagName {
                        UserDefaults.standard.set(release.tagName, forKey: "ScopegramAlertedTag")
                        self.showUpdateAlert(release: release)
                    }
                }
            case .failure:
                break
            }
        }
    }
    
    public func checkManual(from viewController: UIViewController) {
        let loadingAlert = UIAlertController(title: "Scopegram Updates", message: "Подключение к GitHub...", preferredStyle: .alert)
        viewController.present(loadingAlert, animated: true)
        
        fetchLatestRelease { [weak self] result in
            loadingAlert.dismiss(animated: true) {
                guard let self = self else { return }
                switch result {
                case .success(let release):
                    if Self.isVersionNewer(remote: release.tagName, local: Self.currentVersion) {
                        self.showUpdateAlert(release: release, presenter: viewController)
                    } else {
                        let alert = UIAlertController(
                            title: "Обновлений нет",
                            message: "У вас установлена самая свежая версия Scopegram (v\(Self.currentVersion)).",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "Отлично", style: .default))
                        viewController.present(alert, animated: true)
                    }
                case .failure(let error):
                    let alert = UIAlertController(
                        title: "Ошибка проверки",
                        message: "Не удалось получить статус с GitHub: \(error.localizedDescription)\n\nХотите перейти на страницу релизов?",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Открыть сайт", style: .default, handler: { _ in
                        if let url = URL(string: "https://github.com/\(Self.repo)/releases") {
                            UIApplication.shared.open(url)
                        }
                    }))
                    alert.addAction(UIAlertAction(title: "Закрыть", style: .cancel))
                    viewController.present(alert, animated: true)
                }
            }
        }
    }
    
    public func showUpdateAlert(release: ScopegramReleaseInfo, presenter: UIViewController? = nil) {
        guard let hostVC = presenter ?? getTopViewController() else { return }
        
        var message = "Вышла новая версия: \(release.tagName)!"
        let cleanBody = release.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanBody.isEmpty {
            let snippet = cleanBody.count > 250 ? String(cleanBody.prefix(250)) + "..." : cleanBody
            message += "\n\nЧто нового:\n\(snippet)"
        }
        message += "\n\nСкачать обновление из GitHub Releases?"
        
        let alert = UIAlertController(
            title: "Обновление Scopegram",
            message: message,
            preferredStyle: .alert
        )
        
        let targetUrlString = release.htmlUrl
        alert.addAction(UIAlertAction(title: "Скачать", style: .default, handler: { _ in
            if let url = URL(string: targetUrlString) {
                UIApplication.shared.open(url)
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Позже", style: .cancel))
        hostVC.present(alert, animated: true)
    }
    
    private func getTopViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = UIApplication.shared.allWindowSceneWindows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? UIApplication.shared.allWindowSceneWindows.first?.rootViewController
        let base = base ?? root
        if let nav = base as? UINavigationController {
            return getTopViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return getTopViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return getTopViewController(base: presented)
        }
        return base
    }
}
