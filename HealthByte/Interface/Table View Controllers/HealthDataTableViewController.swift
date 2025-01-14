/*Abstract:
A table view controller with a refresh button to re-fetch the step count data.
*/

import UIKit
import HealthKit

/// A view controller that allows switching between health data types as a data source and manually adding new quantity or category samples.
class HealthDataTableViewController: DataTableViewController {
    
    // MARK: - View Life Cycle Overrides
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateNavigationItem()
    }
    
    override func setUpNavigationController() {
        super.setUpNavigationController()
        // The refresh button item.
        let leftBarButtonItem = UIBarButtonItem(title: "Refresh", style: .plain, target: self,
                                                action: #selector(didTapLeftBarButtonItem))
        navigationItem.leftBarButtonItem = leftBarButtonItem
    }
    
    func updateNavigationItem() {
        navigationItem.title = getDataTypeName(for: dataTypeIdentifier)
    }
    
    // MARK: - Button Selectors

    @objc
    private func didTapLeftBarButtonItem() {
        refreshData()
    }
    
    // MARK:  - Refresh
    private func refreshData() {
        HealthData.requestHealthDataAccessIfNeeded(dataTypes: [self.dataTypeIdentifier]) { [weak self] (success) in
            guard let self = self else { return }
            if success {
                DispatchQueue.main.async {
                    self.updateNavigationItem()
                }
                // Otherwise, just reload the data
                DispatchQueue.main.async { [weak self] in
                    self?.reloadData()
                }
            }
        }
    }
}
