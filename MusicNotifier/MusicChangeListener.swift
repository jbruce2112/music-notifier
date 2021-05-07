//
//  MusicChangeListener.swift
//  MusicNotifier
//
//  Created by John on 5/6/21.
//

import Foundation
import UserNotifications

class MusicChangeListener {
    
    private let notificationCenter: NotificationCenter = DistributedNotificationCenter.default()
    
    func listen() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { [weak self] granted, error in
            guard error == nil else {
                print("error registering for notificaiton \(error!)")
                return
            }
            guard granted else {
                print("permission denied")
                return
            }
            self?.registerForNotifications()
        }
    }
    
    private func registerForNotifications() {
        notificationCenter.addObserver(forName: NSNotification.Name("com.apple.Music.playerInfo"),
                                       object: nil,
                                       queue: .main) { [weak self] notification in
            print(notification)
            notification.createContent { content in
                guard let content = content else {
                    return
                }
                self?.deliverNotification(content: content)
            }
        }
    }
    
    private func deliverNotification(content: UNNotificationContent) {
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("error delivering notification \(error)")
            }
        }
    }
}
//https://itunes.apple.com/search?term=in+decay&country=us&entity=album&limit=1&callback=jQuery111209599436147188698_1620368759198&_=1620368759199

private extension Notification {
    func createContent(completion: @escaping ((UNNotificationContent?) -> Void)) {
        
        guard let artist = userInfo?["Artist"] as? String,
              let song = userInfo?["Name"] as? String,
              let album = userInfo?["Album"] as? String else {
            completion(nil)
            return
        }
        
        downloadArtworkIfAvailable(albumName: album) { downloadedArtworkURL in
            let content = UNMutableNotificationContent()
            content.title = song
            content.body = "\(artist) - \(album)"
            
            if let downloadedArtworkURL = downloadedArtworkURL {
                let fileName = downloadedArtworkURL.lastPathComponent
                if let attachment = try? UNNotificationAttachment(identifier: fileName, url: downloadedArtworkURL, options: nil) {
                    content.attachments.append(attachment)
                }
            }
            completion(content)
        }
    }
    
    private func downloadArtworkIfAvailable(albumName: String, completion: @escaping ((URL?) -> Void)) {
        fetchArtworkURL(albumName: albumName) { artworkURL in
            downloadToUniqueFile(artworkURL: artworkURL) { fileURL in
                DispatchQueue.main.async {
                    completion(fileURL)
                }
            }
        }
    }
    
    private func downloadToUniqueFile(artworkURL: URL?, completion: @escaping ((URL?) -> Void)) {
        guard let artworkURL = artworkURL else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: artworkURL) { result, _, _ in
            guard let result = result else {
                completion(nil)
                return
            }

            let uniqueId = ProcessInfo.processInfo.globallyUniqueString
            let downloadedArtFile = FileManager.default.temporaryDirectory.appendingPathComponent(uniqueId).appendingPathExtension(artworkURL.pathExtension)

            do {
                try FileManager.default.moveItem(at: result, to: downloadedArtFile)
                completion(downloadedArtFile)
            }
            catch {
                print(error.localizedDescription)
            }
        }
        task.resume()
    }
    
    private func fetchArtworkURL(albumName: String, completion: @escaping ((URL?) -> Void)) {
        guard var components = URLComponents(string: "https://itunes.apple.com/search?country=us&entity=album&limit=1") else {
            completion(nil)
            return
        }
        
        components.queryItems?.append(URLQueryItem(name: "term", value: albumName))
        guard let url = components.url else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data,
                  let response = try? JSONDecoder().decode(AlbumArtworkResponse.self, from: data) else {
                completion(nil)
                return
            }
            
            let result = response.results.first
            completion(result?.artworkUrl100 ?? result?.artworkUrl60)
        }
        task.resume()
    }
}

struct AlbumArtworkResponse: Decodable {
    struct ArtworkResult: Decodable {
        let artworkUrl60: URL?
        let artworkUrl100: URL?
    }
    
    let results: [ArtworkResult]
}
