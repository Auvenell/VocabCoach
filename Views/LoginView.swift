import SwiftUI

struct LoginView: View {
    @EnvironmentObject var userSession: UserSession
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isRegistering: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Text(isRegistering ? "Register" : "Sign In")
                .font(.largeTitle)
                .bold()
            TextField("Email", text: $email)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            SecureField("Password", text: $password)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            if let error = userSession.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
            if userSession.isLoading {
                ProgressView()
            }
            Button(action: {
                if isRegistering {
                    userSession.register(email: email, password: password)
                } else {
                    userSession.signIn(email: email, password: password)
                }
            }) {
                Text(isRegistering ? "Register" : "Sign In")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            Button(action: {
                isRegistering.toggle()
            }) {
                Text(isRegistering ? "Already have an account? Sign In" : "Don't have an account? Register")
                    .font(.footnote)
            }
        }
        .padding()
    }
}
