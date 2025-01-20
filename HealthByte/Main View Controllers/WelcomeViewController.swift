import UIKit
import HealthKit

class WelcomeViewController: SplashScreenViewController, SplashScreenViewControllerDelegate {
    
    let healthStore = HealthData.healthStore
    
    /// The HealthKit data types we will request to read.
    let readTypes = Set(HealthData.readDataTypes)
    
    var hasRequestedHealthData: Bool = false
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = tabBarItem.title
        view.backgroundColor = .systemBackground
        splashScreenDelegate = self
        actionButton.setTitle("Authorize HealthKit Access", for: .normal)

        getHealthAuthorizationRequestStatus()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Add a Sign Out button to the right side
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Sign Out",
            style: .plain,
            target: self,
            action: #selector(didTapSignOut)
        )
    }
    
    // MARK: - HealthKit Authorization
    
    func getHealthAuthorizationRequestStatus() {
        print("Checking HealthKit authorization status...")
        
        if !HKHealthStore.isHealthDataAvailable() {
            presentHealthDataNotAvailableError()
            return
        }
        
        healthStore.getRequestStatusForAuthorization(toShare: [], read: readTypes) { (authorizationRequestStatus, error) in
            var status: String = ""
            if let error = error {
                status = "HealthKit Authorization Error: \(error.localizedDescription)"
            } else {
                switch authorizationRequestStatus {
                case .shouldRequest:
                    self.hasRequestedHealthData = false
                    status = "The application has not yet requested authorization for all of the specified data types."
                case .unknown:
                    status = "The authorization request status could not be determined because an error occurred."
                case .unnecessary:
                    self.hasRequestedHealthData = true
                    status = "The application has already requested authorization. "
                    status += self.createAuthorizationStatusDescription(for: self.readTypes)
                @unknown default:
                    break
                }
            }
            
            print(status)
            
            // Dispatch UI updates to the main thread.
            DispatchQueue.main.async {
                self.descriptionLabel.text = status
            }
        }
    }
    
    // MARK: - SplashScreenViewController Delegate
    
    func didSelectActionButton() {
        requestHealthAuthorization()
    }
    
    func requestHealthAuthorization() {
        print("Requesting HealthKit authorization...")
        
        if !HKHealthStore.isHealthDataAvailable() {
            presentHealthDataNotAvailableError()
            return
        }
        
        healthStore.requestAuthorization(toShare: [], read: readTypes) { (success, error) in
            var status: String = ""
            
            if let error = error {
                status = "HealthKit Authorization Error: \(error.localizedDescription)"
            } else {
                if success {
                    if self.hasRequestedHealthData {
                        status = "You've already requested access to health data. "
                    } else {
                        status = "HealthKit authorization request was successful! "
                    }
                    
                    status += self.createAuthorizationStatusDescription(for: self.readTypes)
                    
                    self.hasRequestedHealthData = true
                } else {
                    status = "HealthKit authorization did not complete successfully."
                }
            }
            
            print(status)
            
            DispatchQueue.main.async {
                self.descriptionLabel.text = status
            }
        }
    }
    
    // MARK: - Sign Out
    
    @objc private func didTapSignOut() {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
                // Show AuthViewController after sign-out
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
                   let window = sceneDelegate.window {
                    let authVC = AuthViewController()
                    window.rootViewController = authVC
                    window.makeKeyAndVisible()
                }
            } catch {
                print("Failed to sign out:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func createAuthorizationStatusDescription(for types: Set<HKObjectType>) -> String {
        var dictionary = [HKAuthorizationStatus: Int]()
        
        for type in types {
            let status = healthStore.authorizationStatus(for: type)
            
            if let existingValue = dictionary[status] {
                dictionary[status] = existingValue + 1
            } else {
                dictionary[status] = 1
            }
        }
        
        var descriptionArray: [String] = []
        
        if let numberOfAuthorizedTypes = dictionary[.sharingAuthorized] {
            let format = NSLocalizedString("AUTHORIZED_NUMBER_OF_TYPES", comment: "")
            let formattedString = String(format: format, locale: .current, arguments: [numberOfAuthorizedTypes])
            descriptionArray.append(formattedString)
        }
        if let numberOfDeniedTypes = dictionary[.sharingDenied] {
            let format = NSLocalizedString("DENIED_NUMBER_OF_TYPES", comment: "")
            let formattedString = String(format: format, locale: .current, arguments: [numberOfDeniedTypes])
            descriptionArray.append(formattedString)
        }
        if let numberOfUndeterminedTypes = dictionary[.notDetermined] {
            let format = NSLocalizedString("UNDETERMINED_NUMBER_OF_TYPES", comment: "")
            let formattedString = String(format: format, locale: .current, arguments: [numberOfUndeterminedTypes])
            descriptionArray.append(formattedString)
        }
        
        if let lastDescription = descriptionArray.last, descriptionArray.count > 1 {
            descriptionArray[descriptionArray.count - 1] = "and \(lastDescription)"
        }
        
        let description = "Sharing is " + descriptionArray.joined(separator: ", ") + "."
        return description
    }
    
    private func presentHealthDataNotAvailableError() {
        let title = "Health Data Unavailable"
        let message = "Aw, shucks! We are unable to access health data on this device. Make sure you're using a device with HealthKit capabilities."
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "Dismiss", style: .default)
        
        alertController.addAction(action)
        present(alertController, animated: true)
    }
}
