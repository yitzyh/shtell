import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - TMDB Models
struct TMDBResponse: Codable {
    let results: [TMDBMovie]
    let totalResults: Int
    let totalPages: Int
    
    enum CodingKeys: String, CodingKey {
        case results
        case totalResults = "total_results"
        case totalPages = "total_pages"
    }
}

struct TMDBMovie: Codable {
    let id: Int
    let title: String?
    let name: String? // For TV shows
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let firstAirDate: String? // For TV shows
    let voteAverage: Double
    let voteCount: Int
    let popularity: Double
    let genreIds: [Int]
    let adult: Bool
    let imdbId: String?
    let mediaType: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, adult, popularity
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case genreIds = "genre_ids"
        case imdbId = "imdb_id"
        case mediaType = "media_type"
    }
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

struct TMDBGenresResponse: Codable {
    let genres: [TMDBGenre]
}

struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double
    let voteCount: Int
    let popularity: Double
    let genres: [TMDBGenre]
    let adult: Bool
    let imdbId: String?
    let runtime: Int?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, adult, popularity, genres, runtime, status
        case posterPath = "poster_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case imdbId = "imdb_id"
    }
}

// MARK: - TMDB Service
class TMDBService {
    static let shared = TMDBService()
    
    private let apiKey = "189d26e57e32ebac071f7ceee0c61507"
    private let readAccessToken = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIxODlkMjZlNTdlMzJlYmFjMDcxZjdjZWVlMGM2MTUwNyIsIm5iZiI6MTc1NTM3ODUzMi4yOCwic3ViIjoiNjhhMGYzNjRjNTQwNDNiOWI0MDJjZTY3Iiwic2NvcGVzIjpbImFwaV9yZWFkIl0sInZlcnNpb24iOjF9.2wwd9yDWYc96Q62xO_exRpnrWZUiIzM2Xsb8-Wa8t20"
    private let baseURL = "https://api.themoviedb.org/3"
    private let imageBaseURL = "https://image.tmdb.org/t/p/w500"
    
    private init() {}
    
    // MARK: - Popular Movies
    func fetchPopularMovies(page: Int = 1) async throws -> TMDBResponse {
        let url = "\(baseURL)/movie/popular?api_key=\(apiKey)&page=\(page)"
        return try await performRequest(url: url, responseType: TMDBResponse.self)
    }
    
    // MARK: - Popular TV Shows
    func fetchPopularTVShows(page: Int = 1) async throws -> TMDBResponse {
        let url = "\(baseURL)/tv/popular?api_key=\(apiKey)&page=\(page)"
        return try await performRequest(url: url, responseType: TMDBResponse.self)
    }
    
    // MARK: - Top Rated Movies
    func fetchTopRatedMovies(page: Int = 1) async throws -> TMDBResponse {
        let url = "\(baseURL)/movie/top_rated?api_key=\(apiKey)&page=\(page)"
        return try await performRequest(url: url, responseType: TMDBResponse.self)
    }
    
    // MARK: - Movie Details (includes IMDB ID)
    func fetchMovieDetails(movieId: Int) async throws -> TMDBMovieDetails {
        let url = "\(baseURL)/movie/\(movieId)?api_key=\(apiKey)&append_to_response=external_ids"
        return try await performRequest(url: url, responseType: TMDBMovieDetails.self)
    }
    
    // MARK: - TV Show Details (includes IMDB ID)
    func fetchTVDetails(tvId: Int) async throws -> TMDBMovieDetails {
        let url = "\(baseURL)/tv/\(tvId)?api_key=\(apiKey)&append_to_response=external_ids"
        return try await performRequest(url: url, responseType: TMDBMovieDetails.self)
    }
    
    // MARK: - Genre Lists
    func fetchMovieGenres() async throws -> TMDBGenresResponse {
        let url = "\(baseURL)/genre/movie/list?api_key=\(apiKey)"
        return try await performRequest(url: url, responseType: TMDBGenresResponse.self)
    }
    
    func fetchTVGenres() async throws -> TMDBGenresResponse {
        let url = "\(baseURL)/genre/tv/list?api_key=\(apiKey)"
        return try await performRequest(url: url, responseType: TMDBGenresResponse.self)
    }
    
    // MARK: - Discover Movies by Genre
    func discoverMoviesByGenre(genreId: Int, page: Int = 1) async throws -> TMDBResponse {
        let url = "\(baseURL)/discover/movie?api_key=\(apiKey)&with_genres=\(genreId)&page=\(page)&sort_by=popularity.desc"
        return try await performRequest(url: url, responseType: TMDBResponse.self)
    }
    
    // MARK: - Generic Request Handler
    private func performRequest<T: Codable>(url: String, responseType: T.Type) async throws -> T {
        print("🎬 TMDB API Request: \(url)")
        
        guard let requestURL = URL(string: url) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: requestURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 TMDB Response: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "TMDB", code: httpResponse.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "TMDB API error: \(errorString)"
                ])
            }
        }
        
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(responseType, from: data)
            return result
        } catch {
            print("❌ TMDB JSON Decode Error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Raw JSON: \(jsonString)")
            }
            throw error
        }
    }
    
    // MARK: - Bulk Data Collection
    func collectPopularContent(moviePages: Int = 5, tvPages: Int = 5) async throws -> [TMDBMovie] {
        print("🎬 Starting TMDB bulk collection...")
        var allMovies: [TMDBMovie] = []
        
        // Collect popular movies
        for page in 1...moviePages {
            print("📽️ Fetching popular movies page \(page)...")
            let response = try await fetchPopularMovies(page: page)
            allMovies.append(contentsOf: response.results)
            
            // Rate limiting
            try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
        }
        
        // Collect popular TV shows
        for page in 1...tvPages {
            print("📺 Fetching popular TV shows page \(page)...")
            let response = try await fetchPopularTVShows(page: page)
            allMovies.append(contentsOf: response.results)
            
            // Rate limiting
            try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
        }
        
        print("✅ TMDB collection complete: \(allMovies.count) items")
        return allMovies
    }
    
    // MARK: - Helper Methods
    func constructPosterURL(_ posterPath: String?) -> String {
        guard let posterPath = posterPath else {
            return "https://via.placeholder.com/500x750/cccccc/666666?text=No+Image"
        }
        return "\(imageBaseURL)\(posterPath)"
    }
    
    func constructIMDBURL(imdbId: String?) -> String? {
        guard let imdbId = imdbId else { return nil }
        return "https://www.imdb.com/title/\(imdbId)/"
    }
}

// MARK: - Extensions
extension TMDBMovie {
    var displayTitle: String {
        return title ?? name ?? "Unknown Title"
    }
    
    var displayDate: String? {
        return releaseDate ?? firstAirDate
    }
    
    var contentType: String {
        if title != nil {
            return "movie"
        } else if name != nil {
            return "tv"
        } else {
            return "unknown"
        }
    }
}