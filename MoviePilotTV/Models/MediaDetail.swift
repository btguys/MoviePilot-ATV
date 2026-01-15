//
//  MediaDetail.swift
//  MoviePilotTV
//
//  Created on 2025-12-31.
//

import Foundation

struct MediaDetail: Codable {
    let tmdbId: Int?
    let imdbId: String?
    let doubanId: String?
    let title: String
    let originalTitle: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let releaseDate: String?
    let type: String?
    let year: String?
    let originalLanguage: String?
    let source: String?
    
    // 详情页特有字段
    let seasons: [String: [Int]]?  // 季号 -> 集数数组的映射
    let seasonInfo: [SeasonInfo]?
    let actorsData: [PersonInfo]?  // 原始演员数据
    let directorsData: [PersonInfo]?  // 原始导演数据
    let category: String?
    let genresData: [GenreInfo]?  // 原始类型数据
    
    // 计算属性：提取演员名字列表
    var actors: [String]? {
        actorsData?.compactMap { $0.name }
    }
    
    // 计算属性：提取导演名字列表
    var directors: [String]? {
        directorsData?.compactMap { $0.name }
    }
    
    // 计算属性：提取类型名字列表
    var genres: [String]? {
        genresData?.compactMap { $0.name }
    }
    
    enum CodingKeys: String, CodingKey {
        case tmdbId = "tmdb_id"
        case imdbId = "imdb_id"
        case doubanId = "douban_id"
        case title
        case originalTitle = "original_title"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case releaseDate = "release_date"
        case type
        case year
        case originalLanguage = "original_language"
        case source
        case seasons
        case seasonInfo = "season_info"
        case actorsData = "actors"
        case directorsData = "directors"
        case category
        case genresData = "genres"
    }
    
    // 自定义解码器，处理 seasons 可能是数组或字典的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 解码基本字段
        tmdbId = try container.decodeIfPresent(Int.self, forKey: .tmdbId)
        imdbId = try container.decodeIfPresent(String.self, forKey: .imdbId)
        doubanId = try container.decodeIfPresent(String.self, forKey: .doubanId)
        title = try container.decode(String.self, forKey: .title)
        originalTitle = try container.decodeIfPresent(String.self, forKey: .originalTitle)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
        voteAverage = try container.decodeIfPresent(Double.self, forKey: .voteAverage)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        year = try container.decodeIfPresent(String.self, forKey: .year)
        originalLanguage = try container.decodeIfPresent(String.self, forKey: .originalLanguage)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        actorsData = try container.decodeIfPresent([PersonInfo].self, forKey: .actorsData)
        directorsData = try container.decodeIfPresent([PersonInfo].self, forKey: .directorsData)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        
        // 处理 genres：可能是对象数组或字符串数组
        if let genresObjectArray = try? container.decode([GenreInfo].self, forKey: .genresData) {
            // 如果是对象数组格式（如：[{"id": 12, "name": "冒险"}]）
            genresData = genresObjectArray
        } else if let genresStringArray = try? container.decode([String].self, forKey: .genresData) {
            // 如果是字符串数组格式（如：["冒险", "奇幻"]）
            genresData = genresStringArray.map { GenreInfo(id: nil, name: $0) }
        } else {
            // 都解析失败，设为 nil
            genresData = nil
        }
        
        // 处理 seasons：字典格式，键是季号字符串，值是集数数组
        seasons = try? container.decode([String: [Int]].self, forKey: .seasons)
        
        // 处理 seasonInfo：数组格式
        seasonInfo = try container.decodeIfPresent([SeasonInfo].self, forKey: .seasonInfo)
        
        // 添加解码日志
        print("📊 [MediaDetail] ========== 季度数据解码 ==========")
        if let seasons = seasons {
            print("✅ [MediaDetail] seasons 解码成功，包含 \(seasons.count) 个季度")
            for (season, episodes) in seasons {
                print("   季 \(season): \(episodes.count) 集 - \(episodes)")
            }
        } else {
            print("❌ [MediaDetail] seasons 解码失败或为 nil")
        }
        
        if let seasonInfo = seasonInfo {
            print("✅ [MediaDetail] seasonInfo 解码成功，包含 \(seasonInfo.count) 条记录")
            for info in seasonInfo {
                print("   季 \(info.seasonNumber ?? 0): \(info.name ?? "N/A") - \(info.episodeCount ?? 0) 集")
            }
        } else {
            print("❌ [MediaDetail] seasonInfo 解码失败或为 nil")
        }
        print("📊 [MediaDetail] ========== 解码完成 ==========")
    }
    
    var posterURL: URL? {
        guard let posterPath = posterPath, !posterPath.isEmpty else { return nil }
        let rawURL: String
        if posterPath.hasPrefix("http") {
            rawURL = posterPath
        } else {
            rawURL = "https://image.tmdb.org/t/p/w500\(posterPath)"
        }
        return URL(string: applyImageProxyIfNeeded(rawURL))
    }
    
    var backdropURL: URL? {
        guard let backdropPath = backdropPath, !backdropPath.isEmpty else { return nil }
        let rawURL: String
        if backdropPath.hasPrefix("http") {
            rawURL = backdropPath
        } else {
            rawURL = "https://image.tmdb.org/t/p/original\(backdropPath)"
        }
        return URL(string: applyImageProxyIfNeeded(rawURL))
    }
    
    var displayTitle: String {
        if let year = year {
            return "\(title) (\(year))"
        }
        return title
    }
    
    var ratingText: String {
        guard let rating = voteAverage else { return "N/A" }
        return String(format: "%.1f", rating)
    }
}

// MARK: - Image proxy helper
private extension MediaDetail {
    func applyImageProxyIfNeeded(_ urlString: String) -> String {
        let lower = urlString.lowercased()
        let isDouban = (source?.lowercased().contains("douban") ?? false) || lower.contains("doubanio.com")
        guard isDouban else { return urlString }
        let encoded = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
        let base = UserDefaults.standard.string(forKey: "apiEndpoint")?.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")) ?? ""
        guard !base.isEmpty else { return urlString }
        return "\(base)/api/v1/system/img/0?imgurl=\(encoded)"
    }
}

struct SeasonInfo: Codable {
    let seasonNumber: Int?
    let episodeCount: Int?
    let airDate: String?
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case airDate = "air_date"
        case name
    }
}

// 搜索结果
struct SearchResult: Codable {
    let success: Bool?
    let message: String?
    let data: [SearchResultItem]?
    
    // 自定义解码以处理 data 字段可能是空字典的情况
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        
        // 尝试解码 data 字段
        // data 可能是数组 [] 或空对象 {}
        print("🔍 [SearchResult] 开始解码 data 字段")
        
        // 首先检查 data 字段是否存在
        if container.contains(.data) {
            print("   data 字段存在于响应中")
            // 尝试解码为数组
            do {
                let dataArray = try container.decode([SearchResultItem].self, forKey: .data)
                print("✅ [SearchResult] data 成功解码为数组，数量: \(dataArray.count)")
                data = dataArray
            } catch {
                // 解码失败，可能是空对象 {}
                print("⚠️ [SearchResult] 无法将 data 解码为数组，设为 nil")
                print("   异常: \(error)")
                data = nil
            }
        } else {
            // data 字段不存在
            print("   data 字段不存在于响应中")
            data = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(success, forKey: .success)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(data, forKey: .data)
    }
    
    // 兼容旧的 torrents 属性
    var torrents: [Torrent]? {
        return data?.map { item in
            Torrent(
                id: item.torrentInfo?.enclosure ?? UUID().uuidString,
                siteName: item.torrentInfo?.siteName,
                title: item.torrentInfo?.title,
                description: item.torrentInfo?.description,
                enclosure: item.torrentInfo?.enclosure,
                size: item.torrentInfo?.size,
                seeders: item.torrentInfo?.seeders,
                downloadUrl: item.torrentInfo?.enclosure,
                pubdate: item.torrentInfo?.pubdate,
                torrentInfo: item.torrentInfo,
                metaInfo: item.metaInfo
            )
        }
    }
}

// 搜索结果项
struct SearchResultItem: Codable {
    let metaInfo: MetaInfo?
    let torrentInfo: TorrentInfo?
    let mediaInfo: MediaInfo?
    
    enum CodingKeys: String, CodingKey {
        case metaInfo = "meta_info"
        case torrentInfo = "torrent_info"
        case mediaInfo = "media_info"
    }
}

// 媒体信息
struct MediaInfo: Codable {
    let source: String?
    let type: String?
    let title: String?
    let enTitle: String?
    
    enum CodingKeys: String, CodingKey {
        case source
        case type
        case title
        case enTitle = "en_title"
    }
}

struct Torrent: Codable, Identifiable {
    let id: String
    let siteName: String?
    let title: String?
    let description: String?
    let enclosure: String?
    let size: Double?
    let seeders: Int?
    let downloadUrl: String?
    let pubdate: String?
    let torrentInfo: TorrentInfo?
    let metaInfo: MetaInfo?
    
    // 自定义初始化器
    init(id: String, siteName: String?, title: String?, description: String?, enclosure: String?, size: Double?, seeders: Int?, downloadUrl: String?, pubdate: String?, torrentInfo: TorrentInfo?, metaInfo: MetaInfo?) {
        self.id = id
        self.siteName = siteName
        self.title = title
        self.description = description
        self.enclosure = enclosure
        self.size = size
        self.seeders = seeders
        self.downloadUrl = downloadUrl
        self.pubdate = pubdate
        self.torrentInfo = torrentInfo
        self.metaInfo = metaInfo
    }
    
    // 自定义解码，确保 id 非空
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 如果 API 返回的 id 为空，使用 enclosure 或 title 作为备用
        if let apiId = try container.decodeIfPresent(String.self, forKey: .id), !apiId.isEmpty {
            self.id = apiId
        } else if let enclosure = try container.decodeIfPresent(String.self, forKey: .enclosure), !enclosure.isEmpty {
            self.id = enclosure
        } else if let title = try container.decodeIfPresent(String.self, forKey: .title), !title.isEmpty {
            self.id = UUID().uuidString + "_" + title
        } else {
            self.id = UUID().uuidString
        }
        
        self.siteName = try container.decodeIfPresent(String.self, forKey: .siteName)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.enclosure = try container.decodeIfPresent(String.self, forKey: .enclosure)
        self.size = try container.decodeIfPresent(Double.self, forKey: .size)
        self.seeders = try container.decodeIfPresent(Int.self, forKey: .seeders)
        self.downloadUrl = try container.decodeIfPresent(String.self, forKey: .downloadUrl)
        self.pubdate = try container.decodeIfPresent(String.self, forKey: .pubdate)
        self.torrentInfo = try container.decodeIfPresent(TorrentInfo.self, forKey: .torrentInfo)
        self.metaInfo = try container.decodeIfPresent(MetaInfo.self, forKey: .metaInfo)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case siteName = "site_name"
        case title
        case description
        case enclosure
        case size
        case seeders
        case downloadUrl = "download_url"
        case pubdate
        case torrentInfo = "torrent_info"
        case metaInfo = "meta_info"
    }
    
    var sizeText: String {
        guard let size = size else { return "N/A" }
        let gb = size / (1024 * 1024 * 1024)
        return String(format: "%.2f GB", gb)
    }
}

// 人物信息（演员、导演等）
struct PersonInfo: Codable {
    let id: String?  // 使用字符串以兼容 TMDB（整数）和 Douban（字符串）
    let name: String?
    let originalName: String?
    let character: String?  // 角色名（演员）
    let job: String?  // 职位（导演等）
    let profilePath: String?
    let avatar: AvatarInfo?
    
    // 自定义解码器，处理 id 可能是 Int 或 String 的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 尝试解码 id - 可能是 Int 或 String
        if let intId = try? container.decode(Int.self, forKey: .id) {
            self.id = String(intId)
        } else if let stringId = try? container.decode(String.self, forKey: .id) {
            self.id = stringId
        } else {
            self.id = nil
        }
        
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.originalName = try container.decodeIfPresent(String.self, forKey: .originalName)
        self.character = try container.decodeIfPresent(String.self, forKey: .character)
        self.job = try container.decodeIfPresent(String.self, forKey: .job)
        self.profilePath = try container.decodeIfPresent(String.self, forKey: .profilePath)
        self.avatar = try container.decodeIfPresent(AvatarInfo.self, forKey: .avatar)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case originalName = "original_name"
        case character
        case job
        case profilePath = "profile_path"
        case avatar
    }
    
    var profileURL: URL? {
        if let path = profilePath, !path.isEmpty {
            if path.hasPrefix("http") {
                return URL(string: path)
            }
            return URL(string: "https://image.tmdb.org/t/p/w185\(path)")
        }
        if let large = avatar?.large, !large.isEmpty {
            return URL(string: large)
        }
        if let normal = avatar?.normal, !normal.isEmpty {
            return URL(string: normal)
        }
        return nil
    }
}

struct AvatarInfo: Codable {
    let large: String?
    let normal: String?
}

// 类型信息（电影/电视剧类型）
struct GenreInfo: Codable {
    let id: Int?
    let name: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
    }
}

// Torrent 详细信息
struct TorrentInfo: Codable {
    let siteName: String?
    let seeders: Int?
    let peers: Int?
    let size: Double?
    let enclosure: String?      // 下载链接
    let pubdate: String?        // 发布时间
    let title: String?          // 标题
    let description: String?    // 描述
    let label: [String]?        // 额外标签
    
    enum CodingKeys: String, CodingKey {
        case siteName = "site_name"
        case seeders
        case peers
        case size
        case enclosure
        case pubdate
        case title
        case description
        case label
        case labels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        siteName = try container.decodeIfPresent(String.self, forKey: .siteName)
        seeders = try container.decodeIfPresent(Int.self, forKey: .seeders)
        peers = try container.decodeIfPresent(Int.self, forKey: .peers)
        size = try container.decodeIfPresent(Double.self, forKey: .size)
        enclosure = try container.decodeIfPresent(String.self, forKey: .enclosure)
        pubdate = try container.decodeIfPresent(String.self, forKey: .pubdate)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)

        if let labels = try? container.decodeIfPresent([String].self, forKey: .label) {
            label = labels
        } else if let multi = try? container.decodeIfPresent([String].self, forKey: .labels) {
            label = multi
        } else if let single = try? container.decodeIfPresent(String.self, forKey: .label) {
            label = [single]
        } else if let single2 = try? container.decodeIfPresent(String.self, forKey: .labels) {
            label = [single2]
        } else {
            label = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(siteName, forKey: .siteName)
        try container.encodeIfPresent(seeders, forKey: .seeders)
        try container.encodeIfPresent(peers, forKey: .peers)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(enclosure, forKey: .enclosure)
        try container.encodeIfPresent(pubdate, forKey: .pubdate)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        // 同步写入 label/labels，方便与不同接口键兼容
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(label, forKey: .labels)
    }
}

// 元信息（包含各种标签）
struct MetaInfo: Codable {
    let resourcePix: String?           // 分辨率，如 "2160p"
    let videoEncode: String?           // 视频编码，如 "H265"
    let audioEncode: String?           // 音频编码，如 "DDP 5.1 Atmos"
    let resourceEffect: String?        // 特效，如 "DV HDR"
    let edition: String?               // 版本，如 "WEB-DL DV HDR"
    let resourceType: String?          // 资源类型
    
    enum CodingKeys: String, CodingKey {
        case resourcePix = "resource_pix"
        case videoEncode = "video_encode"
        case audioEncode = "audio_encode"
        case resourceEffect = "resource_effect"
        case edition
        case resourceType = "resource_type"
    }
}
