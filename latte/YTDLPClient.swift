//
//  YTDLPClient.swift
//  latte
//
//  Created on 22/05/2026.
//

import Foundation
import Combine
import AppKit
import SwiftUI

// MARK: - Enums

enum SetupState: Equatable {
    case checking
    case installing
    case error
    case ready
}

enum DownloadType: String, CaseIterable, Identifiable {
    case video = "video"
    case audio = "audio"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .video: return "Video"
        case .audio: return "Audio"
        }
    }
}

enum BrowserCookie: String, CaseIterable, Identifiable {
    case none = "none"
    case chrome = "chrome"
    case firefox = "firefox"
    case edge = "edge"
    case brave = "brave"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .none: return "None"
        case .chrome: return "Chrome"
        case .firefox: return "Firefox"
        case .edge: return "Edge"
        case .brave: return "Brave"
        }
    }
}

struct VideoFormatOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let formatSpec: String
    let mergeFormat: String?

    static let allOptions: [VideoFormatOption] = [
        VideoFormatOption(id: "best_mp4", displayName: "Best Quality (MP4)", formatSpec: "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/b", mergeFormat: "mp4"),
        VideoFormatOption(id: "best", displayName: "Best Quality (MKV)", formatSpec: "bv*+ba/b", mergeFormat: "mkv"),
        VideoFormatOption(id: "4k_mp4", displayName: "4K (MP4)", formatSpec: "bv*[height<=2160][ext=mp4]+ba[ext=m4a]/b[height<=2160][ext=mp4]/bv*[height<=2160]+ba/b[height<=2160]", mergeFormat: "mp4"),
        VideoFormatOption(id: "4k_av1", displayName: "4K (AV1/MKV)", formatSpec: "bv*[height<=2160][vcodec~='^av01']+ba/b[height<=2160]", mergeFormat: "mkv"),
        VideoFormatOption(id: "4k_webm", displayName: "4K (WebM)", formatSpec: "bv*[height<=2160][ext=webm]+ba/b[height<=2160]", mergeFormat: "webm"),
        VideoFormatOption(id: "1440p_mp4", displayName: "1440p (MP4)", formatSpec: "bv*[height<=1440][ext=mp4]+ba[ext=m4a]/b[height<=1440][ext=mp4]/bv*[height<=1440]+ba/b[height<=1440]", mergeFormat: "mp4"),
        VideoFormatOption(id: "1080p_mp4", displayName: "1080p (MP4)", formatSpec: "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/b[height<=1080][ext=mp4]/bv*[height<=1080]+ba/b[height<=1080]", mergeFormat: "mp4"),
        VideoFormatOption(id: "1080p_av1", displayName: "1080p (AV1/MKV)", formatSpec: "bv*[height<=1080][vcodec~='^av01']+ba/b[height<=1080]", mergeFormat: "mkv"),
        VideoFormatOption(id: "1080p_webm", displayName: "1080p (WebM)", formatSpec: "bv*[height<=1080][ext=webm]+ba/b[height<=1080]", mergeFormat: "webm"),
        VideoFormatOption(id: "720p_mp4", displayName: "720p (MP4)", formatSpec: "bv*[height<=720][ext=mp4]+ba[ext=m4a]/b[height<=720][ext=mp4]/bv*[height<=720]+ba/b[height<=720]", mergeFormat: "mp4"),
        VideoFormatOption(id: "480p_mp4", displayName: "480p (MP4)", formatSpec: "bv*[height<=480][ext=mp4]+ba[ext=m4a]/b[height<=480][ext=mp4]/bv*[height<=480]+ba/b[height<=480]", mergeFormat: "mp4"),
        VideoFormatOption(id: "360p_mp4", displayName: "360p (MP4)", formatSpec: "bv*[height<=360][ext=mp4]+ba[ext=m4a]/b[height<=360][ext=mp4]/bv*[height<=360]+ba/b[height<=360]", mergeFormat: "mp4")
    ]

    static func option(for id: String) -> VideoFormatOption {
        allOptions.first { $0.id == id } ?? allOptions[0]
    }
}

struct AudioFormatOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let formatSpec: String
    let audioFormat: String
    let audioQuality: String

    static let allOptions: [AudioFormatOption] = [
        AudioFormatOption(id: "best_audio", displayName: "Best Audio", formatSpec: "ba/b", audioFormat: "best", audioQuality: "0"),
        AudioFormatOption(id: "mp3_320", displayName: "MP3 (320k)", formatSpec: "ba/b", audioFormat: "mp3", audioQuality: "320K"),
        AudioFormatOption(id: "mp3_256", displayName: "MP3 (256k)", formatSpec: "ba/b", audioFormat: "mp3", audioQuality: "256K"),
        AudioFormatOption(id: "mp3_128", displayName: "MP3 (128k)", formatSpec: "ba/b", audioFormat: "mp3", audioQuality: "128K"),
        AudioFormatOption(id: "m4a_best", displayName: "M4A (AAC)", formatSpec: "ba[ext=m4a]/ba/b", audioFormat: "m4a", audioQuality: "0"),
        AudioFormatOption(id: "alac", displayName: "ALAC", formatSpec: "ba/b", audioFormat: "alac", audioQuality: "0"),
        AudioFormatOption(id: "flac", displayName: "FLAC", formatSpec: "ba/b", audioFormat: "flac", audioQuality: "0"),
        AudioFormatOption(id: "opus_best", displayName: "OPUS", formatSpec: "ba[ext=webm]/ba/b", audioFormat: "opus", audioQuality: "0"),
        AudioFormatOption(id: "vorbis", displayName: "Vorbis (Ogg)", formatSpec: "ba/b", audioFormat: "vorbis", audioQuality: "0"),
        AudioFormatOption(id: "wav", displayName: "WAV", formatSpec: "ba/b", audioFormat: "wav", audioQuality: "0")
    ]

    static func option(for id: String) -> AudioFormatOption {
        allOptions.first { $0.id == id } ?? allOptions[0]
    }
}

// MARK: - Video Entry

struct VideoEntry: Identifiable, Sendable {
    let id = UUID()
    let url: String
    let title: String
    let thumbnailURL: String?
    let duration: Int?
    var isSelected: Bool = true
}

// MARK: - YTDLPClient

@MainActor
class YTDLPClient: ObservableObject {
    @Published var appTheme: AppTheme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "Rare Jade") ?? .rareJade {
        didSet { UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme") }
    }
    
    @Published var urlText: String = ""
    @Published var isMultipleLinks: Bool = UserDefaults.standard.bool(forKey: "isMultipleLinks") {
        didSet { UserDefaults.standard.set(isMultipleLinks, forKey: "isMultipleLinks") }
    }
    @Published var downloadType: DownloadType = DownloadType(rawValue: UserDefaults.standard.string(forKey: "downloadType") ?? "video") ?? .video {
        didSet { UserDefaults.standard.set(downloadType.rawValue, forKey: "downloadType") }
    }
    
    @Published var browserCookies: BrowserCookie = BrowserCookie(rawValue: UserDefaults.standard.string(forKey: "browserCookies") ?? "none") ?? .none {
        didSet { UserDefaults.standard.set(browserCookies.rawValue, forKey: "browserCookies") }
    }
    
    @Published var videoFormatOrder: [String] = UserDefaults.standard.stringArray(forKey: "videoFormatOrder") ?? VideoFormatOption.allOptions.map(\.id) {
        didSet { UserDefaults.standard.set(videoFormatOrder, forKey: "videoFormatOrder") }
    }
    @Published var audioFormatOrder: [String] = UserDefaults.standard.stringArray(forKey: "audioFormatOrder") ?? AudioFormatOption.allOptions.map(\.id) {
        didSet { UserDefaults.standard.set(audioFormatOrder, forKey: "audioFormatOrder") }
    }
    
    @Published var hiddenVideoFormats: [String] = UserDefaults.standard.stringArray(forKey: "hiddenVideoFormats") ?? [] {
        didSet {
            UserDefaults.standard.set(hiddenVideoFormats, forKey: "hiddenVideoFormats")
            if !activeVideoFormats.contains(where: { $0.id == selectedVideoFormatId }), let first = activeVideoFormats.first {
                selectedVideoFormatId = first.id
            }
        }
    }
    @Published var hiddenAudioFormats: [String] = UserDefaults.standard.stringArray(forKey: "hiddenAudioFormats") ?? [] {
        didSet {
            UserDefaults.standard.set(hiddenAudioFormats, forKey: "hiddenAudioFormats")
            if !activeAudioFormats.contains(where: { $0.id == selectedAudioFormatId }), let first = activeAudioFormats.first {
                selectedAudioFormatId = first.id
            }
        }
    }
    
    var orderedVideoFormats: [VideoFormatOption] {
        videoFormatOrder.compactMap { id in VideoFormatOption.allOptions.first(where: { $0.id == id }) }
    }
    var orderedAudioFormats: [AudioFormatOption] {
        audioFormatOrder.compactMap { id in AudioFormatOption.allOptions.first(where: { $0.id == id }) }
    }
    
    var activeVideoFormats: [VideoFormatOption] {
        let active = orderedVideoFormats.filter { !hiddenVideoFormats.contains($0.id) }
        return active.isEmpty ? orderedVideoFormats : active
    }
    
    var activeAudioFormats: [AudioFormatOption] {
        let active = orderedAudioFormats.filter { !hiddenAudioFormats.contains($0.id) }
        return active.isEmpty ? orderedAudioFormats : active
    }
    
    @Published var selectedVideoFormatId: String = UserDefaults.standard.string(forKey: "selectedVideoFormatId") ?? VideoFormatOption.allOptions[0].id {
        didSet { UserDefaults.standard.set(selectedVideoFormatId, forKey: "selectedVideoFormatId") }
    }
    @Published var selectedAudioFormatId: String = UserDefaults.standard.string(forKey: "selectedAudioFormatId") ?? AudioFormatOption.allOptions[0].id {
        didSet { UserDefaults.standard.set(selectedAudioFormatId, forKey: "selectedAudioFormatId") }
    }

    @Published var setupState: SetupState = .checking
    @Published var setupProgressText: String = "Checking environment…"

    @Published var isFetchingInfo: Bool = false
    @Published var isPlaylist: Bool = false
    @Published var playlistTitle: String = ""
    @Published var videoEntries: [VideoEntry] = []
    @Published var hasVideoInfo: Bool = false
    @Published var singleVideoTitle: String = ""
    @Published var singleVideoThumbnail: String? = nil
    @Published var singleVideoUploader: String? = nil
    @Published var singleVideoDuration: Int? = nil
    @Published var infoError: String? = nil

    @Published var isDownloading: Bool = false
    @Published var downloadPercent: Double = 0.0
    @Published var downloadProgressText: String = ""
    @Published var downloadError: String? = nil
    @Published var downloadCompleted: Bool = false

    @Published var downloadFolder: String = UserDefaults.standard.string(forKey: "downloadFolder") ?? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (home as NSString).appendingPathComponent("Downloads")
    }() {
        didSet { UserDefaults.standard.set(downloadFolder, forKey: "downloadFolder") }
    }

    @Published var embedThumbnail: Bool = {
        let key = "embedThumbnail"
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        return UserDefaults.standard.bool(forKey: key)
    }() {
        didSet { UserDefaults.standard.set(embedThumbnail, forKey: "embedThumbnail") }
    }

    @Published var embedMetadata: Bool = {
        let key = "embedMetadata"
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(true, forKey: key)
        }
        return UserDefaults.standard.bool(forKey: key)
    }() {
        didSet { UserDefaults.standard.set(embedMetadata, forKey: "embedMetadata") }
    }

    @Published var writeSubtitles: Bool = UserDefaults.standard.bool(forKey: "writeSubtitles") {
        didSet { UserDefaults.standard.set(writeSubtitles, forKey: "writeSubtitles") }
    }

    @Published var keepPanelOpen: Bool = UserDefaults.standard.bool(forKey: "keepPanelOpen") {
        didSet { UserDefaults.standard.set(keepPanelOpen, forKey: "keepPanelOpen") }
    }

    @Published var isWindowMovable: Bool = UserDefaults.standard.bool(forKey: "isWindowMovable") {
        didSet {
            UserDefaults.standard.set(isWindowMovable, forKey: "isWindowMovable")
            NotificationCenter.default.post(name: .windowMovableChanged, object: nil, userInfo: ["value": isWindowMovable])
        }
    }

    @Published var menuBarIcon: String = UserDefaults.standard.string(forKey: "menuBarIcon") ?? "arrow.down.circle.fill" {
        didSet {
            UserDefaults.standard.set(menuBarIcon, forKey: "menuBarIcon")
            NotificationCenter.default.post(name: .menuBarIconChanged, object: nil, userInfo: ["icon": menuBarIcon])
        }
    }

    @Published var ffmpegAvailable: Bool = false

    private var activeDownloadTask: Task<Void, Never>? = nil
    private var currentDownloadProcess: Process? = nil
    private var fetchDebounceTask: Task<Void, Never>? = nil

    let latteDirectory: URL
    let ytdlpPath: URL

    var downloadsDirectory: URL {
        URL(fileURLWithPath: downloadFolder)
    }

    var hasValidURL: Bool {
        let urls = extractURLs()
        return !urls.isEmpty
    }

    init() {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        latteDirectory = homeDirectory.appendingPathComponent(".latte")
        ytdlpPath = latteDirectory.appendingPathComponent("yt-dlp")
        
        let validVideoIds = Set(VideoFormatOption.allOptions.map(\.id))
        videoFormatOrder = videoFormatOrder.filter { validVideoIds.contains($0) }
        
        let validAudioIds = Set(AudioFormatOption.allOptions.map(\.id))
        audioFormatOrder = audioFormatOrder.filter { validAudioIds.contains($0) }
        
        let missingVideoIds = VideoFormatOption.allOptions.map(\.id).filter { !validVideoIds.intersection(Set(videoFormatOrder)).contains($0) }
        if !missingVideoIds.isEmpty { videoFormatOrder.append(contentsOf: missingVideoIds) }

        let missingAudioIds = AudioFormatOption.allOptions.map(\.id).filter { !validAudioIds.intersection(Set(audioFormatOrder)).contains($0) }
        if !missingAudioIds.isEmpty { audioFormatOrder.append(contentsOf: missingAudioIds) }

        if !activeVideoFormats.contains(where: { $0.id == selectedVideoFormatId }) {
            selectedVideoFormatId = activeVideoFormats.first?.id ?? VideoFormatOption.allOptions[0].id
        }
        if !activeAudioFormats.contains(where: { $0.id == selectedAudioFormatId }) {
            selectedAudioFormatId = activeAudioFormats.first?.id ?? AudioFormatOption.allOptions[0].id
        }

        createDirectoryIfNeeded()

        let fm = FileManager.default
        if fm.isExecutableFile(atPath: ytdlpPath.path) {
            setupState = .ready
            setupProgressText = "Ready"
        } else {
            setupState = .checking
            setupProgressText = "Checking environment…"
        }

        checkFfmpegAsync()
        runSetupScript()

        NotificationCenter.default.post(name: .windowMovableChanged, object: nil, userInfo: ["value": isWindowMovable])
    }

    nonisolated func createDirectoryIfNeeded() {
        let fm = FileManager.default
        for folder in ["Downloads", "Cache", "Config"] {
            let url = latteDirectory.appendingPathComponent(folder)
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }

    private func checkFfmpegAsync() {
        Task.detached {
            let possiblePaths = [
                "/opt/homebrew/bin/ffmpeg",
                "/usr/local/bin/ffmpeg",
                "/usr/bin/ffmpeg",
                "/bin/ffmpeg"
            ]

            for path in possiblePaths {
                if FileManager.default.isExecutableFile(atPath: path) {
                    await MainActor.run { self.ffmpegAvailable = true }
                    return
                }
            }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = ["-c", "command -v ffmpeg"]
            
            let ffmpegPipe = Pipe()
            task.standardOutput = ffmpegPipe
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                task.waitUntilExit()
                let output = String(data: ffmpegPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let found = !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                await MainActor.run { self.ffmpegAvailable = found }
            } catch {
                await MainActor.run { self.ffmpegAvailable = false }
            }
        }
    }

    func runSetupScript() {
        Task.detached {
            let fm = FileManager.default
            let ytdlpFile = self.ytdlpPath.path

            if fm.isExecutableFile(atPath: ytdlpFile) {
                await MainActor.run { self.setupState = .ready; self.setupProgressText = "Ready" }
                return
            }

            await MainActor.run {
                self.setupState = .installing
                self.setupProgressText = "Installing fast backend (yt-dlp)…"
            }

            let installTask = Process()
            installTask.executableURL = URL(fileURLWithPath: "/bin/bash")
            
            let script = """
            mkdir -p "\(self.latteDirectory.path)"
            cd "\(self.latteDirectory.path)"
            curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos -o yt-dlp 2>/dev/null
            chmod a+x yt-dlp
            ./yt-dlp --version
            """
            installTask.arguments = ["-c", script]

            let setupPipe = Pipe()
            installTask.standardOutput = setupPipe
            installTask.standardError = setupPipe

            setupPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.count > 0, let str = String(data: data, encoding: .utf8) {
                    let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    if let last = lines.last {
                        Task { @MainActor in self.setupProgressText = last }
                    }
                }
            }

            do {
                try installTask.run()
                installTask.waitUntilExit()
                setupPipe.fileHandleForReading.readabilityHandler = nil

                await MainActor.run {
                    if installTask.terminationStatus == 0 {
                        self.setupState = .ready
                        self.setupProgressText = "Ready"
                    } else {
                        self.setupState = .error
                        self.setupProgressText = "Installation failed. Check internet connection."
                    }
                }
            } catch {
                await MainActor.run {
                    self.setupState = .error
                    self.setupProgressText = error.localizedDescription
                }
            }
        }
    }

    func debouncedFetchInfo() {
        fetchDebounceTask?.cancel()
        fetchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            if self.hasValidURL { self.fetchVideoInfo() }
        }
    }

    func extractURLs() -> [String] {
        if isMultipleLinks {
            return urlText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("http://") || $0.hasPrefix("https://") }
        } else {
            let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                return [trimmed]
            }
            return []
        }
    }

    func fetchVideoInfo() {
        let urls = extractURLs()
        guard !urls.isEmpty else { return }

        isFetchingInfo = true
        hasVideoInfo = false
        isPlaylist = false
        videoEntries = []
        infoError = nil
        downloadCompleted = false
        downloadError = nil

        let safeYtdlpExe = self.ytdlpExecutable()
        let safeLatteDir = self.latteDirectory
        let safeCookies = self.browserCookies

        Task.detached {
            let batchFile = safeLatteDir.appendingPathComponent("batch.txt")
            let urlsString = urls.joined(separator: "\n")
            try? urlsString.write(to: batchFile, atomically: true, encoding: .utf8)

            let task = Process()
                        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                        task.environment = self.processEnvironment()
                        
                        var arguments = [safeYtdlpExe, "--dump-single-json", "--flat-playlist", "--no-warnings"]
                        
                        if safeCookies != .none {
                            arguments += ["--cookies-from-browser", safeCookies.rawValue]
                        }
                        arguments += ["-a", batchFile.path]
                        
                        task.arguments = arguments

            let stdOutPipe = Pipe()
            let stdErrPipe = Pipe()
            task.standardOutput = stdOutPipe
            task.standardError = stdErrPipe

            var outputData = Data()
            var errorData = Data()
            
            stdOutPipe.fileHandleForReading.readabilityHandler = { handle in
                outputData.append(handle.availableData)
            }
            stdErrPipe.fileHandleForReading.readabilityHandler = { handle in
                errorData.append(handle.availableData)
            }

            do {
                try task.run()
                task.waitUntilExit()
                
                stdOutPipe.fileHandleForReading.readabilityHandler = nil
                stdErrPipe.fileHandleForReading.readabilityHandler = nil
                
                outputData.append(stdOutPipe.fileHandleForReading.readDataToEndOfFile())
                errorData.append(stdErrPipe.fileHandleForReading.readDataToEndOfFile())

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                let lines = output.components(separatedBy: .newlines).filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("{") }
                
                var aggregatedEntries: [VideoEntry] = []
                var foundPlaylistTitle: String? = nil
                var firstSingleDict: [String: Any]? = nil

                for line in lines {
                    guard let data = line.data(using: .utf8),
                          let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    
                    if let entries = info["entries"] as? [[String: Any]] {
                        if foundPlaylistTitle == nil {
                            foundPlaylistTitle = info["title"] as? String ?? info["playlist_title"] as? String
                        }
                        for entry in entries {
                            aggregatedEntries.append(self.parseEntry(entry))
                        }
                    } else {
                        aggregatedEntries.append(self.parseEntry(info))
                        if firstSingleDict == nil { firstSingleDict = info }
                    }
                }

                await MainActor.run {
                    self.isFetchingInfo = false

                    if task.terminationStatus != 0 && aggregatedEntries.isEmpty {
                        var errorMsg = errOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if errorMsg.isEmpty { errorMsg = "Unknown error occurred." }
                        
                        let errLines = errorMsg.components(separatedBy: .newlines)
                        var mainError = errLines.first(where: { $0.contains("ERROR:") }) ?? errLines.last ?? errorMsg
                        let lowerError = mainError.lowercased()
                        
                        if lowerError.contains("account authentication is required") || lowerError.contains("sign in") || lowerError.contains("this content is unreachable") || lowerError.contains("authentication") || lowerError.contains("login") {
                            mainError = "Authentication required. Ensure you are logged into \(safeCookies.displayName) (Default Profile)."
                        } else if lowerError.contains("cannot parse data") {
                            mainError = "Cannot parse data. This is a known yt-dlp limitation, often occurring with private Facebook videos."
                        } else if lowerError.contains("database is locked") {
                            mainError = "\(safeCookies.displayName) cookie database is locked. Try closing the browser and retry."
                        }
                        
                        self.infoError = mainError
                        return
                    }

                    if aggregatedEntries.isEmpty {
                        if task.terminationStatus == 0 {
                            // Succeeded but returned no standard JSON (e.g. some IG Stories)
                            self.isPlaylist = false
                            self.hasVideoInfo = true
                            self.singleVideoTitle = "Media Ready to Download"
                            self.singleVideoUploader = "Metadata unavailable"
                        } else {
                            self.infoError = "No data received"
                        }
                        return
                    }

                    if urls.count > 1 || aggregatedEntries.count > 1 {
                        self.isPlaylist = true
                        self.playlistTitle = urls.count > 1 ? "Batch (\(aggregatedEntries.count) Links)" : (foundPlaylistTitle ?? "Playlist")
                        self.videoEntries = aggregatedEntries
                        self.hasVideoInfo = !aggregatedEntries.isEmpty
                    } else if let singleDict = firstSingleDict {
                        self.isPlaylist = false
                        self.parseSingleVideo(info: singleDict)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isFetchingInfo = false
                    self.infoError = "Failed to fetch info: \(error.localizedDescription)"
                }
            }
        }
    }
    
    nonisolated private func parseEntry(_ info: [String: Any]) -> VideoEntry {
        let t = info["title"] as? String
        let entryTitle = (t?.isEmpty == false) ? t! : (info["id"] as? String ?? "Media Ready to Download")
        let webpageUrl = info["webpage_url"] as? String ?? info["url"] as? String ?? ""

        var thumbnail: String? = nil
        if let thumbnails = info["thumbnails"] as? [[String: Any]], let last = thumbnails.last {
            thumbnail = last["url"] as? String
        } else if let thumb = info["thumbnail"] as? String {
            thumbnail = thumb
        }
        if thumbnail == nil, let id = info["id"] as? String {
            thumbnail = "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"
        }

        let duration = info["duration"] as? Int

        return VideoEntry(url: webpageUrl, title: entryTitle, thumbnailURL: thumbnail, duration: duration, isSelected: true)
    }

    nonisolated private func ytdlpExecutable() -> String {
            let fm = FileManager.default
            if fm.isExecutableFile(atPath: ytdlpPath.path) {
                return ytdlpPath.path
            }
            return "yt-dlp"
        }

        nonisolated private func processEnvironment() -> [String: String] {
            var environment = ProcessInfo.processInfo.environment
            let existingPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(existingPath)"
            return environment
        }

    private func parseSingleVideo(info: [String: Any]) {
        hasVideoInfo = true
        isPlaylist = false
        
        let t = info["title"] as? String
        singleVideoTitle = (t?.isEmpty == false) ? t! : "Media Ready to Download"
        
        singleVideoUploader = info["uploader"] as? String
        singleVideoDuration = info["duration"] as? Int

        if let thumbnails = info["thumbnails"] as? [[String: Any]], let last = thumbnails.last {
            singleVideoThumbnail = last["url"] as? String
        } else if let thumb = info["thumbnail"] as? String {
            singleVideoThumbnail = thumb
        }
    }

    nonisolated private func findNextBatchFolder(basePath: String, prefix: String = "Download") -> String {
        let fm = FileManager.default
        var counter = 1
        while true {
            let folderName = "\(prefix)_\(counter)"
            let folderPath = (basePath as NSString).appendingPathComponent(folderName)
            if !fm.fileExists(atPath: folderPath) {
                return folderPath
            }
            counter += 1
        }
    }

    func startDownload() {
        let urls = extractURLs()
        guard !urls.isEmpty else { return }

        isDownloading = true
        downloadPercent = 0.0
        downloadProgressText = "Starting…"
        downloadError = nil
        downloadCompleted = false

        let isPlaylistDownload = isPlaylist && !videoEntries.isEmpty
        let isMultipleDownload = isMultipleLinks && urls.count > 1
        
        let selectedUrls: [String]
        let targetFolder: String

        if isPlaylistDownload {
            selectedUrls = videoEntries.filter(\.isSelected).map(\.url)
            if selectedUrls.isEmpty {
                isDownloading = false
                downloadError = "No videos selected"
                return
            }
            targetFolder = findNextBatchFolder(basePath: downloadFolder, prefix: "Playlist")
            try? FileManager.default.createDirectory(atPath: targetFolder, withIntermediateDirectories: true)
        } else if isMultipleDownload {
            selectedUrls = urls
            targetFolder = findNextBatchFolder(basePath: downloadFolder, prefix: "Batch")
            try? FileManager.default.createDirectory(atPath: targetFolder, withIntermediateDirectories: true)
        } else {
            selectedUrls = urls
            targetFolder = downloadFolder
        }

        let formatOpt: VideoFormatOption = VideoFormatOption.option(for: selectedVideoFormatId)
        let audioOpt: AudioFormatOption = AudioFormatOption.option(for: selectedAudioFormatId)
        let bCookies = self.browserCookies
        let dlType = self.downloadType
        let eThumb = self.embedThumbnail
        let eMeta = self.embedMetadata
        let wSubs = self.writeSubtitles
        let ytdlp = ytdlpExecutable()

        activeDownloadTask = Task.detached {
            var completedCount = 0
            let totalCount = selectedUrls.count

            for (index, url) in selectedUrls.enumerated() {
                if Task.isCancelled { break }

                let task = Process()
                                await MainActor.run { self.currentDownloadProcess = task }
                                
                                task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                                task.environment = self.processEnvironment()
                                task.currentDirectoryURL = URL(fileURLWithPath: targetFolder)

                                var arguments = [ytdlp, "--no-warnings", "--newline", "--progress"]
                                
                                if bCookies != .none {
                                    arguments += ["--cookies-from-browser", bCookies.rawValue]
                                }

                                if dlType == .video {
                                    arguments += ["-f", formatOpt.formatSpec]
                                    if let mFormat = formatOpt.mergeFormat {
                                        arguments += ["--merge-output-format", mFormat]
                                    }
                                } else {
                                    arguments += ["-f", audioOpt.formatSpec, "-x", "--audio-format", audioOpt.audioFormat, "--audio-quality", audioOpt.audioQuality]
                                }

                                if eThumb { arguments.append("--embed-thumbnail") }
                                if eMeta { arguments.append("--embed-metadata") }
                                if wSubs { arguments += ["--write-subs", "--embed-subs"] }

                                arguments += ["-o", "%(title)s [%(id)s].%(ext)s", url]
                                task.arguments = arguments

                let stdOutPipe = Pipe()
                let stdErrPipe = Pipe()
                task.standardOutput = stdOutPipe
                task.standardError = stdErrPipe

                var lastErrorLine = ""
                
                stdOutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard data.count > 0, let str = String(data: data, encoding: .utf8) else { return }

                    for line in str.components(separatedBy: .newlines) where !line.isEmpty {
                        if line.contains("[download]") {
                            let pattern = #"\d+\.?\d*%"#
                            if let regex = try? NSRegularExpression(pattern: pattern),
                               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                                let pctStr = String(line[Range(match.range, in: line)!])
                                let cleanPct = pctStr.replacingOccurrences(of: "%", with: "")
                                if let pct = Double(cleanPct) {
                                    let overall = (Double(index) + pct / 100.0) / Double(totalCount)
                                    Task { @MainActor in
                                        self.downloadPercent = overall
                                        let cleanLine = line.replacingOccurrences(of: "[download] ", with: "")
                                        self.downloadProgressText = "\(index + 1)/\(totalCount): \(cleanLine)"
                                    }
                                }
                            }
                        }
                    }
                }
                
                stdErrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard data.count > 0, let str = String(data: data, encoding: .utf8) else { return }
                    let lines = str.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    if let last = lines.last {
                        lastErrorLine = last
                    }
                }

                do {
                    try task.run()
                    task.waitUntilExit()
                    
                    stdOutPipe.fileHandleForReading.readabilityHandler = nil
                    stdErrPipe.fileHandleForReading.readabilityHandler = nil

                    if task.terminationStatus == 0 {
                        completedCount += 1
                    } else {
                        let fallbackError = lastErrorLine.isEmpty ? "Unknown error occurred" : lastErrorLine
                        let lowerError = fallbackError.lowercased()
                        
                        await MainActor.run {
                            if lowerError.contains("unreachable") || lowerError.contains("authentication") || lowerError.contains("sign in") {
                                self.downloadError = "Authentication failed. Make sure you are logged into \(bCookies.displayName)."
                            } else if lowerError.contains("cannot parse data") {
                                self.downloadError = "Cannot parse data. This is a known yt-dlp limitation with some private videos."
                            } else {
                                self.downloadError = "Failed: \(fallbackError.prefix(100))"
                            }
                        }
                        break
                    }
                } catch {
                    await MainActor.run {
                        self.downloadError = "Failed to start download"
                    }
                    break
                }
            }

            let finalCompletedCount = completedCount
            await MainActor.run {
                self.isDownloading = false
                self.currentDownloadProcess = nil
                if finalCompletedCount == totalCount && totalCount > 0 {
                    self.downloadCompleted = true
                    self.downloadProgressText = "Complete"
                    self.downloadPercent = 1.0
                }
            }
        }
    }

    func stopDownload() {
        activeDownloadTask?.cancel()
        if let process = currentDownloadProcess {
            process.terminationHandler = nil
            process.terminate()
        }
        isDownloading = false
        downloadProgressText = "Stopped"
    }

    func clearState() {
        hasVideoInfo = false
        isPlaylist = false
        videoEntries = []
        singleVideoTitle = ""
        singleVideoThumbnail = nil
        singleVideoUploader = nil
        singleVideoDuration = nil
        infoError = nil
        downloadError = nil
        downloadCompleted = false
        downloadPercent = 0.0
        downloadProgressText = ""
    }
    
    func resetFormatOrders() {
        videoFormatOrder = VideoFormatOption.allOptions.map(\.id)
        audioFormatOrder = AudioFormatOption.allOptions.map(\.id)
        hiddenVideoFormats = []
        hiddenAudioFormats = []
    }

    func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}
