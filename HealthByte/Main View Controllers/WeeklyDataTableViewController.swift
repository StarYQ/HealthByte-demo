import UIKit
import HealthKit

class WeeklyQuantitySampleTableViewController: HealthDataTableViewController, HealthQueryDataSource {
    
    // MARK: ‑ Health‑Kit helpers
    private let calendar: Calendar = .current
    private let healthStore = HealthData.healthStore
    
    private var quantityTypeIdentifier: HKQuantityTypeIdentifier {
        HKQuantityTypeIdentifier(rawValue: dataTypeIdentifier)

    }
    
    private var quantityType: HKQuantityType {

        HKQuantityType.quantityType(forIdentifier: quantityTypeIdentifier)!

    }

    private var query: HKStatisticsCollectionQuery?
    
    // MARK: ‑ View‑life‑cycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Only set up once per appearance cycle.
        guard query == nil else { return }
        let readTypes = Set([quantityType])
        print("Requesting HealthKit authorization…")
        healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, _ in
            guard success else { return }
            self?.calculateDailyQuantitySamplesForPastWeek()
        }
    }
    
    /// We use the “Refresh” button inherited from the parent class.
    // MARK: Navigation‑bar configuration
    override func setUpNavigationController() {
        // Call super so the parent sets up its refresh button
        super.setUpNavigationController()
        // Right‑side button for uploading the aggregate value.
        let uploadItem = UIBarButtonItem(title: uploadButtonTitle(),
                                         style: .plain,
                                         target: self,
                                         action: #selector(didTapUploadButton))
        navigationItem.rightBarButtonItem = uploadItem
    }

    /// Refresh the title of the right‑bar button whenever the data type changes.
    override func updateNavigationItem() {
        super.updateNavigationItem()
        navigationItem.rightBarButtonItem?.title = uploadButtonTitle()
    }
    

    private func uploadButtonTitle() -> String {
        let typeName = getDataTypeName(for: dataTypeIdentifier) ?? "Data"
        return "Update \(typeName)"
    }
    
    // MARK: ‑ Health‑Kit querying
    private func calculateDailyQuantitySamplesForPastWeek() {
        performQuery { [weak self] in
            DispatchQueue.main.async { self?.reloadData() }
        }
    }
    
    func performQuery(completion: @escaping () -> Void) {
        let predicate        = createLastWeekPredicate()
        let anchorDate       = createAnchorDate()
        let dailyInterval    = DateComponents(day: 1)
        let statsOptions     = getStatisticsOptions(for: dataTypeIdentifier)
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: predicate,
                                                options: statsOptions,
                                                anchorDate: anchorDate,
                                                intervalComponents: dailyInterval)
        let handleStats: (HKStatisticsCollection) -> Void = { [weak self] collection in
            guard let self = self else { return }
            self.dataValues.removeAll()
            let now       = Date()
            let startDate = getLastWeekStartDate()
            collection.enumerateStatistics(from: startDate, to: now) { stats, _ in
                var value = 0.0
                if let quantity = getStatisticsQuantity(for: stats, with: statsOptions),
                   let unit = preferredUnit(for: self.dataTypeIdentifier) {
                    value = quantity.doubleValue(for: unit)
                }
                let entry = HealthDataTypeValue(startDate: stats.startDate,
                                                endDate:   stats.endDate,
                                                value:     value)
                self.dataValues.append(entry)
            }
            completion()
        }
        query.initialResultsHandler = { _, collection, _ in
            if let collection = collection { handleStats(collection) }
        }

        query.statisticsUpdateHandler = { [weak self] q, _, collection, _ in
            guard let self = self,
                  q.objectType?.identifier == self.dataTypeIdentifier,
                  let collection = collection else { return }
            handleStats(collection)
        }
        healthStore.execute(query)
        self.query = query
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let q = query { healthStore.stop(q) }
    }
    

    // MARK: ‑ Upload aggregate value to Supabase
    @objc private func didTapUploadButton() {
        Task { await uploadAggregateValueToSupabase() }
    }
    
    /// Maps Health‑Kit identifiers to column names in the Patient table.
    private static let columnMap: [String: String] = [
        HKQuantityTypeIdentifier.stepCount.rawValue:              "stepCount",
        HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue: "walkingDistanceMeters",
        HKQuantityTypeIdentifier.sixMinuteWalkTestDistance.rawValue: "sixMinuteWalkMeters"
    ]

    private func uploadAggregateValueToSupabase() async {
        guard let user = SupabaseManager.shared.client.auth.currentUser else {
            print("No authenticated user – cannot update data.")
            return
        }
        guard let column = Self.columnMap[dataTypeIdentifier] else {
            print("No Patient‑table column mapped for \(dataTypeIdentifier).")
            return
        }
        let total = dataValues.reduce(0) { $0 + $1.value }
        
        do {
            if column == "stepCount" {
                let payload = [column: Int(total.rounded())]            // [String : Int]
                _ = try await SupabaseManager.shared.client
                    .from("Patient")
                    .update(payload)
                    .eq("authId", value: user.id.uuidString.lowercased())
                    .execute()
            } else {
                let payload = [column: total] as [String : Double]      // [String : Double]
                _ = try await SupabaseManager.shared.client
                    .from("Patient")
                    .update(payload)
                    .eq("authId", value: user.id.uuidString.lowercased())
                    .execute()
            }
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Data Updated",
                                              message: "Your weekly \(column) has been uploaded!",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        } catch {
            print("Supabase update failed for \(column):", error.localizedDescription)
        }
    }
}
