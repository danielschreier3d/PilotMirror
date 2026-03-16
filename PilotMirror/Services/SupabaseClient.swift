import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Configuration  ← fill in your credentials here
// ─────────────────────────────────────────────────────────────────────────────
enum SupabaseConfig {
    /// https://app.supabase.com → Project Settings → API → Project URL
    static let projectURL = "https://outsherttkwwuvihpkzn.supabase.co"
    /// https://app.supabase.com → Project Settings → API → anon / public key
    static let anonKey    = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im91dHNoZXJ0dGt3d3V2aWhwa3puIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyODE4NzgsImV4cCI6MjA4ODg1Nzg3OH0.KRFm5YghZPysybdTKtQRUX2Mr6pOKgyWgJ1gOnc-9as"
    /// Supabase Edge Function URL for AI analysis (Groq key stored server-side)
    static let analyzeFunctionURL = "\(projectURL)/functions/v1/analyze"
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Auth response DTOs
// ─────────────────────────────────────────────────────────────────────────────
struct SBAuthResponse: Decodable {
    let accessToken:  String?   // SBDecoder convertFromSnakeCase: "access_token" → "accessToken"
    let refreshToken: String?   // "refresh_token" → "refreshToken"
    let user:         SBUser?
}

struct SBUser: Decodable {
    let id:    String
    let email: String?
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Error
// ─────────────────────────────────────────────────────────────────────────────
enum SupabaseError: LocalizedError {
    case unauthenticated
    case http(Int, String)
    case noData

    var errorDescription: String? {
        switch self {
        case .unauthenticated:     return "Not authenticated"
        case .http(let c, let m): return "HTTP \(c): \(m)"
        case .noData:             return "No data returned"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Client
// ─────────────────────────────────────────────────────────────────────────────
@MainActor
final class SupabaseClient: ObservableObject {
    static let shared = SupabaseClient()

    private(set) var accessToken:  String?
    private(set) var refreshToken: String?
    private(set) var userId:       String?

    var isAuthenticated: Bool { accessToken != nil && userId != nil }

    private let base = SupabaseConfig.projectURL
    private let anon = SupabaseConfig.anonKey

    private init() {
        accessToken  = UserDefaults.standard.string(forKey: "sb_at")
        refreshToken = UserDefaults.standard.string(forKey: "sb_rt")
        userId       = UserDefaults.standard.string(forKey: "sb_uid")
    }

    // MARK: – Auth

    /// Called after email confirmation deep link — stores tokens without a server round-trip.
    func applyAuthTokens(access: String, refresh: String) async throws {
        // Fetch user info with the new access token
        var req = URLRequest(url: URL(string: "\(base)/auth/v1/user")!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let user = try SBDecoder.decode(SBUser.self, from: data)
        accessToken  = access
        refreshToken = refresh
        userId       = user.id
        UserDefaults.standard.set(access,   forKey: "sb_at")
        UserDefaults.standard.set(refresh,  forKey: "sb_rt")
        UserDefaults.standard.set(user.id,  forKey: "sb_uid")
    }

    func signUpEmail(email: String, password: String) async throws -> SBAuthResponse {
        let r: SBAuthResponse = try await authPost(
            "/auth/v1/signup", body: ["email": email, "password": password])
        if r.accessToken != nil { persistSession(r) }
        return r
    }

    func signInEmail(email: String, password: String) async throws -> SBAuthResponse {
        let r: SBAuthResponse = try await authPost(
            "/auth/v1/token?grant_type=password", body: ["email": email, "password": password])
        guard r.accessToken != nil else {
            throw SupabaseError.http(0, "Login fehlgeschlagen.")
        }
        persistSession(r); return r
    }

    func signInApple(idToken: String) async throws -> SBAuthResponse {
        let r: SBAuthResponse = try await authPost(
            "/auth/v1/token?grant_type=id_token", body: ["provider": "apple", "id_token": idToken])
        guard r.accessToken != nil else {
            throw SupabaseError.http(0, "Apple Sign-In fehlgeschlagen.")
        }
        persistSession(r); return r
    }

    func signOut() {
        accessToken = nil; refreshToken = nil; userId = nil
        ["sb_at", "sb_rt", "sb_uid"].forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }

    // MARK: – REST: SELECT

    func select<T: Decodable>(
        from table: String,
        filters: [String: String] = [:],
        anonOnly: Bool = false
    ) async throws -> [T] {
        var comps = URLComponents(string: "\(base)/rest/v1/\(table)")!
        comps.queryItems = filters.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = makeRequest(url: comps.url!, method: "GET", anonOnly: anonOnly)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, res) = try await URLSession.shared.data(for: req)
        try validate(res, data)
        return try SBDecoder.decode([T].self, from: data)
    }

    func selectFirst<T: Decodable>(
        from table: String,
        filters: [String: String],
        anonOnly: Bool = false
    ) async throws -> T? {
        let r: [T] = try await select(from: table, filters: filters, anonOnly: anonOnly)
        return r.first
    }

    // MARK: – REST: INSERT

    func insert<T: Encodable>(
        into table: String,
        value: T,
        anonOnly: Bool = false
    ) async throws {
        var req = makeRequest(
            url: URL(string: "\(base)/rest/v1/\(table)")!, method: "POST", anonOnly: anonOnly)
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try SBEncoder.encode(value)
        let (data, res) = try await URLSession.shared.data(for: req)
        try validate(res, data)
    }

    // MARK: – REST: UPSERT

    func upsert<T: Encodable>(
        into table: String,
        value: T,
        onConflict: String = "id"
    ) async throws {
        var comps = URLComponents(string: "\(base)/rest/v1/\(table)")!
        comps.queryItems = [URLQueryItem(name: "on_conflict", value: onConflict)]
        var req = makeRequest(url: comps.url!, method: "POST")
        req.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try SBEncoder.encode(value)
        let (data, res) = try await URLSession.shared.data(for: req)
        try validate(res, data)
    }

    // MARK: – REST: PATCH

    func update(
        table: String,
        filters: [String: String],
        body: [String: Any]
    ) async throws {
        var comps = URLComponents(string: "\(base)/rest/v1/\(table)")!
        comps.queryItems = filters.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = makeRequest(url: comps.url!, method: "PATCH")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await URLSession.shared.data(for: req)
        try validate(res, data)
    }

    // MARK: – REST: DELETE

    func delete(from table: String, filters: [String: String]) async throws {
        var comps = URLComponents(string: "\(base)/rest/v1/\(table)")!
        comps.queryItems = filters.map { URLQueryItem(name: $0.key, value: $0.value) }
        let req = makeRequest(url: comps.url!, method: "DELETE")
        let (data, res) = try await URLSession.shared.data(for: req)
        try validate(res, data)
    }

    // MARK: – Auth: Update password

    func sendPasswordReset(email: String) async throws {
        var req = URLRequest(url: URL(string: "\(base)/auth/v1/recover")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email": email])
        let (data, res) = try await URLSession.shared.data(for: req)
        try validate(res, data)
    }

    func updatePassword(_ newPassword: String) async throws {
        guard let token = accessToken else { throw SupabaseError.unauthenticated }
        var req = URLRequest(url: URL(string: "\(base)/auth/v1/user")!)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["password": newPassword])
        let (data, res) = try await URLSession.shared.data(for: req)
        try validate(res, data)
    }

    // MARK: – RPC (returns value)

    func rpc<R: Decodable>(
        function: String,
        params: [String: Any],
        anonOnly: Bool = false
    ) async throws -> R {
        var req = makeRequest(
            url: URL(string: "\(base)/rest/v1/rpc/\(function)")!, method: "POST", anonOnly: anonOnly)
        req.httpBody = try JSONSerialization.data(withJSONObject: params)
        let (data, res) = try await URLSession.shared.data(for: req)
        try validate(res, data)
        return try SBDecoder.decode(R.self, from: data)
    }

    // MARK: – RPC (void)

    func rpcVoid(
        function: String,
        params: [String: Any],
        anonOnly: Bool = false
    ) async throws {
        var req = makeRequest(
            url: URL(string: "\(base)/rest/v1/rpc/\(function)")!, method: "POST", anonOnly: anonOnly)
        req.httpBody = try JSONSerialization.data(withJSONObject: params)
        let (data, res) = try await URLSession.shared.data(for: req)
        try validate(res, data)
    }

    // MARK: – Helpers

    private func makeRequest(url: URL, method: String, anonOnly: Bool = false) -> URLRequest {
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.cachePolicy = .reloadIgnoringLocalCacheData
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(anon, forHTTPHeaderField: "apikey")
        let token = (!anonOnly && accessToken != nil) ? accessToken! : anon
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return r
    }

    private func persistSession(_ r: SBAuthResponse) {
        accessToken  = r.accessToken
        refreshToken = r.refreshToken
        userId       = r.user?.id
        UserDefaults.standard.set(r.accessToken,  forKey: "sb_at")
        UserDefaults.standard.set(r.refreshToken, forKey: "sb_rt")
        UserDefaults.standard.set(r.user?.id,     forKey: "sb_uid")
    }

    private func authPost<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        let url = URL(string: "\(base)\(path)")!
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(anon, forHTTPHeaderField: "apikey")
        r.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, res) = try await URLSession.shared.data(for: r)
        try validate(res, data)
        return try SBDecoder.decode(T.self, from: data)
    }

    private func validate(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode >= 400 else { return }
        let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw SupabaseError.http(http.statusCode, msg)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared coders (camelCase Swift ↔ snake_case Supabase)
// ─────────────────────────────────────────────────────────────────────────────
let SBEncoder: JSONEncoder = {
    let e = JSONEncoder()
    e.keyEncodingStrategy  = .convertToSnakeCase
    e.dateEncodingStrategy = .iso8601
    return e
}()

let SBDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy  = .convertFromSnakeCase
    d.dateDecodingStrategy = .custom { decoder in
        let s = try decoder.singleValueContainer().decode(String.self)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = f.date(from: s) { return date }
        f.formatOptions = .withInternetDateTime
        if let date = f.date(from: s) { return date }
        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Unrecognized date: \(s)"))
    }
    return d
}()
