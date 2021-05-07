//
//  AppDelegate.swift
//  MusicNotifier
//
//  Created by John on 5/6/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private let musicListener = MusicChangeListener()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        musicListener.listen()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

