import Foundation
import SQLite3

class URLCache {
    private var db: OpaquePointer?
    private let dbPath: String
    
    init() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        dbPath = documentsPath.appendingPathComponent("url_cache.sqlite").path
        
        openDatabase()
        createTable()
    }
    
    deinit {
        sqlite3_close(db)
    }
    
    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("❌ URLCache: Unable to open database at \(dbPath)")
        } else {
            print("✅ URLCache: Database opened successfully at \(dbPath)")
        }
    }
    
    private func createTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS cached_urls (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                url TEXT NOT NULL,
                title TEXT,
                category TEXT NOT NULL,
                cached_date INTEGER NOT NULL,
                UNIQUE(url, category)
            );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ URLCache: Error creating table")
        } else {
            print("✅ URLCache: Table created successfully")
        }
    }
    
    func saveURLs(_ urls: [String], category: String, titles: [String]? = nil) {
        // Limit URLs per category to prevent disk space issues
        let maxURLsPerCategory = 100
        let urlsToSave = Array(urls.prefix(maxURLsPerCategory))
        
        // Clean up old entries before saving new ones
        removeOldEntries(olderThanDays: 3)
        limitCategorySize(category: category, maxCount: maxURLsPerCategory)
        
        let insertSQL = "INSERT OR REPLACE INTO cached_urls (url, title, category, cached_date) VALUES (?, ?, ?, ?)"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) != SQLITE_OK {
            print("❌ URLCache: Error preparing insert statement")
            return
        }
        
        let currentTime = Int64(Date().timeIntervalSince1970)
        var savedCount = 0
        
        for (index, url) in urlsToSave.enumerated() {
            // Skip empty URLs
            guard !url.isEmpty else {
                continue
            }
            
            let title = titles?[safe: index] ?? ""
            
            sqlite3_bind_text(statement, 1, url, -1, nil)
            sqlite3_bind_text(statement, 2, title, -1, nil)
            sqlite3_bind_text(statement, 3, category, -1, nil)
            sqlite3_bind_int64(statement, 4, currentTime)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("❌ URLCache: Error inserting URL: \(url)")
            } else {
                savedCount += 1
            }
            
            sqlite3_reset(statement)
        }
        
        sqlite3_finalize(statement)
        print("✅ URLCache: Saved \(savedCount)/\(urls.count) URLs for category '\(category)' (limited to \(maxURLsPerCategory))")
    }
    
    func getRandomURL(category: String) -> String? {
        let selectSQL = "SELECT url FROM cached_urls WHERE category = ? AND url != '' AND url IS NOT NULL ORDER BY RANDOM() LIMIT 1"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) != SQLITE_OK {
            print("❌ URLCache: Error preparing select statement")
            return nil
        }
        
        sqlite3_bind_text(statement, 1, category, -1, nil)
        
        var result: String?
        if sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                let url = String(cString: cString)
                // Additional validation to ensure URL is not empty
                result = url.isEmpty ? nil : url
            }
        }
        
        sqlite3_finalize(statement)
        return result
    }
    
    func getAllURLs(category: String) -> [String] {
        let selectSQL = "SELECT url FROM cached_urls WHERE category = ?"
        var statement: OpaquePointer?
        var urls: [String] = []
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) != SQLITE_OK {
            print("❌ URLCache: Error preparing select statement")
            return urls
        }
        
        sqlite3_bind_text(statement, 1, category, -1, nil)
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                urls.append(String(cString: cString))
            }
        }
        
        sqlite3_finalize(statement)
        return urls
    }
    
    func getCacheInfo() -> [String: Int] {
        let selectSQL = "SELECT category, COUNT(*) FROM cached_urls GROUP BY category"
        var statement: OpaquePointer?
        var info: [String: Int] = [:]
        
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) != SQLITE_OK {
            print("❌ URLCache: Error preparing cache info statement")
            return info
        }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                let category = String(cString: cString)
                let count = Int(sqlite3_column_int(statement, 1))
                info[category] = count
            }
        }
        
        sqlite3_finalize(statement)
        return info
    }
    
    func clearCache() {
        let deleteSQL = "DELETE FROM cached_urls"
        if sqlite3_exec(db, deleteSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ URLCache: Error clearing cache")
        } else {
            print("✅ URLCache: Cache cleared successfully")
        }
    }
    
    func removeOldEntries(olderThanDays days: Int = 7) {
        let cutoffTime = Int64(Date().timeIntervalSince1970) - Int64(days * 24 * 60 * 60)
        let deleteSQL = "DELETE FROM cached_urls WHERE cached_date < ?"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) != SQLITE_OK {
            print("❌ URLCache: Error preparing delete statement")
            return
        }
        
        sqlite3_bind_int64(statement, 1, cutoffTime)
        
        if sqlite3_step(statement) == SQLITE_DONE {
            let deletedCount = sqlite3_changes(db)
            if deletedCount > 0 {
                print("✅ URLCache: Removed \(deletedCount) old entries")
            }
        }
        
        sqlite3_finalize(statement)
    }
    
    func limitCategorySize(category: String, maxCount: Int) {
        // Keep only the most recent entries for this category
        let deleteSQL = """
            DELETE FROM cached_urls 
            WHERE category = ? AND id NOT IN (
                SELECT id FROM cached_urls 
                WHERE category = ? 
                ORDER BY cached_date DESC 
                LIMIT ?
            )
        """
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) != SQLITE_OK {
            print("❌ URLCache: Error preparing category limit statement")
            return
        }
        
        sqlite3_bind_text(statement, 1, category, -1, nil)
        sqlite3_bind_text(statement, 2, category, -1, nil)
        sqlite3_bind_int(statement, 3, Int32(maxCount))
        
        if sqlite3_step(statement) == SQLITE_DONE {
            let deletedCount = sqlite3_changes(db)
            if deletedCount > 0 {
                print("✅ URLCache: Limited category '\(category)' to \(maxCount) entries (removed \(deletedCount))")
            }
        }
        
        sqlite3_finalize(statement)
    }
}

// Helper extension for safe array access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}