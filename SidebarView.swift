//
//  SidebarView.swift
//  VocabCoach
//
//  Created by Aunik Paul on 7/11/25.
//

import SwiftUI

struct SidebarView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var userSession: UserSession
    var onSelectText: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Background overlay
            if isShowing {
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }
            }
            
            // Sidebar content
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userSession.user?.email ?? "User")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Vocab Coach")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        Divider()
                            .padding(.horizontal, 20)
                    }
                    
                    // Menu Items
                    VStack(spacing: 0) {
                        SidebarMenuItem(
                            icon: "book.fill",
                            title: "Practice",
                            isActive: true
                        ) {
                            // Navigate to practice
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }
                        
                        SidebarMenuItem(
                            icon: "doc.text",
                            title: "Select Text",
                            isActive: false
                        ) {
                            onSelectText?()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }
                        
                        SidebarMenuItem(
                            icon: "chart.bar.fill",
                            title: "Progress",
                            isActive: false
                        ) {
                            // Navigate to progress
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }
                        
                        SidebarMenuItem(
                            icon: "gear",
                            title: "Settings",
                            isActive: false
                        ) {
                            // Navigate to settings
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }
                        
                        SidebarMenuItem(
                            icon: "questionmark.circle",
                            title: "Help",
                            isActive: false
                        ) {
                            // Navigate to help
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Logout button
                    VStack(spacing: 0) {
                        Divider()
                            .padding(.horizontal, 20)
                        
                        SidebarMenuItem(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "Log Out",
                            isActive: false,
                            isDestructive: true
                        ) {
                            userSession.signOut()
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowing = false
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .frame(width: 280)
                .background(Color(.systemBackground))
                .offset(x: isShowing ? 0 : -280)
                
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
}

struct SidebarMenuItem: View {
    let icon: String
    let title: String
    let isActive: Bool
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDestructive ? .red : (isActive ? .blue : .primary))
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.blue.opacity(0.1) : Color.clear)
                    .padding(.horizontal, 20)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SidebarView(isShowing: .constant(true)) {
        // Select text action
    }
    .environmentObject(UserSession())
} 