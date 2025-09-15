import Foundation

// MARK: - Collection Tracking Models
struct CollectionSession: Codable {
    let id: String
    let genre: String
    let startTime: Date
    let endTime: Date?
    let targetCount: Int
    let actualCount: Int
    let apiCallsUsed: Int
    let status: SessionStatus
    let lastPageToken: String?
    
    enum SessionStatus: String, Codable {
        case active = "active"
        case completed = "completed"
        case paused = "paused"
        case failed = "failed"
    }
}

struct DailyQuota: Codable {
    let date: String // YYYY-MM-DD
    let apiCallsUsed: Int
    let videosCollected: Int
    let sessionsActive: [String] // Session IDs
}

// MARK: - YouTube Collection Tracker
class YouTubeCollectionTracker {
    static let shared = YouTubeCollectionTracker()
    
    private let quotaLimit = 10_000 // YouTube API daily limit
    private let userDefaults = UserDefaults.standard
    private let dateFormatter: DateFormatter
    
    private init() {
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    // MARK: - Collection Session Management
    
    func startCollectionSession(
        genre: String,
        targetCount: Int
    ) -> CollectionSession? {
        
        // Check if we can start new collection today
        guard canStartNewCollection() else {
            print("❌ Cannot start collection: Daily quota exceeded")
            return nil
        }
        
        // Check if genre already being collected
        if let existingSession = getActiveSession(for: genre) {
            print("⚠️ Active session exists for \(genre). Resume instead?")
            return existingSession
        }
        
        let session = CollectionSession(
            id: UUID().uuidString,
            genre: genre,
            startTime: Date(),
            endTime: nil,
            targetCount: targetCount,
            actualCount: 0,
            apiCallsUsed: 0,
            status: .active,
            lastPageToken: nil
        )
        
        saveSession(session)
        updateDailyQuota(apiCallsUsed: 0, videosCollected: 0)
        
        print("🚀 Started collection session for \(genre) (target: \(targetCount))")
        return session
    }
    
    func updateSession(
        sessionId: String,
        videosCollected: Int,
        apiCallsUsed: Int,
        pageToken: String? = nil,
        status: CollectionSession.SessionStatus? = nil
    ) {
        
        guard var session = getSession(id: sessionId) else {
            print("❌ Session \(sessionId) not found")
            return
        }
        
        let newApiCalls = apiCallsUsed - session.apiCallsUsed
        let newVideos = videosCollected - session.actualCount
        
        session = CollectionSession(
            id: session.id,
            genre: session.genre,
            startTime: session.startTime,
            endTime: status == .completed ? Date() : session.endTime,
            targetCount: session.targetCount,
            actualCount: videosCollected,
            apiCallsUsed: apiCallsUsed,
            status: status ?? session.status,
            lastPageToken: pageToken ?? session.lastPageToken
        )
        
        saveSession(session)
        updateDailyQuota(apiCallsUsed: newApiCalls, videosCollected: newVideos)
        
        print("📊 Updated session \(session.genre): \(videosCollected)/\(session.targetCount) videos, \(apiCallsUsed) API calls")
    }
    
    func completeSession(sessionId: String) {
        updateSession(sessionId: sessionId, videosCollected: 0, apiCallsUsed: 0, status: .completed)
    }
    
    // MARK: - Quota Management
    
    func canStartNewCollection() -> Bool {
        let today = todayString()
        let quota = getDailyQuota(for: today)
        return quota.apiCallsUsed < quotaLimit
    }
    
    func getRemainingQuota() -> Int {
        let today = todayString()
        let quota = getDailyQuota(for: today)
        return max(0, quotaLimit - quota.apiCallsUsed)
    }
    
    func estimateVideosFromQuota(_ apiCalls: Int) -> Int {
        // Estimate: ~25 API calls per 50 videos (search + details)
        // 1 search call = 50 video IDs
        // 1 details call = 50 video details  
        // So ~1 API call per video on average
        return apiCalls
    }
    
    func estimateQuotaForVideos(_ videoCount: Int) -> Int {
        // Conservative estimate: 1.5 API calls per video
        // (accounts for pagination, retries, etc.)
        return Int(Double(videoCount) * 1.5)
    }
    
    // MARK: - Duplicate Prevention
    
    func hasCollectedGenre(_ genre: String) -> Bool {
        let sessions = getAllSessions()
        return sessions.contains { session in
            session.genre == genre && 
            session.status == .completed &&
            session.actualCount >= session.targetCount
        }
    }
    
    func getGenreProgress(_ genre: String) -> (collected: Int, target: Int)? {
        if let session = getActiveSession(for: genre) {
            return (session.actualCount, session.targetCount)
        }
        
        // Check completed sessions
        let sessions = getAllSessions()
        let completedSession = sessions.first { session in
            session.genre == genre && session.status == .completed
        }
        
        if let completed = completedSession {
            return (completed.actualCount, completed.targetCount)
        }
        
        return nil
    }
    
    // MARK: - Storage Methods
    
    private func saveSession(_ session: CollectionSession) {
        let key = "youtube_session_\(session.id)"
        let data = try? JSONEncoder().encode(session)
        userDefaults.set(data, forKey: key)
        
        // Also track in sessions list
        var sessionIds = getSessionIds()
        if !sessionIds.contains(session.id) {
            sessionIds.append(session.id)
            userDefaults.set(sessionIds, forKey: "youtube_session_ids")
        }
    }
    
    private func getSession(id: String) -> CollectionSession? {
        let key = "youtube_session_\(id)"
        guard let data = userDefaults.data(forKey: key),
              let session = try? JSONDecoder().decode(CollectionSession.self, from: data) else {
            return nil
        }
        return session
    }
    
    private func getActiveSession(for genre: String) -> CollectionSession? {
        let sessions = getAllSessions()
        return sessions.first { session in
            session.genre == genre && session.status == .active
        }
    }
    
    private func getAllSessions() -> [CollectionSession] {
        let sessionIds = getSessionIds()
        return sessionIds.compactMap { getSession(id: $0) }
    }
    
    private func getSessionIds() -> [String] {
        return userDefaults.stringArray(forKey: "youtube_session_ids") ?? []
    }
    
    private func updateDailyQuota(apiCallsUsed: Int, videosCollected: Int) {
        let today = todayString()
        var quota = getDailyQuota(for: today)
        
        quota = DailyQuota(
            date: today,
            apiCallsUsed: quota.apiCallsUsed + apiCallsUsed,
            videosCollected: quota.videosCollected + videosCollected,
            sessionsActive: quota.sessionsActive
        )
        
        let key = "youtube_quota_\(today)"
        let data = try? JSONEncoder().encode(quota)
        userDefaults.set(data, forKey: key)
    }
    
    private func getDailyQuota(for date: String) -> DailyQuota {
        let key = "youtube_quota_\(date)"
        guard let data = userDefaults.data(forKey: key),
              let quota = try? JSONDecoder().decode(DailyQuota.self, from: data) else {
            return DailyQuota(date: date, apiCallsUsed: 0, videosCollected: 0, sessionsActive: [])
        }
        return quota
    }
    
    private func todayString() -> String {
        return dateFormatter.string(from: Date())
    }
    
    // MARK: - Reporting
    
    func generateReport() -> String {
        let today = todayString()
        let quota = getDailyQuota(for: today)
        let sessions = getAllSessions()
        let activeSessions = sessions.filter { $0.status == .active }
        let completedSessions = sessions.filter { $0.status == .completed }
        
        var report = """
        📊 YouTube Collection Report (\(today))
        
        🔹 Quota Usage: \(quota.apiCallsUsed)/\(quotaLimit) API calls (\(Int(Double(quota.apiCallsUsed)/Double(quotaLimit)*100))%)
        🔹 Videos Collected Today: \(quota.videosCollected)
        🔹 Remaining Quota: \(getRemainingQuota()) calls (~\(estimateVideosFromQuota(getRemainingQuota())) videos)
        
        📈 Active Sessions (\(activeSessions.count)):
        """
        
        for session in activeSessions {
            let progress = Int(Double(session.actualCount)/Double(session.targetCount)*100)
            report += "\n   • \(session.genre): \(session.actualCount)/\(session.targetCount) (\(progress)%)"
        }
        
        report += "\n\n✅ Completed Sessions (\(completedSessions.count)):"
        for session in completedSessions {
            report += "\n   • \(session.genre): \(session.actualCount) videos"
        }
        
        return report
    }
}