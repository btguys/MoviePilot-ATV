//
//  UserInfo.swift
//  MoviePilotTV
//
//  Created on 2025-12-31.
//

import Foundation

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
