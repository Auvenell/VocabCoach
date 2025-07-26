//
//  VocabCoachApp.swift
//  VocabCoach
//
//  Created by Aunik Paul on 7/11/25.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
    // Lock orientation to portrait only
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct VocabCoachApp: App {
    @StateObject private var userSession = UserSession()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            if userSession.user != nil {
                ContentView()
                    .environmentObject(userSession)
            } else {
                LoginView()
                    .environmentObject(userSession)
            }
        }
    }
}
