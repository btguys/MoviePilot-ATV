//
//  APIService.swift
//  MoviePilotTV
//
//  Created on 2025-12-30.
//

import Foundation

// MARK: - User Info Model

struct UserInfo: Codable, Identifiable {
    var id: Int
    var name: String
    var email: String?
    var avatar: String?
    var is_active: Bool
    var is_superuser: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case avatar
        case is_active
        case is_superuser
    }
}

// MARK: - API Error

enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case authenticationFailed
    case decodingError(Error)
    case serverError(Int)
    case tokenExpired
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的服务器地址，请检查 API Endpoint 格式"
        case .networkError(let error):
            return "网络连接失败: \(error.localizedDescription)"
        case .invalidResponse:
            return "服务器响应无效"
        case .authenticationFailed:
            return "登录失败，请检查用户名和密码是否正确"
        case .decodingError(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .serverError(let code):
            return "服务器错误 (HTTP \(code))"
        case .tokenExpired:
            return "登录已过期，请重新登录"
        }
    }
}

@MainActor
class APIService {
    static let shared = APIService()
    private let authManager = AuthenticationManager.shared
    private let urlSession: URLSession
    
    private init() {
        // 配置 URLSession 的磁盘缓存
        let config = URLSessionConfiguration.default
        
        // 启用 URLCache 磁盘缓存
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,      // 50MB 内存缓存
            diskCapacity: 500 * 1024 * 1024,       // 500MB 磁盘缓存
            diskPath: nil                          // 使用系统默认缓存路径
        )
        
        // 缓存策略：优先使用缓存，缓存失效后才请求网络
        config.requestCachePolicy = .returnCacheDataElseLoad
        
        // 网络超时设置
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        
        self.urlSession = URLSession(configuration: config)
        
        print("🔵 [APIService] 已初始化 URLSession 缓存配置 - 磁盘: 500MB, 内存: 50MB")
    }
    
    private func createRequest(endpoint: String, method: String = "GET") throws -> URLRequest {
        let fullURL = "\(authManager.apiEndpoint)\(endpoint)"
        print("🔵 [APIService] 创建请求: \(method) \(fullURL)")
        
        guard let url = URL(string: fullURL) else {
            print("❌ [APIService] 无效的 URL: \(fullURL)")
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 检查 token 是否为空
        if authManager.accessToken.isEmpty {
            print("⚠️ [APIService] Access Token 为空！")
        } else {
            request.setValue("Bearer \(authManager.accessToken)", forHTTPHeaderField: "Authorization")
            print("   Token: \(authManager.accessToken.prefix(20))...")
        }
        
        return request
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        print("📡 [APIService] 发送请求: \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "unknown")")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [APIService] 无效的响应类型")
                throw APIError.invalidResponse
            }
            
            print("   HTTP Status: \(httpResponse.statusCode)")
            
            // 检查是否是认证失败 (401 或 403)
            if httpResponse.statusCode == 401 {
                print("⚠️ [APIService] 未认证 (401) - Token 可能无效或已过期")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   响应内容: \(responseString)")
                }
                authManager.handleTokenExpired()
                throw APIError.tokenExpired
            }
            
            // 检查是否是 token 过期 (403 + {"detail":"token校验不通过"})
            if httpResponse.statusCode == 403 {
                if let responseString = String(data: data, encoding: .utf8),
                   responseString.contains("token校验不通过") {
                    print("⚠️ [APIService] Token 已过期")
                    authManager.handleTokenExpired()
                    throw APIError.tokenExpired
                }
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("❌ [APIService] 服务器错误: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   响应内容: \(responseString.prefix(200))")
                }
                throw APIError.serverError(httpResponse.statusCode)
            }
            
            do {
                let decoder = JSONDecoder()
                // 不使用 convertFromSnakeCase,因为我们在 CodingKeys 中手动映射了
                let result = try decoder.decode(T.self, from: data)
                print("✅ [APIService] 成功解析数据 (类型: \(T.self))")
                return result
            } catch {
                print("❌ [APIService] 数据解析失败: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   缺少字段: \(key.stringValue), 路径: \(context.codingPath)")
                    case .typeMismatch(let type, let context):
                        print("   类型不匹配: 期望 \(type), 路径: \(context.codingPath)")
                    case .valueNotFound(let type, let context):
                        print("   值为空: 类型 \(type), 路径: \(context.codingPath)")
                    case .dataCorrupted(let context):
                        print("   数据损坏: \(context)")
                    @unknown default:
                        print("   未知解码错误")
                    }
                }
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   原始数据前500字符: \(responseString.prefix(500))")
                }
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ [APIService] 网络错误: \(error)")
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - User API
    
    func getCurrentUser() async throws -> UserInfo {
        let request = try createRequest(endpoint: "/api/v1/user/current")
        return try await performRequest(request)
    }
    
    // MARK: - Media API
    
    func getRecommendations(source: String) async throws -> [MediaItem] {
        let request = try createRequest(endpoint: "/api/v1/recommend/\(source)")
        return try await performRequest(request)
    }
    
    func searchMedia(keyword: String, page: Int = 1) async throws -> [MediaItem] {
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let request = try createRequest(endpoint: "/api/v1/media/search?title=\(encodedKeyword)&page=\(page)")
        return try await performRequest(request)
    }
    
    func getTrending(page: Int = 1) async throws -> [MediaItem] {
        let request = try createRequest(endpoint: "/api/v1/recommend/tmdb_trending?page=\(page)")
        return try await performRequest(request)
    }
    
    // 获取媒体详情 (支持 TMDB 和豆瓣)
    func getMediaDetail(source: String, id: String, title: String, year: String?, typeName: String) async throws -> MediaDetail {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let yearParam = year.map { "&year=\($0)" } ?? ""
        let encodedType = typeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // source 应该是 "tmdb" 或 "douban"
        let endpoint = "/api/v1/media/\(source):\(id)?title=\(encodedTitle)\(yearParam)&type_name=\(encodedType)"
        let request = try createRequest(endpoint: endpoint)
        return try await performRequest(request)
    }
    
    // 获取演职人员信息 (仅支持 TMDB)
    func getCredits(tmdbId: Int, mediaType: String) async throws -> CreditsResponse {
        // mediaType: "电影" 或 "电视剧"
        let encodedType = mediaType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let endpoint = "/api/v1/tmdb/credits/\(tmdbId)/\(encodedType)"
        let request = try createRequest(endpoint: endpoint)
        return try await performRequest(request)
    }
    
    // 搜索资源 (支持 TMDB 和豆瓣)
    func searchMediaResources(source: String, id: String, mtype: String, title: String, year: String?, season: String?, sites: String) async throws -> SearchResult {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedType = mtype.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let yearParam = year ?? ""
        let seasonParam = season ?? ""
        
        // source 应该是 "tmdb" 或 "douban"
        let endpoint = "/api/v1/search/media/\(source):\(id)?mtype=\(encodedType)&area=imdbid&title=\(encodedTitle)&year=\(yearParam)&season=\(seasonParam)&sites=\(sites)"
        let request = try createRequest(endpoint: endpoint)
        return try await performRequest(request)
    }
    
    // MARK: - Subscribe API
    
    func getSubscriptions(type: String? = nil) async throws -> [Subscription] {
        var endpoint = "/api/v1/subscribe/"
        if let type = type {
            endpoint += "?type=\(type)"
        }
        print("🔵 [APIService] 获取订阅列表: \(endpoint)")
        var request = try createRequest(endpoint: endpoint)
        
        // 禁用缓存，确保获取最新数据
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // 打印请求详情确认是GET
        print("🔵 [APIService] 创建请求: \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "UNKNOWN")")
        
        // 尝试两种解析方式：直接数组或包装格式
        do {
            // 先尝试直接解析为数组
            let subscriptions: [Subscription] = try await performRequest(request)
            print("✅ [APIService] 成功获取 \(subscriptions.count) 个订阅（直接数组格式）")
            return subscriptions
        } catch {
            print("⚠️ [APIService] 直接数组解析失败，尝试包装格式")
            // 如果失败，尝试包装格式
            let response: MoviePilotResponse<[Subscription]> = try await performRequest(request)
            let subscriptions = response.data ?? []
            print("✅ [APIService] 成功获取 \(subscriptions.count) 个订阅（包装格式）")
            return subscriptions
        }
    }
    
    func addSubscription(tmdbId: Int, name: String, year: Int?, type: String, season: Int?) async throws {
        var request = try createRequest(endpoint: "/api/v1/subscribe/", method: "POST")
        
        var body: [String: Any] = [
            "tmdbid": tmdbId,
            "name": name,
            "type": type,
            "season": season ?? 0,
            "best_version": 0
        ]
        
        if let year = year {
            body["year"] = String(year)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 订阅API返回包装格式
        struct SubscribeResponseData: Codable {
            let id: Int
        }
        let _: MoviePilotResponse<SubscribeResponseData> = try await performRequest(request)
    }
    
    // 新增：支持豆瓣和TMDB的通用订阅方法
    func subscribe(name: String, type: String, year: String?, tmdbId: Int?, doubanId: String?, season: Int = 0) async throws {
        print("🔵 [APIService] 订阅请求参数:")
        print("   name: \(name)")
        print("   type: \(type)")
        print("   year: \(year ?? "nil")")
        print("   tmdbId: \(tmdbId?.description ?? "nil")")
        print("   doubanId: \(doubanId ?? "nil")")
        print("   season: \(season)")
        
        var request = try createRequest(endpoint: "/api/v1/subscribe/", method: "POST")
        
        // 打印设置body前的headers
        print("   📋 设置body前的Headers:")
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key == "Authorization" {
                    print("      \(key): Bearer \(authManager.accessToken.prefix(20))...")
                } else {
                    print("      \(key): \(value)")
                }
            }
        }
        
        var body: [String: Any] = [
            "name": name,
            "type": type,
            "season": season,
            "best_version": 0
        ]
        
        if let year = year {
            body["year"] = year
        }
        
        if let tmdbId = tmdbId {
            body["tmdbid"] = tmdbId
            body["doubanid"] = NSNull()
        } else if let doubanId = doubanId {
            body["doubanid"] = doubanId
            body["tmdbid"] = NSNull()
        }
        
        body["bangumiid"] = NSNull()
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        
        if let bodyString = String(data: bodyData, encoding: .utf8) {
            print("   📦 请求体: \(bodyString)")
        }
        
        request.httpBody = bodyData
        
        // 打印设置body后的headers
        print("   📋 设置body后的Headers:")
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                if key == "Authorization" {
                    print("      \(key): Bearer \(authManager.accessToken.prefix(20))...")
                } else {
                    print("      \(key): \(value)")
                }
            }
        } else {
            print("      ⚠️ Headers 为 nil!")
        }
        
        // 订阅API返回包装格式 {"success":true,"message":"","data":{"id":54}}
        struct SubscribeResponseData: Codable {
            let id: Int
        }
        let _: MoviePilotResponse<SubscribeResponseData> = try await performRequest(request)
    }
    
    func deleteSubscription(id: Int) async throws {
        let request = try createRequest(endpoint: "/api/v1/subscribe/\(id)", method: "DELETE")
        let _: EmptyResponse = try await performRequest(request)
    }
    
    // 检查订阅状态
    func checkSubscriptionStatus(source: String, id: String, title: String, season: Int = 0) async throws -> (isSubscribed: Bool, subscriptionId: Int?) {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let endpoint = "/api/v1/subscribe/media/\(source):\(id)?season=\(season)&title=\(encodedTitle)"

        print("🔵 [APIService] 检查订阅状态: \(endpoint)")
        var request = try createRequest(endpoint: endpoint)

        // 禁用缓存，确保获取最新数据
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [APIService] 无效的响应类型")
            throw APIError.invalidResponse
        }

        print("   HTTP Status: \(httpResponse.statusCode)")

        // 检查是否是认证失败
        if httpResponse.statusCode == 401 {
            print("⚠️ [APIService] 未认证 (401) - Token 可能无效或已过期")
            authManager.handleTokenExpired()
            throw APIError.tokenExpired
        }

        // 检查是否是 token 过期
        if httpResponse.statusCode == 403 {
            if let responseString = String(data: data, encoding: .utf8),
               responseString.contains("token校验不通过") {
                print("⚠️ [APIService] Token 已过期")
                authManager.handleTokenExpired()
                throw APIError.tokenExpired
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ [APIService] 服务器错误: \(httpResponse.statusCode)")
            throw APIError.serverError(httpResponse.statusCode)
        }

        // 特殊处理订阅状态检查：API返回Subscription对象（已订阅）或null（未订阅）
        if let responseString = String(data: data, encoding: .utf8) {
            if responseString.trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
                print("✅ [APIService] 订阅状态检查成功: 未订阅 (返回null)")
                return (false, nil)
            }

            // 尝试解析为Subscription对象
            do {
                let decoder = JSONDecoder()
                let subscription = try decoder.decode(Subscription.self, from: data)
                let isSubscribed = (subscription.id ?? 0) != 0 // id为nil或0都视为未订阅
                print("✅ [APIService] 订阅状态检查成功: \(isSubscribed ? "已订阅 (ID: \(subscription.id ?? 0))" : "未订阅")")
                return (isSubscribed, subscription.id)
            } catch {
                print("❌ [APIService] 解析Subscription对象失败: \(error)")
                print("   原始数据: \(responseString.prefix(500))")
                // 如果解析失败，默认认为未订阅
                return (false, nil)
            }
        } else {
            print("❌ [APIService] 无法读取响应数据")
            return (false, nil)
        }
    }
    
    // MARK: - Episode API
    
    /// 获取剧集详情列表
    /// - Parameters:
    ///   - tmdbId: TMDB ID
    ///   - seasonNumber: 季号
    /// - Returns: 剧集详情数组
    func getEpisodeDetails(tmdbId: Int, seasonNumber: Int) async throws -> [TMDBEpisodeDetail] {
        let endpoint = "/api/v1/tmdb/\(tmdbId)/\(seasonNumber)"
        print("📡 [APIService] 获取剧集详情: \(endpoint)")
        let request = try createRequest(endpoint: endpoint)
        return try await performRequest(request)
    }
    
    // MARK: - Download API
    
    func getDownloads() async throws -> [Download] {
        var request = try createRequest(endpoint: "/api/v1/download")
        
        // 禁用缓存，确保获取最新数据
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        return try await performRequest(request)
    }
    
    func getDownloadHistory(page: Int = 1, count: Int = 30) async throws -> [DownloadHistory] {
        let request = try createRequest(endpoint: "/api/v1/download/history?page=\(page)&count=\(count)")
        let response: DownloadHistoryResponse = try await performRequest(request)
        return response.items ?? []
    }
    
    // MARK: - Site API
    
    func getSites() async throws -> [Site] {
        let request = try createRequest(endpoint: "/api/v1/site/")
        return try await performRequest(request)
    }
    
    func getSiteUserData() async throws -> [SiteUserData] {
        let request = try createRequest(endpoint: "/api/v1/site/userdata/latest")
        return try await performRequest(request)
    }
    
    func updateSiteStatus(id: Int, enabled: Bool) async throws {
        var request = try createRequest(endpoint: "/api/v1/site/\(id)", method: "PUT")
        let body = ["enabled": enabled]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let _: EmptyResponse = try await performRequest(request)
    }
    
    // MARK: - System Status API Methods

    // 获取存储空间信息
    func fetchStorageInfo() async throws -> StorageInfo {
        let url = URL(string: authManager.apiEndpoint + "/api/v1/dashboard/storage")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authManager.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let storageInfo = try JSONDecoder().decode(StorageInfo.self, from: data)
        print("✅ [APIService] 获取存储信息成功: 已用 \(storageInfo.usedStorageText) / 总计 \(storageInfo.totalStorageText)")
        return storageInfo
    }
    
    // 获取下载器速度和统计信息
    func fetchDownloaderInfo() async throws -> DownloaderInfo {
        let url = URL(string: authManager.apiEndpoint + "/api/v1/dashboard/downloader")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authManager.accessToken)", forHTTPHeaderField: "Authorization")
        
        // 禁用缓存，确保获取实时数据
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let downloaderInfo = try JSONDecoder().decode(DownloaderInfo.self, from: data)
        print("✅ [APIService] 获取下载信息成功: 下载速度 \(downloaderInfo.downloadSpeedText), 上传速度 \(downloaderInfo.uploadSpeedText)")
        return downloaderInfo
    }
    
    // 获取系统状态（同时获取存储和下载信息）
    func fetchSystemStatus() async throws -> SystemStatus {
        var storageInfo: StorageInfo?
        var downloaderInfo: DownloaderInfo?
        
        // 并发获取两个信息
        async let storage = try? fetchStorageInfo()
        async let downloader = try? fetchDownloaderInfo()
        
        (storageInfo, downloaderInfo) = (await storage, await downloader)
        
        return SystemStatus(
            storageInfo: storageInfo,
            downloaderInfo: downloaderInfo,
            lastUpdated: Date()
        )
    }

    // 提交下载任务
    func downloadTorrent(request: DownloadRequest) async throws -> DownloadResponse {
        let url = URL(string: authManager.apiEndpoint + "/api/v1/download/")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(authManager.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        // 日志: 打印请求的 endpoint 与 body（可读 JSON）
        if let body = urlRequest.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("🔵 [APIService] POST \(url.absoluteString) - 请求体:\n\(bodyString)")
        } else {
            print("🔵 [APIService] POST \(url.absoluteString) - 请求体为空或不可序列化")
        }

        let (data, response) = try await urlSession.data(for: urlRequest)

        // 打印原始响应文本，便于排查 JSON 解析或服务器错误
        let responseText = String(data: data, encoding: .utf8) ?? "<binary-response>"
        if let httpResponse = response as? HTTPURLResponse {
            print("📗 [APIService] 响应来自 \(url.absoluteString) - status: \(httpResponse.statusCode)\n\(responseText)")
            guard (200..<300).contains(httpResponse.statusCode) else {
                print("❌ [APIService] 非2xx响应: \(httpResponse.statusCode) \n 响应体: \(responseText)")
                throw URLError(.badServerResponse)
            }
        } else {
            print("⚠️ [APIService] 未收到 HTTP 响应对象 - 原始响应: \(response)")
        }

        do {
            let result = try JSONDecoder().decode(DownloadResponse.self, from: data)
            print("✅ [APIService] downloadTorrent 解析成功: success=\(result.success), message=\(result.message ?? "nil"), download_id=\(result.data?.download_id ?? "nil")")
            return result
        } catch {
            print("❌ [APIService] 解析 downloadTorrent 响应失败: \(error). 原始响应: \(responseText)")
            throw error
        }
    }
}

// MARK: - Response Models

// MoviePilot 标准响应包装
struct MoviePilotResponse<T: Codable>: Codable {
    let success: Bool
    let message: String
    let data: T?
}

struct DownloadHistoryResponse: Codable {
    let items: [DownloadHistory]?
    let total: Int?
}

struct EmptyResponse: Codable {}

// 下载控制请求体
private struct ControlDownloadRequest: Codable {
    let name: String
    let hash: String
}

// 下载接口响应
struct DownloadResponse: Codable {
    let success: Bool
    let message: String?
    let data: DownloadData?
}

struct DownloadData: Codable {
    let download_id: String?
}

// 下载请求体
struct DownloadRequest: Codable {
    let torrent_in: TorrentIn
    let downloader: String?
    let save_path: String?
    let media_in: MediaDetail?
}

// Torrent 入参（尽量对齐服务端字段，缺失的字段保持可选）
struct TorrentIn: Codable {
    let site: Int?
    let site_name: String?
    let site_cookie: String?
    let site_ua: String?
    let site_proxy: String?
    let site_order: Int?
    let site_downloader: String?
    let title: String?
    let description: String?
    let imdbid: String?
    let enclosure: String?
    let page_url: String?
    let size: Double?
    let seeders: Int?
    let peers: Int?
    let grabs: Int?
    let pubdate: String?
    let date_elapsed: String?
    let freedate: String?
    let uploadvolumefactor: Double?
    let downloadvolumefactor: Double?
    let hit_and_run: Bool?
    let labels: [String]?
    let pri_order: Int?
    let category: String?
    let volume_factor: String?
    let freedate_diff: String?
}

// MARK: - System Status Models

struct StorageInfo: Codable {
    let totalStorage: Double      // 总存储空间（字节）
    let usedStorage: Double       // 已用存储空间（字节）
    
    enum CodingKeys: String, CodingKey {
        case totalStorage = "total_storage"
        case usedStorage = "used_storage"
    }
    
    // 计算已用百分比
    var usagePercentage: Double {
        guard totalStorage > 0 else { return 0 }
        return (usedStorage / totalStorage) * 100
    }
    
    // 格式化显示的已用空间
    var usedStorageText: String {
        return formatBytes(usedStorage)
    }
    
    // 格式化显示的总空间
    var totalStorageText: String {
        return formatBytes(totalStorage)
    }
    
    // 剩余空间
    var freeStorage: Double {
        return totalStorage - usedStorage
    }
    
    var freeStorageText: String {
        return formatBytes(freeStorage)
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = bytes
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", size, units[unitIndex])
    }
}

// 下载器速度和统计信息
struct DownloaderInfo: Codable {
    let downloadSpeed: Double      // 实时下载速度（字节/秒）
    let uploadSpeed: Double        // 实时上传速度（字节/秒）
    let downloadSize: Double       // 总下载大小（字节）
    let uploadSize: Double         // 总上传大小（字节）
    let freeSpace: Double          // 磁盘剩余空间（字节）
    
    enum CodingKeys: String, CodingKey {
        case downloadSpeed = "download_speed"
        case uploadSpeed = "upload_speed"
        case downloadSize = "download_size"
        case uploadSize = "upload_size"
        case freeSpace = "free_space"
    }
    
    // 格式化下载速度
    var downloadSpeedText: String {
        return formatSpeed(downloadSpeed)
    }
    
    // 格式化上传速度
    var uploadSpeedText: String {
        return formatSpeed(uploadSpeed)
    }
    
    // 格式化总下载大小
    var downloadSizeText: String {
        return formatBytes(downloadSize)
    }
    
    // 格式化总上传大小
    var uploadSizeText: String {
        return formatBytes(uploadSize)
    }
    
    // 格式化剩余空间
    var freeSpaceText: String {
        return formatBytes(freeSpace)
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = bytes
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", size, units[unitIndex])
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var speed = bytesPerSecond
        var unitIndex = 0
        
        while speed >= 1024 && unitIndex < units.count - 1 {
            speed /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", speed, units[unitIndex])
    }
}

// 系统状态（存储 + 下载信息）
struct SystemStatus: Codable {
    let storageInfo: StorageInfo?
    let downloaderInfo: DownloaderInfo?
    let lastUpdated: Date
}

// MARK: - Download Management API

extension APIService {
    /// 获取可用的下载器客户端列表
    func getDownloaderClients() async throws -> [DownloaderClient] {
        let endpoint = "/api/v1/download/clients"
        let request = try createRequest(endpoint: endpoint)
        return try await performRequest(request)
    }
    
    /// 根据下载器名字获取任务列表
    func getDownloadTasks(downloaderName: String) async throws -> [DownloadTask] {
        let encodedName = downloaderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? downloaderName
        let endpoint = "/api/v1/download/?name=\(encodedName)"
        var request = try createRequest(endpoint: endpoint)
        
        // 禁用缓存，确保获取最新数据
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        return try await performRequest(request)
    }

    /// 暂停/停止下载任务
    func stopDownloadTask(downloaderName: String, taskHash: String) async throws {
        let payload = ControlDownloadRequest(name: downloaderName, hash: taskHash)
        var request = try createRequest(endpoint: "/api/v1/download/stop", method: "POST")
        request.httpBody = try JSONEncoder().encode(payload)
        let _: EmptyResponse = try await performRequest(request)
    }
    
    /// 删除下载任务
    func deleteDownloadTask(downloaderName: String, taskHash: String) async throws {
        let encodedName = downloaderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? downloaderName
        let encodedHash = taskHash.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? taskHash
        let endpoint = "/api/v1/download/?name=\(encodedName)&hash=\(encodedHash)"
        let request = try createRequest(endpoint: endpoint, method: "DELETE")
        let _: EmptyResponse = try await performRequest(request)
    }
}

// MARK: - TMDB Episode Response Models

struct TMDBEpisodeDetail: Codable {
    let airDate: String?
    let episodeNumber: Int
    let episodeType: String?
    let name: String
    let overview: String?
    let runtime: Int?
    let seasonNumber: Int
    let stillPath: String?
    let voteAverage: Double?
    let crew: [TMDBCrewMember]?
    let guestStars: [TMDBCastMember]?
    
    enum CodingKeys: String, CodingKey {
        case airDate = "air_date"
        case episodeNumber = "episode_number"
        case episodeType = "episode_type"
        case name
        case overview
        case runtime
        case seasonNumber = "season_number"
        case stillPath = "still_path"
        case voteAverage = "vote_average"
        case crew
        case guestStars = "guest_stars"
    }
}

struct TMDBCrewMember: Codable {
    let job: String?
    let department: String?
    let creditId: String?
    let adult: Bool?
    let gender: Int?
    let id: Int
    let knownForDepartment: String?
    let name: String
    let originalName: String?
    let popularity: Double?
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case job
        case department
        case creditId = "credit_id"
        case adult
        case gender
        case id
        case knownForDepartment = "known_for_department"
        case name
        case originalName = "original_name"
        case popularity
        case profilePath = "profile_path"
    }
}

struct TMDBCastMember: Codable {
    let character: String?
    let creditId: String?
    let order: Int?
    let adult: Bool?
    let gender: Int?
    let id: Int
    let knownForDepartment: String?
    let name: String
    let originalName: String?
    let popularity: Double?
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case character
        case creditId = "credit_id"
        case order
        case adult
        case gender
        case id
        case knownForDepartment = "known_for_department"
        case name
        case originalName = "original_name"
        case popularity
        case profilePath = "profile_path"
    }
}

// MARK: - Media Server Not Exists API

extension APIService {
    /// 获取不存在的剧集信息（仅用于 TMDB 电视剧）
    func getNotExistsEpisodes(mediaDetail: MediaDetail) async throws -> [NotExistsResponse] {
        let endpoint = "/api/v1/mediaserver/notexists"
        var request = try createRequest(endpoint: endpoint, method: "POST")
        
        // 发送完整的 MediaDetail 作为载荷
        request.httpBody = try JSONEncoder().encode(mediaDetail)
        
        // 不使用缓存，确保获取最新数据
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        return try await performRequest(request)
    }
}

// MARK: - Not Exists Response Models

struct NotExistsResponse: Codable {
    let season: Int
    let episodes: [Int]
    let totalEpisode: Int
    let startEpisode: Int
    
    enum CodingKeys: String, CodingKey {
        case season
        case episodes
        case totalEpisode = "total_episode"
        case startEpisode = "start_episode"
    }
}
