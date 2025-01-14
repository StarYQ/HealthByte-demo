import UIKit
import Supabase

class AuthViewController: UIViewController {
    
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
        emailTextField.placeholder = "Email"
        emailTextField.autocapitalizationType = .none
        emailTextField.borderStyle = .roundedRect
        
        passwordTextField.placeholder = "Password"
        passwordTextField.autocapitalizationType = .none
        passwordTextField.isSecureTextEntry = true
        passwordTextField.borderStyle = .roundedRect
    }
    
    private func setupButtons() {
        signUpButton.setTitle("Sign Up", for: .normal)
        signUpButton.addTarget(self, action: #selector(didTapSignUp), for: .touchUpInside)

        signInButton.setTitle("Sign In", for: .normal)
        signInButton.addTarget(self, action: #selector(didTapSignIn), for: .touchUpInside)
    }
    
    private func layoutViews() {
        // Simple vertical stack layout, adapt as needed
        let stack = UIStackView(arrangedSubviews: [emailTextField, passwordTextField, signUpButton, signInButton])
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
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        
        guard !email.isEmpty, !password.isEmpty else { return }

        do {
            // 1) Sign Up
            try await SupabaseManager.shared.client.auth.signUp(email: email, password: password)
            // 2) Then sign in (or prompt them to do so)
            try await SupabaseManager.shared.client.auth.signIn(email: email, password: password)
            
            dismissAuthFlow()
        } catch {
            print("Sign-up failed:", error.localizedDescription)
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
        // Replace root VC with MainTabViewController once authenticated
        DispatchQueue.main.async {
            if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                let mainTabVC = MainTabViewController()
                window.rootViewController = mainTabVC
                window.makeKeyAndVisible()
            }
        }
    }
}
