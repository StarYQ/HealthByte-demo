import UIKit
import Supabase

final class AuthViewController: UIViewController {

    // MARK: ‑ UI
    private let firstNameTextField = UITextField()
    private let lastNameTextField  = UITextField()
    private let emailTextField     = UITextField()
    private let passwordTextField  = UITextField()
    private let signUpButton       = UIButton(type: .system)
    private let signInButton       = UIButton(type: .system)

    // MARK: ‑ Life‑cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Authentication"

        setupTextFields()
        setupButtons()
        layoutViews()
    }

    // MARK: ‑ Setup helpers
    private func setupTextFields() {
        [firstNameTextField, lastNameTextField, emailTextField, passwordTextField].forEach {
            $0.borderStyle = .roundedRect
            $0.autocapitalizationType = .none
            $0.delegate = self
        }

        firstNameTextField.placeholder = "First Name"
        lastNameTextField.placeholder  = "Last Name"

        emailTextField.placeholder     = "Email"
        if #available(iOS 10.0, *) { emailTextField.textContentType = .username }

        passwordTextField.placeholder  = "Password"
        passwordTextField.isSecureTextEntry = true
        passwordTextField.textContentType   = .oneTimeCode
    }

    private func setupButtons() {
        signUpButton.setTitle("Sign Up", for: .normal)
        signUpButton.addTarget(self, action: #selector(didTapSignUp), for: .touchUpInside)

        signInButton.setTitle("Sign In", for: .normal)
        signInButton.addTarget(self, action: #selector(didTapSignIn), for: .touchUpInside)
    }

    private func layoutViews() {
        let stack = UIStackView(arrangedSubviews: [
            firstNameTextField,
            lastNameTextField,
            emailTextField,
            passwordTextField,
            signUpButton,
            signInButton
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(equalToConstant: 260)
        ])
    }

    // MARK: ‑ Button actions
    @objc private func didTapSignUp() { Task { await handleSignUp() } }
    @objc private func didTapSignIn() { Task { await handleSignIn() } }

    // MARK: ‑ Auth logic
    private func handleSignUp() async {
        let first = firstNameTextField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let last  = lastNameTextField.text?.trimmingCharacters(in: .whitespaces)  ?? ""
        let email = emailTextField.text?.lowercased() ?? ""
        let password   = passwordTextField.text ?? ""

        guard !first.isEmpty, !last.isEmpty, !email.isEmpty, !password.isEmpty else {
            presentAlert(title: "Missing Fields", message: "Please fill in all fields.")
            return
        }

        do {
            // Create the Supabase user account
            _ = try await SupabaseManager.shared.client.auth.signUp(
                email: email,
                password: password
            )

            // Sign in right away (returns session + user)
            _ = try await SupabaseManager.shared.client.auth.signIn(
                email: email,
                password: password
            )

            guard let user = SupabaseManager.shared.client.auth.currentUser else {
                throw AuthError.couldNotRetrieveUser
            }

            // Insert initial Patient profile
            struct PatientProfile: Codable {
                let authId: String
                let name: String
                let stepCount: Int64               // BigInt in DB
                let walkingDistanceMeters: Double? // nil until first sync
                let sixMinuteWalkMeters: Double?   // nil until first sync
            }

            let profile = PatientProfile(
                authId: user.id.uuidString.lowercased(),
                name: "\(first) \(last)",
                stepCount: -1,
                walkingDistanceMeters: nil,
                sixMinuteWalkMeters: nil
            )

            try await SupabaseManager.shared.client
                .from("Patient")
                .insert(profile)
                .execute()

            presentAlert(title: "Account Created",
                         message: "Welcome, \(first)!")
            dismissAuthFlow()

        } catch {
            presentAlert(title: "Sign‑up Failed", message: error.localizedDescription)
            print("Sign‑up error:", error)
        }
    }

    private func handleSignIn() async {
        let email = emailTextField.text?.lowercased() ?? ""
        let password   = passwordTextField.text ?? ""

        guard !email.isEmpty, !password.isEmpty else {
            presentAlert(title: "Missing Fields", message: "Email and password required.")
            return
        }

        do {
            _ = try await SupabaseManager.shared.client.auth.signIn(
                email: email,
                password: password
            )
            dismissAuthFlow()
        } catch {
            presentAlert(title: "Sign‑in Failed", message: error.localizedDescription)
            print("Sign‑in error:", error)
        }
    }

    // MARK: ‑ Helpers
    private func dismissAuthFlow() {
        DispatchQueue.main.async {
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                window.rootViewController = MainTabViewController()
                window.makeKeyAndVisible()
            }
        }
    }

    private func presentAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title,
                                          message: message,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    private enum AuthError: Error { case couldNotRetrieveUser }
}

// MARK: ‑ Return‑key navigation
extension AuthViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case firstNameTextField: lastNameTextField.becomeFirstResponder()
        case lastNameTextField:  emailTextField.becomeFirstResponder()
        case emailTextField:     passwordTextField.becomeFirstResponder()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}
