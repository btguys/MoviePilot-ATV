//
//  TMDBEpisode.swift
//  MoviePilotTV
//
//  Created on 2026-01-15.
//

import Foundation

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
