//
//  LatteView.swift
//  latte
//
//  Created on 22/05/2026.
//

import SwiftUI

struct LatteView: View {
    @StateObject var client = YTDLPClient()
    var onClose: () -> Void

    @State private var showSettings: Bool = false
    @State private var showAbout: Bool = false
    @State private var showFormatPriority: Bool = false
    
    @FocusState private var isInputFocused: Bool
    @State private var isMultipleLinksCollapsed: Bool = false
    
    @State private var updateStatus: String = "Check for Updates"
    @State private var updateURL: String? = nil

    private let baseWindowWidth: CGFloat = 380
    
    private var dynamicWindowHeight: CGFloat {
        if showFormatPriority {
            return 480
        }
        if showSettings || showAbout {
            return 410 // Adjusted for removed Safari warning height
        }
        let expandList = client.isPlaylist && !client.videoEntries.isEmpty
        return expandList ? 460 : 360
    }

    var body: some View {
        VStack(spacing: 0) {
            if client.setupState != .ready {
                setupOverlay
            } else if showFormatPriority {
                formatPriorityContent
            } else if showSettings {
                if showAbout {
                    aboutContent
                } else {
                    settingsContent
                }
            } else {
                mainContent
            }

            Spacer(minLength: 0)

            if client.setupState == .ready {
                Divider().opacity(0.5)
                if showFormatPriority || showAbout {
                    backOnlyBottomBar
                } else {
                    bottomBar
                }
            }
        }
        .frame(width: baseWindowWidth, height: dynamicWindowHeight)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dynamicWindowHeight)
        .animation(.easeInOut(duration: 0.2), value: showSettings)
        .animation(.easeInOut(duration: 0.2), value: showAbout)
        .animation(.easeInOut(duration: 0.2), value: showFormatPriority)
        .tint(client.appTheme.accentColor)
        .background(AmbientThemeBackground(theme: client.appTheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            isInputFocused = true
        }
    }

    // MARK: - Setup Overlay

    private var setupOverlay: some View {
        VStack(spacing: 14) {
            if client.setupState == .installing || client.setupState == .checking {
                ProgressView().scaleEffect(0.8)
                Text(client.setupState == .checking ? "Checking Environment…" : "Initial Setup in Progress")
                    .font(.system(size: 13, weight: .semibold))
            } else if client.setupState == .error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 24))
                Text("Setup Failed")
                    .font(.system(size: 13, weight: .semibold))
            }
            Text(client.setupProgressText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 16)
            if client.setupState == .error {
                HStack(spacing: 12) {
                    Button("Exit") { NSApplication.shared.terminate(nil) }.controlSize(.small)
                    Button("Retry") {
                        let c = client
                        c.runSetupScript()
                    }.controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            urlInputSection

            HStack {
                Toggle(isOn: Binding(
                    get: { client.isMultipleLinks },
                    set: { val in
                        Task { @MainActor in client.isMultipleLinks = val; client.clearState() }
                    }
                )) {
                    Text("Multiple Links")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                Spacer()
            }
            .padding(.horizontal, 12)

            formatSelectionSection

            videoInfoSection

            if let error = client.infoError {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 0)

            downloadSection
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - URL Input

    private var urlInputSection: some View {
        Group {
            if client.isMultipleLinks {
                ZStack(alignment: .topTrailing) {
                    ZStack(alignment: .topLeading) {
                        if client.urlText.isEmpty {
                            Text("Paste video links (one per line)…")
                                .foregroundColor(.secondary.opacity(0.6))
                                .font(.system(size: 13))
                                .padding(.leading, 9)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $client.urlText)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                    }
                    .padding(.leading, 4)
                    .padding(.vertical, 8)
                    .padding(.trailing, 22)
                    .frame(height: isMultipleLinksCollapsed ? 60 : 88)
                    
                    Button(action: { withAnimation { isMultipleLinksCollapsed.toggle() } }) {
                        Image(systemName: isMultipleLinksCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
                .background(Color.black.opacity(0.15))
                .cornerRadius(8)
                .padding(.horizontal, 12)
            } else {
                HStack(spacing: 8) {
                    TextField("Paste video link here…", text: $client.urlText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .regular))
                        .focused($isInputFocused)

                    if !client.urlText.isEmpty {
                        Button(action: {
                            client.urlText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
        }
        .onChange(of: client.urlText) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                client.clearState()
            } else if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                let linesCount = newValue.components(separatedBy: .newlines).count
                if client.isMultipleLinks {
                    withAnimation { isMultipleLinksCollapsed = (linesCount >= 10) }
                }
                client.debouncedFetchInfo()
            }
        }
    }

    // MARK: - Format Selection

    private var formatSelectionSection: some View {
        HStack(spacing: 8) {
            Picker("Type", selection: Binding(
                get: { client.downloadType },
                set: { val in Task { @MainActor in client.downloadType = val } }
            )) {
                ForEach(DownloadType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 120)

            if client.downloadType == .video {
                Picker("Format", selection: Binding(
                    get: { client.selectedVideoFormatId },
                    set: { val in Task { @MainActor in client.selectedVideoFormatId = val } }
                )) {
                    ForEach(client.activeVideoFormats) { fmt in
                        Text(fmt.displayName).tag(fmt.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            } else {
                Picker("Quality", selection: Binding(
                    get: { client.selectedAudioFormatId },
                    set: { val in Task { @MainActor in client.selectedAudioFormatId = val } }
                )) {
                    ForEach(client.activeAudioFormats) { fmt in
                        Text(fmt.displayName).tag(fmt.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Spacer()

            if !client.ffmpegAvailable {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                    .help("ffmpeg not found. Merging/converting may not work.")
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Video Info Section

    private var videoInfoSection: some View {
        Group {
            if client.isFetchingInfo {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Fetching info…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
            } else if client.isPlaylist && !client.videoEntries.isEmpty {
                playlistView
            } else if client.hasVideoInfo && !client.isPlaylist {
                singleVideoView
            }
        }
    }

    private var singleVideoView: some View {
        HStack(alignment: .top, spacing: 10) {
            ThumbnailView(urlString: client.singleVideoThumbnail, width: 110, height: 62)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.singleVideoTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)

                if let uploader = client.singleVideoUploader {
                    Text(uploader)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let duration = client.singleVideoDuration {
                    Text(client.formatDuration(duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
    }

    private var playlistView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(client.playlistTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Spacer()

                let selectedCount = client.videoEntries.filter(\.isSelected).count
                let totalCount = client.videoEntries.count

                Button(action: {
                    let allSelected = client.videoEntries.allSatisfy(\.isSelected)
                    for i in client.videoEntries.indices {
                        client.videoEntries[i].isSelected = !allSelected
                    }
                }) {
                    Text(selectedCount == totalCount ? "Deselect All" : "Select All")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Text("\(selectedCount)/\(totalCount)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(client.videoEntries.indices, id: \.self) { index in
                        playlistItemRow(index: index)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func playlistItemRow(index: Int) -> some View {
        HStack(spacing: 6) {
            Toggle("", isOn: Binding(
                get: { client.videoEntries[index].isSelected },
                set: { client.videoEntries[index].isSelected = $0 }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            ThumbnailView(urlString: client.videoEntries[index].thumbnailURL, width: 56, height: 32)
                .cornerRadius(3)

            VStack(alignment: .leading, spacing: 1) {
                Text(client.videoEntries[index].title)
                    .font(.system(size: 10))
                    .lineLimit(1)

                if let duration = client.videoEntries[index].duration {
                    Text(client.formatDuration(duration))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 1)
    }

    // MARK: - Download Section

    private var downloadSection: some View {
        VStack(spacing: 6) {
            if client.downloadCompleted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundColor(Color.green.opacity(0.8))
                    Text("Saved to \(client.downloadFolder)")
                        .font(.system(size: 10)).foregroundColor(Color.green.opacity(0.8)).lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
            
            if let error = client.downloadError {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundColor(.red)
                    Text(error).font(.system(size: 10)).foregroundColor(.red).lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 12)
            }

            if client.isDownloading {
                HStack(spacing: 8) {
                    Button(action: {
                        let c = client
                        c.stopDownload()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.circle.fill").font(.system(size: 12))
                            Text("Stop").font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 1) {
                        ProgressView(value: client.downloadPercent)
                            .progressViewStyle(.linear)
                            .frame(height: 4)
                        Text(client.downloadProgressText)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text("\(Int(client.downloadPercent * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
                .padding(.horizontal, 12)
            } else {
                Button(action: {
                    let c = client
                    c.startDownload()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                        Text("Download")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(client.hasValidURL ? client.appTheme.accentColor : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!client.hasValidURL)
                .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - Bottom Bar (Main & Settings)

    private var bottomBar: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if showFormatPriority {
                        showFormatPriority = false
                    } else if showAbout {
                        showAbout = false
                    } else {
                        showSettings.toggle()
                    }
                }
            }) {
                Image(systemName: (showSettings || showAbout || showFormatPriority) ? "chevron.left" : "gearshape")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: {
                NSWorkspace.shared.open(URL(fileURLWithPath: client.downloadFolder))
            }) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Exit") { NSApplication.shared.terminate(nil) }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 28)
    }

    // MARK: - Bottom Bar (Back Only)

    private var backOnlyBottomBar: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if showFormatPriority { showFormatPriority = false }
                    else if showAbout { showAbout = false }
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: 28)
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: { withAnimation { showAbout = true } }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Download Folder")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    Text(client.downloadFolder)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose") { chooseDownloadFolder() }
                        .font(.system(size: 10))
                        .controlSize(.small)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Authentication (For Restricted Sites)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    Text("Browser Cookies")
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: $client.browserCookies) {
                        ForEach(BrowserCookie.allCases) { browser in
                            Text(browser.displayName).tag(browser)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
                
                if client.browserCookies != .none {
                    Text("Please ensure you are logged in on the Default Profile.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Post-Processing")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                Toggle("Embed Thumbnail", isOn: $client.embedThumbnail)
                    .font(.system(size: 12))
                Toggle("Embed Metadata", isOn: $client.embedMetadata)
                    .font(.system(size: 12))
                Toggle("Download Subtitles", isOn: $client.writeSubtitles)
                    .font(.system(size: 12))
            }
            
            HStack {
                Toggle("Keep Window Open", isOn: $client.keepPanelOpen)
                    .font(.system(size: 12))
                Spacer()
                Toggle("Allow Dragging", isOn: $client.isWindowMovable)
                    .font(.system(size: 12))
            }
            
            Divider().opacity(0.5)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Format Priority")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    Text("Show/hide and reorder formats")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Edit") {
                        withAnimation { showFormatPriority = true }
                    }
                    .font(.system(size: 10))
                    .controlSize(.small)
                }
            }

            if !client.ffmpegAvailable {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("ffmpeg not found. Install via: brew install ffmpeg")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    // MARK: - Format Priority Content

    private var formatPriorityContent: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Format Priority")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Reset") {
                    client.resetFormatOrders()
                }
                .font(.system(size: 11))
                .controlSize(.small)
            }
            .padding(.bottom, 4)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Video").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    List {
                        ForEach(client.orderedVideoFormats) { fmt in
                            let isHidden = client.hiddenVideoFormats.contains(fmt.id)
                            HStack {
                                Button(action: {
                                    if isHidden { client.hiddenVideoFormats.removeAll { $0 == fmt.id } }
                                    else { client.hiddenVideoFormats.append(fmt.id) }
                                }) {
                                    Image(systemName: isHidden ? "eye.slash" : "eye")
                                        .foregroundColor(isHidden ? .secondary : client.appTheme.accentColor)
                                        .frame(width: 16)
                                }
                                .buttonStyle(.plain)
                                
                                Text(fmt.displayName)
                                    .font(.system(size: 11))
                                    .foregroundColor(isHidden ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
                        }
                        .onMove { indices, newOffset in
                            client.videoFormatOrder.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 22)
                    .frame(height: 250)
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.05), lineWidth: 1))
                    .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    List {
                        ForEach(client.orderedAudioFormats) { fmt in
                            let isHidden = client.hiddenAudioFormats.contains(fmt.id)
                            HStack {
                                Button(action: {
                                    if isHidden { client.hiddenAudioFormats.removeAll { $0 == fmt.id } }
                                    else { client.hiddenAudioFormats.append(fmt.id) }
                                }) {
                                    Image(systemName: isHidden ? "eye.slash" : "eye")
                                        .foregroundColor(isHidden ? .secondary : client.appTheme.accentColor)
                                        .frame(width: 16)
                                }
                                .buttonStyle(.plain)
                                
                                Text(fmt.displayName)
                                    .font(.system(size: 11))
                                    .foregroundColor(isHidden ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6))
                        }
                        .onMove { indices, newOffset in
                            client.audioFormatOrder.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 22)
                    .frame(height: 250)
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.15))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.05), lineWidth: 1))
                    .cornerRadius(6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private func chooseDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: client.downloadFolder)

        if panel.runModal() == .OK, let url = panel.urls.first {
            client.downloadFolder = url.path
        }
    }

    // MARK: - About Content
    private var aboutContent: some View {
        VStack(spacing: 12) {
            Text("About")
                .font(.system(size: 14, weight: .semibold))

            VStack(spacing: 3) {
                if let nsImage = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                        .cornerRadius(12)
                }
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Latte")
                    .font(.system(size: 13, weight: .bold))
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                if let url = updateURL {
                    NSWorkspace.shared.open(URL(string: url)!)
                    return
                }
                updateStatus = "Checking..."
                Task {
                    do {
                        let reqURL = URL(string: "https://github.com/arinltte/latte/releases/latest")!
                        var request = URLRequest(url: reqURL)
                        request.httpMethod = "HEAD"
                        let (_, response) = try await URLSession.shared.data(for: request)
                        let tag = (response.url?.lastPathComponent ?? "")
                            .trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "v"))

                        let current = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.1.0"
                        let isNewer = tag.compare(current, options: .numeric) == .orderedDescending

                        if !tag.isEmpty && isNewer {
                            updateStatus = "New Version Released (v\(tag))"
                            updateURL = "https://github.com/arinltte/latte/releases/latest"
                        } else {
                            updateStatus = "Up to Date"
                        }
                    } catch {
                        updateStatus = "Check for Updates"
                    }
                }
            }) {
                Text(updateStatus)
                    .font(.system(size: 11))
                    .foregroundColor(updateURL != nil ? .white : nil)
                    .padding(.horizontal, updateURL != nil ? 8 : 0)
                    .padding(.vertical, updateURL != nil ? 3 : 0)
                    .background(updateURL != nil ? client.appTheme.accentColor : Color.clear)
                    .cornerRadius(4)
            }
            .controlSize(.small)
            .disabled(updateStatus == "Checking..." || updateStatus == "Up to Date")

            Divider().opacity(0.5)

            HStack {
                Text("Menu Bar Icon")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("", selection: $client.menuBarIcon) {
                    Text("⬇ Arrow").tag("arrow.down.circle.fill")
                    Text("🎬 Play").tag("play.circle.fill")
                    Text("🎵 Music").tag("music.note")
                    Text("📥 Download").tag("square.and.arrow.down")
                    Text("☕ Coffee").tag("cup.and.saucer.fill")
                    Text("🍿 Popcorn").tag("popcorn.fill")
                    Text("📺 TV").tag("tv")
                    Text("💡 Light").tag("lightbulb.fill")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
            
            HStack {
                Text("Theme")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Picker("", selection: $client.appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text("2026 Developed by [arinltte](https://github.com/arinltte)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .tint(client.appTheme.accentColor)

                Text("cjshen00@gmail.com")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(14)
    }
}

// MARK: - Thumbnail View
struct ThumbnailView: View {
    let urlString: String?
    let width: CGFloat
    let height: CGFloat

    @State private var loadedImage: NSImage? = nil

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.15))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: min(width, height) * 0.35))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .onAppear { loadThumbnail() }
        .onChange(of: urlString) { _, _ in loadedImage = nil; loadThumbnail() }
    }

    private func loadThumbnail() {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }
        Task.detached {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = NSImage(data: data) {
                    Task { @MainActor in self.loadedImage = image }
                }
            } catch { }
        }
    }
}
