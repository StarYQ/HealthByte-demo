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
        // Left‑side “Refresh” button.
        let refreshItem = UIBarButtonItem(title: "Refresh",
                                          style: .plain,
                                          target: self,
                                          action: #selector(didTapRefreshButton))

        navigationItem.leftBarButtonItem = refreshItem
        // Right‑side “More” button (choose another Health‑data type).
        let moreItem = UIBarButtonItem(title: "More",
                                       style: .plain,
                                       target: self,
                                       action: #selector(didTapMoreButton))
        navigationItem.rightBarButtonItem = moreItem
    }

    func updateNavigationItem() {
        navigationItem.title = getDataTypeName(for: dataTypeIdentifier)
    }
    
    // MARK: - Button actions

    @objc
    private func didTapRefreshButton() {
        refreshData()
    }
    @objc
    private func didTapMoreButton() {
        presentDataTypeSelectionView()
    }
    

    // MARK: - Refresh
    private func refreshData() {
        HealthData.requestHealthDataAccessIfNeeded(dataTypes: [dataTypeIdentifier]) { [weak self] success in
            guard let self = self, success else { return }
            DispatchQueue.main.async { self.updateNavigationItem() }
            // If this controller performs a HealthKit query, re‑run it;
            // otherwise simply reload the existing table data.
            if let queryProvider = self as? HealthQueryDataSource {
                queryProvider.performQuery { [weak self] in
                    DispatchQueue.main.async { self?.reloadData() }
                }
            } else {
                DispatchQueue.main.async { self.reloadData() }
            }
        }
    }
    
    
    // MARK: - Data‑type switching
    
    private func presentDataTypeSelectionView() {
        let alertController = UIAlertController(title: "Select Health Data Type", message: nil, preferredStyle: .actionSheet)
        for sampleType in HealthData.readDataTypes {
            let readableName = getDataTypeName(for: sampleType.identifier) ?? sampleType.identifier
            let action = UIAlertAction(title: readableName, style: .default) { [weak self] _ in
                self?.didSelectDataTypeIdentifier(sampleType.identifier)

            }
            alertController.addAction(action)

        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alertController, animated: true)
    }

    private func didSelectDataTypeIdentifier(_ identifier: String) {
        // Ignore no‑op selections.
        guard identifier != dataTypeIdentifier else { return }
        dataTypeIdentifier = identifier
        HealthData.requestHealthDataAccessIfNeeded(dataTypes: [identifier]) { [weak self] success in
            guard let self = self, success else { return }
            DispatchQueue.main.async { self.updateNavigationItem() }
            if let queryProvider = self as? HealthQueryDataSource {
                queryProvider.performQuery { [weak self] in
                    DispatchQueue.main.async { self?.reloadData() }
                }
            } else {
                DispatchQueue.main.async { self.reloadData() }
            }
        }
    }
}
