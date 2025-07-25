//
//  ContentView.swift
//  VocabCoach
//
//  Created by Aunik Paul on 7/11/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var userSession: UserSession
    var body: some View {
        VStack {
            PracticeView()
            Spacer()
            Button(action: {
                userSession.signOut()
            }) {
                Text("Log Out")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .padding(.bottom)
        }
    }
}

#Preview {
    ContentView()
}
