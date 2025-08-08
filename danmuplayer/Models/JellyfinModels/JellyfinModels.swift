/// Jellyfin数据模型
import Foundation

/// Jellyfin用户信息
struct JellyfinUser: Codable {
    let id: String
    let name: String
    let serverId: String
    let hasPassword: Bool
    let hasConfiguredPassword: Bool
    let hasConfiguredEasyPassword: Bool
    let enableAutoLogin: Bool?
    let lastLoginDate: String?
    let lastActivityDate: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case hasPassword = "HasPassword"
        case hasConfiguredPassword = "HasConfiguredPassword"
        case hasConfiguredEasyPassword = "HasConfiguredEasyPassword"
        case enableAutoLogin = "EnableAutoLogin"
        case lastLoginDate = "LastLoginDate"
        case lastActivityDate = "LastActivityDate"
    }
}

/// Jellyfin认证响应
struct JellyfinAuthResponse: Codable {
    let user: JellyfinUser
    let sessionInfo: JellyfinSessionInfo?
    let accessToken: String
    let serverId: String
    
    enum CodingKeys: String, CodingKey {
        case user = "User"
        case sessionInfo = "SessionInfo"
        case accessToken = "AccessToken"
        case serverId = "ServerId"
    }
}

/// Jellyfin会话信息
struct JellyfinSessionInfo: Codable {
    let playState: JellyfinPlayState?
    let remoteEndPoint: String?
    let playableMediaTypes: [String]
    let id: String
    let userId: String
    let userName: String
    let client: String
    let lastActivityDate: String
    let lastPlaybackCheckIn: String?
    let deviceName: String
    let deviceType: String?
    let nowPlayingItem: JellyfinMediaItem?
    let deviceId: String
    let applicationVersion: String
    let isActive: Bool
    let supportsMediaControl: Bool
    let supportsRemoteControl: Bool
    let hasCustomDeviceName: Bool
    let serverId: String
    let supportedCommands: [String]
    
    enum CodingKeys: String, CodingKey {
        case playState = "PlayState"
        case remoteEndPoint = "RemoteEndPoint"
        case playableMediaTypes = "PlayableMediaTypes"
        case id = "Id"
        case userId = "UserId"
        case userName = "UserName"
        case client = "Client"
        case lastActivityDate = "LastActivityDate"
        case lastPlaybackCheckIn = "LastPlaybackCheckIn"
        case deviceName = "DeviceName"
        case deviceType = "DeviceType"
        case nowPlayingItem = "NowPlayingItem"
        case deviceId = "DeviceId"
        case applicationVersion = "ApplicationVersion"
        case isActive = "IsActive"
        case supportsMediaControl = "SupportsMediaControl"
        case supportsRemoteControl = "SupportsRemoteControl"
        case hasCustomDeviceName = "HasCustomDeviceName"
        case serverId = "ServerId"
        case supportedCommands = "SupportedCommands"
    }
}

/// Jellyfin播放状态
struct JellyfinPlayState: Codable {
    let canSeek: Bool
    let isPaused: Bool
    let isMuted: Bool
    let repeatMode: String
    let positionTicks: Int64?
    let playbackStartTimeTicks: Int64?
    
    enum CodingKeys: String, CodingKey {
        case canSeek = "CanSeek"
        case isPaused = "IsPaused"
        case isMuted = "IsMuted"
        case repeatMode = "RepeatMode"
        case positionTicks = "PositionTicks"
        case playbackStartTimeTicks = "PlaybackStartTimeTicks"
    }
}

/// Jellyfin媒体库
struct JellyfinLibrary: Codable, Identifiable {
    let id: String
    let name: String
    let serverId: String
    let etag: String?
    let dateCreated: String?
    let canDelete: Bool?
    let canDownload: Bool?
    let sortName: String?
    let collectionType: String?
    let type: String
    let locationType: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case etag = "Etag"
        case dateCreated = "DateCreated"
        case canDelete = "CanDelete"
        case canDownload = "CanDownload"
        case sortName = "SortName"
        case collectionType = "CollectionType"
        case type = "Type"
        case locationType = "LocationType"
    }
}

/// Jellyfin媒体项目
struct JellyfinMediaItem: Codable, Identifiable {
    let id: String
    let name: String
    let serverId: String
    let etag: String?
    let dateCreated: String?
    let canDelete: Bool?
    let canDownload: Bool?
    let sortName: String?
    let type: String
    let locationType: String?
    let userData: JellyfinUserData?
    let productionYear: Int?
    let status: String?
    let endDate: String?
    let overview: String?
    let communityRating: Double?
    let officialRating: String?
    let runTimeTicks: Int64?
    let genres: [String]?
    let tags: [String]?
    let imageTags: [String: String]?
    let seriesName: String?
    let seriesId: String?
    let seasonId: String?
    let seasonName: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let primaryImageAspectRatio: Double?
    
    // 计算属性
    var posterImageUrl: String? {
        return imageTags?["Primary"]
    }
    
    var backdropImageUrl: String? {
        return imageTags?["Backdrop"]
    }
    
    var duration: TimeInterval? {
        guard let runTimeTicks = runTimeTicks else { return nil }
        return TimeInterval(runTimeTicks / 10_000_000) // Ticks转秒
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverId = "ServerId"
        case etag = "Etag"
        case dateCreated = "DateCreated"
        case canDelete = "CanDelete"
        case canDownload = "CanDownload"
        case sortName = "SortName"
        case type = "Type"
        case locationType = "LocationType"
        case userData = "UserData"
        case productionYear = "ProductionYear"
        case status = "Status"
        case endDate = "EndDate"
        case overview = "Overview"
        case communityRating = "CommunityRating"
        case officialRating = "OfficialRating"
        case runTimeTicks = "RunTimeTicks"
        case genres = "Genres"
        case tags = "Tags"
        case imageTags = "ImageTags"
        case seriesName = "SeriesName"
        case seriesId = "SeriesId"
        case seasonId = "SeasonId"
        case seasonName = "SeasonName"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case primaryImageAspectRatio = "PrimaryImageAspectRatio"
    }
}

/// Jellyfin用户数据（观看进度等）
struct JellyfinUserData: Codable {
    let rating: Double?
    let playedPercentage: Double?
    let unplayedItemCount: Int?
    let playbackPositionTicks: Int64?
    let playCount: Int
    let isFavorite: Bool
    let played: Bool
    let key: String?
    
    enum CodingKeys: String, CodingKey {
        case rating = "Rating"
        case playedPercentage = "PlayedPercentage"
        case unplayedItemCount = "UnplayedItemCount"
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
        case isFavorite = "IsFavorite"
        case played = "Played"
        case key = "Key"
    }
}

/// Jellyfin剧集
typealias JellyfinEpisode = JellyfinMediaItem

/// Jellyfin字幕轨道信息
struct JellyfinSubtitleTrack: Codable {
    let index: Int
    let language: String?
    let displayTitle: String?
    let codec: String?
    let isDefault: Bool
    let isForced: Bool
    let isExternal: Bool
    let deliveryUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case index = "Index"
        case language = "Language"
        case displayTitle = "DisplayTitle"
        case codec = "Codec"
        case isDefault = "IsDefault"
        case isForced = "IsForced"
        case isExternal = "IsExternal"
        case deliveryUrl = "DeliveryUrl"
    }
}

/// Jellyfin响应包装器
struct JellyfinItemsResponse<T: Codable>: Codable {
    let items: [T]
    let totalRecordCount: Int
    let startIndex: Int
    
    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
        case startIndex = "StartIndex"
    }
}
