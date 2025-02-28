import UIKit
import HealthKit

class WeeklyQuantitySampleTableViewController: HealthDataTableViewController, HealthQueryDataSource {
    
    let calendar: Calendar = .current
    let healthStore = HealthData.healthStore
    
    var quantityTypeIdentifier: HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier(rawValue: dataTypeIdentifier)
    }
    
    var quantityType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: quantityTypeIdentifier)!
    }
    
    var query: HKStatisticsCollectionQuery?
    
    // MARK: - View Life Cycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // If we already have a query, skip
        if query != nil { return }
        
        // Request HealthKit authorization for reading/writing steps
        let dataTypeValues = Set([quantityType])
        
        print("Requesting HealthKit authorization...")
        
        self.healthStore.requestAuthorization(toShare: [], read: dataTypeValues) { (success, error) in
            if success {
                self.calculateDailyQuantitySamplesForPastWeek()
            }
        }
    }
    
    /// We use the “Refresh” button inherited from the parent class.

    override func setUpNavigationController() {
        // Call super so the parent sets up its refresh button
        super.setUpNavigationController()
        
        // Create only our "Update Steps" on the right
        let updateStepsButton = UIBarButtonItem(
            title: "Update Steps",
            style: .plain,
            target: self,
            action: #selector(didTapUpdateSteps)
        )

        navigationItem.rightBarButtonItem = updateStepsButton
    }
    
    // MARK: - Overriding refreshData
    
    /// Called when the inherited "Refresh" button is tapped.
    /// Re-requests HealthKit authorization, then re-queries for data.
    override func refreshData() {
        HealthData.requestHealthDataAccessIfNeeded(dataTypes: [dataTypeIdentifier]) { [weak self] success in
            guard let self = self else { return }
            if success {
                // If re-authorized, re-run the query for the last week’s data
                DispatchQueue.main.async {
                    self.updateNavigationItem()
                }
                self.calculateDailyQuantitySamplesForPastWeek()
            }
        }
    }

    // MARK: - HealthKit Data
    
    func calculateDailyQuantitySamplesForPastWeek() {
        performQuery {
            DispatchQueue.main.async { [weak self] in
                self?.reloadData()
            }
        }
    }

    func performQuery(completion: @escaping () -> Void) {
        let predicate = createLastWeekPredicate()
        let anchorDate = createAnchorDate()
        let dailyInterval = DateComponents(day: 1)
        let statisticsOptions = getStatisticsOptions(for: dataTypeIdentifier)

        let query = HKStatisticsCollectionQuery(
            quantityType: quantityType,
            quantitySamplePredicate: predicate,
            options: statisticsOptions,
            anchorDate: anchorDate,
            intervalComponents: dailyInterval
        )
        
        let updateInterfaceWithStatistics: (HKStatisticsCollection) -> Void = { statisticsCollection in
            self.dataValues = []
            
            let now = Date()
            let startDate = getLastWeekStartDate()
            let endDate = now
            
            statisticsCollection.enumerateStatistics(from: startDate, to: endDate) { [weak self] (statistics, _) in
                var dataValue = HealthDataTypeValue(
                    startDate: statistics.startDate,
                    endDate: statistics.endDate,
                    value: 0
                )
                
                if let quantity = getStatisticsQuantity(for: statistics, with: statisticsOptions),
                   let identifier = self?.dataTypeIdentifier,
                   let unit = preferredUnit(for: identifier) {
                    dataValue.value = quantity.doubleValue(for: unit)
                }
                
                self?.dataValues.append(dataValue)
            }
            
            completion()
        }
        
        query.initialResultsHandler = { _, statisticsCollection, _ in
            if let statisticsCollection = statisticsCollection {
                updateInterfaceWithStatistics(statisticsCollection)
            }
        }
        
        query.statisticsUpdateHandler = { [weak self] query, _, statisticsCollection, _ in
            if let statisticsCollection = statisticsCollection,
               query.objectType?.identifier == self?.dataTypeIdentifier {
                updateInterfaceWithStatistics(statisticsCollection)
            }
        }
        
        self.healthStore.execute(query)
        self.query = query
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let query = query {
            self.healthStore.stop(query)
        }
    }
    
    // MARK: - Upsert Weekly Steps in Supabase
    
    @objc private func didTapUpdateSteps() {
        Task {
            await updateWeeklyStepCountInSupabase()
        }
    }

    private func updateWeeklyStepCountInSupabase() async {
        guard let user = SupabaseManager.shared.client.auth.currentUser else {
            print("No authenticated user – cannot update steps.")
            return
        }

        // Sum the step data for the past week
        let totalSteps = Int(dataValues.reduce(0, { $0 + $1.value }))

        // Build a struct matching columns in user_profiles
        struct UserProfile: Codable {
            let user_id: UUID
            let total_weekly_steps: Int
        }
        do {
            // Update profile in user_profiles
            try await SupabaseManager.shared.client
                .from("user_profiles")
                .update(["total_weekly_steps": totalSteps])
                .eq("user_id", value: user.id)
                .execute()
            
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Steps Updated",
                    message: "Your weekly step count has been upserted to Supabase!",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        } catch {
            print("Failed to update user_profiles:", error.localizedDescription)
        }
    }
}
