//
//  Credits.swift
//  MoviePilotTV
//
//  Created on 2025-12-31.
//

import Foundation

// 演职人员信息响应
struct CreditsResponse: Codable {
    let cast: [CastMember]?      // 演员列表
    let crew: [CrewMember]?      // 制作人员列表
    
    // 自定义解码器 - 支持数组或字典格式
    init(from decoder: Decoder) throws {
        // 尝试解码为数组（API 可能直接返回 cast 数组）
        if let castArray = try? decoder.singleValueContainer().decode([CastMember].self) {
            self.cast = castArray
            self.crew = nil
            return
        }
        
        // 尝试解码为字典（标准格式）
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.cast = try container.decodeIfPresent([CastMember].self, forKey: .cast)
        self.crew = try container.decodeIfPresent([CrewMember].self, forKey: .crew)
    }
    
    enum CodingKeys: String, CodingKey {
        case cast
        case crew
    }
}

// 演员信息
struct CastMember: Codable, Identifiable {
    let id: Int
    let name: String
    let originalName: String?
    let character: String?       // 扮演的角色
    let profilePath: String?     // 头像路径（TMDB）
    let avatar: Avatar?          // 头像对象（豆瓣）
    let order: Int?              // 演员顺序
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case originalName = "original_name"
        case character
        case profilePath = "profile_path"
        case avatar
        case order
    }
    
    // 头像 URL - 优先使用豆瓣 avatar，其次使用 TMDB profilePath
    var profileURL: URL? {
        // 优先使用豆瓣的 avatar.large
        if let avatarURL = avatar?.large ?? avatar?.normal {
            return URL(string: avatarURL)
        }
        
        // 回退到 TMDB profilePath
        guard let profilePath = profilePath, !profilePath.isEmpty else { return nil }
        if profilePath.hasPrefix("http") {
            return URL(string: profilePath)
        }
        return URL(string: "https://image.tmdb.org/t/p/w600_and_h900_bestv2\(profilePath)")
    }
}

// 豆瓣头像对象
struct Avatar: Codable {
    let large: String?
    let normal: String?
}

// 制作人员信息
struct CrewMember: Codable, Identifiable {
    let id: Int
    let name: String
    let originalName: String?
    let job: String?             // 职位（导演、编剧等）
    let department: String?      // 部门
    let profilePath: String?     // 头像路径（TMDB）
    let avatar: Avatar?          // 头像对象（豆瓣）
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case originalName = "original_name"
        case job
        case department
        case profilePath = "profile_path"
        case avatar
    }
    
    // 头像 URL - 优先使用豆瓣 avatar，其次使用 TMDB profilePath
    var profileURL: URL? {
        // 优先使用豆瓣的 avatar.large
        if let avatarURL = avatar?.large ?? avatar?.normal {
            return URL(string: avatarURL)
        }
        
        // 回退到 TMDB profilePath
        guard let profilePath = profilePath, !profilePath.isEmpty else { return nil }
        if profilePath.hasPrefix("http") {
            return URL(string: profilePath)
        }
        return URL(string: "https://image.tmdb.org/t/p/w600_and_h900_bestv2\(profilePath)")
    }
}
