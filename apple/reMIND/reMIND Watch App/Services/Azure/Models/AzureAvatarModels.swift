//
//  AzureAvatarModels.swift
//  reMIND Watch App
//
//  Avatar and animation configuration models from Azure Voice Live API specification
//

import Foundation

// MARK: - Animation Configuration

struct RealtimeAnimation: Codable, Sendable {
    let modelName: String?
    let outputs: [RealtimeAnimationOutputType]?

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case outputs
    }

    init(
        modelName: String? = nil,
        outputs: [RealtimeAnimationOutputType]? = nil
    ) {
        self.modelName = modelName
        self.outputs = outputs
    }
}

// MARK: - Avatar Configuration

struct RealtimeAvatarConfig: Codable, Sendable {
    let iceServers: [RealtimeIceServer]?
    let character: String
    let style: String?
    let customized: Bool
    let video: RealtimeVideoParams?

    enum CodingKeys: String, CodingKey {
        case iceServers = "ice_servers"
        case character
        case style
        case customized
        case video
    }

    init(
        iceServers: [RealtimeIceServer]? = nil,
        character: String,
        style: String? = nil,
        customized: Bool,
        video: RealtimeVideoParams? = nil
    ) {
        self.iceServers = iceServers
        self.character = character
        self.style = style
        self.customized = customized
        self.video = video
    }
}

// MARK: - ICE Server

struct RealtimeIceServer: Codable, Sendable {
    let urls: [String]
    let username: String?
    let credential: String?

    enum CodingKeys: String, CodingKey {
        case urls
        case username
        case credential
    }

    init(
        urls: [String],
        username: String? = nil,
        credential: String? = nil
    ) {
        self.urls = urls
        self.username = username
        self.credential = credential
    }
}

// MARK: - Video Parameters

struct RealtimeVideoParams: Codable, Sendable {
    let bitrate: Int?
    let codec: String?
    let crop: RealtimeVideoCrop?
    let resolution: RealtimeVideoResolution?

    enum CodingKeys: String, CodingKey {
        case bitrate
        case codec
        case crop
        case resolution
    }

    init(
        bitrate: Int? = nil,
        codec: String? = nil,
        crop: RealtimeVideoCrop? = nil,
        resolution: RealtimeVideoResolution? = nil
    ) {
        self.bitrate = bitrate
        self.codec = codec
        self.crop = crop
        self.resolution = resolution
    }
}

// MARK: - Video Crop

struct RealtimeVideoCrop: Codable, Sendable {
    let topLeft: [Int]
    let bottomRight: [Int]

    enum CodingKeys: String, CodingKey {
        case topLeft = "top_left"
        case bottomRight = "bottom_right"
    }

    init(topLeft: [Int], bottomRight: [Int]) {
        self.topLeft = topLeft
        self.bottomRight = bottomRight
    }
}

// MARK: - Video Resolution

struct RealtimeVideoResolution: Codable, Sendable {
    let width: Int
    let height: Int

    enum CodingKeys: String, CodingKey {
        case width
        case height
    }

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}
