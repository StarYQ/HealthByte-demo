import UIKit
import Supabase

class AuthViewController: UIViewController {
    
    private let firstNameTextField = UITextField()
    private let lastNameTextField = UITextField()
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let signUpButton = UIButton(type: .system)
    private let signInButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Authentication"
        
        setupTextFields()
        setupButtons()
        layoutViews()
    }
    
    private func setupTextFields() {
        firstNameTextField.placeholder = "First Name"
        firstNameTextField.autocapitalizationType = .none
        firstNameTextField.borderStyle = .roundedRect
        
        lastNameTextField.placeholder = "Last Name"
        lastNameTextField.autocapitalizationType = .none
        lastNameTextField.borderStyle = .roundedRect
        
        emailTextField.placeholder = "Email"
        emailTextField.autocapitalizationType = .none
        emailTextField.borderStyle = .roundedRect
        if #available(iOS 10.0, *) {
            emailTextField.textContentType = .username
        }
        
        passwordTextField.placeholder = "Password"
        passwordTextField.autocapitalizationType = .none
        passwordTextField.isSecureTextEntry = true
        passwordTextField.borderStyle = .roundedRect
        passwordTextField.textContentType = .oneTimeCode
    }
    
    private func setupButtons() {
        signUpButton.setTitle("Sign Up", for: .normal)
        signUpButton.addTarget(self, action: #selector(didTapSignUp), for: .touchUpInside)

        signInButton.setTitle("Sign In", for: .normal)
        signInButton.addTarget(self, action: #selector(didTapSignIn), for: .touchUpInside)
    }
    
    private func layoutViews() {
        // Simple vertical stack layout
        let stack = UIStackView(arrangedSubviews: [firstNameTextField, lastNameTextField, emailTextField, passwordTextField, signUpButton, signInButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(equalToConstant: 250)
        ])
    }

    // MARK: - Button Handlers

    @objc private func didTapSignUp() {
        Task {
            await handleSignUp()
        }
    }

    @objc private func didTapSignIn() {
        Task {
            await handleSignIn()
        }
    }

    // MARK: - Auth Logic
    
    private func handleSignUp() async {
        let firstName = firstNameTextField.text ?? ""
        let lastName = lastNameTextField.text ?? ""
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        
        guard !firstName.isEmpty, !lastName.isEmpty, !email.isEmpty, !password.isEmpty else { return }

        do {
            // 1) Sign Up
            try await SupabaseManager.shared.client.auth.signUp(email: email, password: password)
            // 2) Then sign in
            try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
            debugCurrentSession()
            
            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                print("User creation failed - can not get user")
                return
            }
            // Build a struct matching columns in Patient table (clinician is not assigned immediately)
            struct PatientProfile: Codable {
                let name: String
                let authId: String
                let stepCount: Int
            }
            
            // For now, set a flag value, -1, to new accounts for which data has not yet been updated
            let profile = PatientProfile(name: firstName + " " + lastName, authId: user.id.uuidString.lowercased(), stepCount: -1)
            // 3) Then upsert new profile to Patient table
            try await SupabaseManager.shared.client
                .from("Patient")
                .insert(profile)
                .execute()
            
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Account created",
                    message: "Your account has been created!",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
            dismissAuthFlow()
        } catch {
            // Print general error
            print("Sign-up failed: \(error)")

            // Try to extract more details from the error
            let nsError = error as NSError
            print("Error domain: \(nsError.domain)")
            print("Error code: \(nsError.code)")
            print("Error description: \(nsError.localizedDescription)")

            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("Underlying error: \(underlyingError.localizedDescription)")
            }
        }
    }

    private func handleSignIn() async {
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""

        guard !email.isEmpty, !password.isEmpty else { return }

        do {
            try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
            dismissAuthFlow()
        } catch {
            print("Sign-in failed:", error.localizedDescription)
        }
    }

    private func dismissAuthFlow() {
        // Replaces root VC with MainTabViewController once authenticated
        DispatchQueue.main.async {
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                let mainTabVC = MainTabViewController()
                window.rootViewController = mainTabVC
                window.makeKeyAndVisible()
            }
        }
    }
    
    // MARK: - Debugging
    func debugCurrentSession() {
        if let session = SupabaseManager.shared.client.auth.currentSession {
            print("=== Current Session ===")
            print("Access Token: \(session.accessToken)")
            print("Refresh Token: \(session.refreshToken)")
            print("Expires At: \(session.expiresAt)")
            
            // Optionally, decode the JWT to log the uid (if your JWT includes it)
            if let jwtPayload = decode(jwt: session.accessToken) {
                print("Decoded JWT Payload: \(jwtPayload)")
            }
        } else {
            print("No current session available.")
        }
    }

    /// A simple JWT decoder that splits the token and decodes the payload (base64 encoded).
    /// Note: This is a simple decoder for debugging purposes only and does not validate the token.
    func decode(jwt token: String) -> [String: Any]? {
        let segments = token.components(separatedBy: ".")
        guard segments.count > 1 else { return nil }
        
        var base64String = segments[1]
        
        // Fix base64 padding if necessary
        let requiredLength = 4 * ((base64String.count + 3) / 4)
        let paddingLength = requiredLength - base64String.count
        if paddingLength > 0 {
            base64String += String(repeating: "=", count: paddingLength)
        }
        
        guard let data = Data(base64Encoded: base64String, options: []),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let payload = json as? [String: Any] else {
            return nil
        }
        
        return payload
    }
}
