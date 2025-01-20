/*Abstract:
The Supabase client.
*/
import Foundation
import Supabase

class SupabaseManager {
    static let shared: SupabaseManager = {
        guard
            let urlString = ProcessInfo.processInfo.environment["SUPABASE_URL"],
            let anonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"],
            let url = URL(string: urlString)
        else {
            fatalError("Supabase environment variables are missing or invalid.")
        }
        return SupabaseManager(url: url, key: anonKey)
    }()
    let client: SupabaseClient

    private init(url: URL, key: String) {
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}
