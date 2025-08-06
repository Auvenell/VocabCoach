//
//  VocabCoachApp.swift
//  VocabCoach
//
//  Created by Aunik Paul on 7/11/25.
//

import FirebaseCore
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication,
                     didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool
    {
        FirebaseApp.configure()
        return true
    }

    // Lock orientation to portrait only
    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
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
