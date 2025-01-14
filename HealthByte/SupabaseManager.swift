import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client = SupabaseClient(
        supabaseURL: URL(string: "https://YOUR-PROJECT-REF.supabase.co")!,
        supabaseKey: "YOUR-PUBLIC-ANON-KEY"
    )

    private init() {}
}
