//
//  TribunetourApp.swift
//  Tribunetour
//
//  Created by Martin Toudal on 03/02/2026.
//

import SwiftUI

@main
struct TribunetourApp: App {
    @UIApplicationDelegateAdaptor(AppNotificationAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
