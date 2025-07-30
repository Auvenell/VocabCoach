//
//  SidebarFeatures.swift
//  VocabCoach
//
//  Created by Aunik Paul on 7/11/25.
//

import SwiftUI

// MARK: - Advanced Sidebar Features

// 1. Sidebar with User Profile Section
struct UserProfileSection: View {
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                // User Avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 60, height: 60)

                    Text(String(userSession.user?.email?.prefix(1) ?? "U").uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(userSession.user?.email ?? "User")
                        .font(.headline)
                        .lineLimit(1)

                    Text("Premium Member")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            // Quick Stats
            HStack(spacing: 20) {
                VStack {
                    Text("127")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("89%")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("14")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// 2. Sidebar with Search
struct SidebarSearchBar: View {
    @State private var searchText = ""

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

// 3. Sidebar with Categories
struct SidebarCategory: View {
    let title: String
    let items: [SidebarMenuItemData]
    @Binding var isShowing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ForEach(items) { item in
                SidebarMenuItem(
                    icon: item.icon,
                    title: item.title,
                    isActive: item.isActive,
                    isDestructive: item.isDestructive
                ) {
                    item.action()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            }
        }
    }
}

// 4. Sidebar with Badge Notifications
struct SidebarMenuItemWithBadge: View {
    let icon: String
    let title: String
    let badge: String?
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

                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
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

// 5. Data Model for Menu Items
struct SidebarMenuItemData: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let isActive: Bool
    let isDestructive: Bool
    let badge: String?
    let action: () -> Void

    init(icon: String, title: String, isActive: Bool = false, isDestructive: Bool = false, badge: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isActive = isActive
        self.isDestructive = isDestructive
        self.badge = badge
        self.action = action
    }
}

// 6. Enhanced Sidebar with All Features
struct EnhancedSidebarView: View {
    @Binding var isShowing: Bool
    @EnvironmentObject var userSession: UserSession
    @State private var searchText = ""

    private let mainMenuItems = [
        SidebarMenuItemData(icon: "book.fill", title: "Practice", isActive: true) {},
        SidebarMenuItemData(icon: "chart.bar.fill", title: "Progress") {},
        SidebarMenuItemData(icon: "trophy.fill", title: "Achievements", badge: "3") {},
        SidebarMenuItemData(icon: "star.fill", title: "Favorites") {},
    ]

    private let settingsItems = [
        SidebarMenuItemData(icon: "gear", title: "Settings") {},
        SidebarMenuItemData(icon: "bell", title: "Notifications", badge: "2") {},
        SidebarMenuItemData(icon: "questionmark.circle", title: "Help") {},
        SidebarMenuItemData(icon: "envelope", title: "Feedback") {},
    ]

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
                    // User Profile Section
                    UserProfileSection()
                        .padding(.top, 20)

                    // Search Bar
                    SidebarSearchBar()
                        .padding(.top, 16)

                    // Main Menu
                    SidebarCategory(
                        title: "MAIN",
                        items: mainMenuItems,
                        isShowing: $isShowing
                    )

                    // Settings Menu
                    SidebarCategory(
                        title: "SETTINGS",
                        items: settingsItems,
                        isShowing: $isShowing
                    )

                    Spacer()

                    // Logout
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
                .frame(width: 300)
                .background(Color(.systemBackground))
                .offset(x: isShowing ? 0 : -300)

                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
}

#Preview {
    EnhancedSidebarView(isShowing: .constant(true))
        .environmentObject(UserSession())
}

#Preview {
    SidebarView(isShowing: .constant(true)) {
        // Select text action
    }
    .environmentObject(UserSession())
}
