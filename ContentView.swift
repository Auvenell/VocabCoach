//
//  ContentView.swift
//  VocabCoach
//
//  Created by Aunik Paul on 7/11/25.
//

import SwiftUI

class HeaderState: ObservableObject {
    @Published var showBackButton = false
    @Published var backButtonAction: (() -> Void)?
    @Published var title = ""
    @Published var titleIcon = ""
    @Published var titleColor: Color = .primary
}

struct ContentView: View {
    @EnvironmentObject var userSession: UserSession
    @StateObject private var headerState = HeaderState()
    @State private var isSidebarShowing = false
    @State private var showingParagraphSelector = false

    var body: some View {
        ZStack {
            // Main content
            VStack {
                // Header with back button, title, and hamburger menu
                HStack {
                    // Back button
                    if headerState.showBackButton {
                        Button(action: {
                            headerState.backButtonAction?()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.blue)
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    // Title with icon
                    if !headerState.title.isEmpty {
                        HStack {
                            if !headerState.titleIcon.isEmpty {
                                Image(systemName: headerState.titleIcon)
                                    .foregroundColor(headerState.titleColor)
                            }
                            Text(headerState.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        .transition(.opacity.combined(with: .scale))
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarShowing.toggle()
                        }
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: headerState.showBackButton)
                .animation(.easeInOut(duration: 0.3), value: headerState.title)
                .padding(.horizontal)
                .padding(.top, 8)

                // Main content area
                PracticeView(showingParagraphSelector: $showingParagraphSelector)
                    .environmentObject(headerState)

                Spacer()
            }

            // Sidebar overlay
            SidebarView(isShowing: $isSidebarShowing) {
                showingParagraphSelector = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(UserSession())
}
