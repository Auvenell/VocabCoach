//
//  ContentView.swift
//  VocabCoach
//
//  Created by Aunik Paul on 7/11/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var isSidebarShowing = false
    
    var body: some View {
        ZStack {
            // Main content
            VStack {
                // Header with hamburger menu
                HStack {
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
                    
                    Spacer()
                    
                    Text("Vocab Coach")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Placeholder to balance the layout
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Main content area
                PracticeView()
                
                Spacer()
            }
            
            // Sidebar overlay
            SidebarView(isShowing: $isSidebarShowing)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(UserSession())
}
