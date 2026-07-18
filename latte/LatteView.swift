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
    @State private var isPanelVisible: Bool = true
    
    @FocusState private var isInputFocused: Bool
    @State private var isMultipleLinksCollapsed: Bool = false

    private let baseWindowWidth: CGFloat = 380
    
    // To ensure that enough and consistent height for the section
    private var dynamicWindowHeight: CGFloat {
        if showFormatPriority {
            let maxCount = max(client.orderedVideoFormats.count, client.orderedAudioFormats.count)
            return CGFloat(maxCount * 22) + 140
        }
        // Increased height to safely fit the new Settings typography spacing
        if showSettings || showAbout { return 460 }
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
        .background(AmbientThemeBackground(theme: client.appTheme, isActive: isPanelVisible))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { isInputFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .panelVisibilityChanged)) { notification in
            isPanelVisible = notification.userInfo?["value"] as? Bool ?? false
        }
    }

    // MARK: - Setup Overlay

    private var setupOverlay: some View {
        VStack(spacing: 14) {
            if client.setupState == .installing || client.setupState == .checking {
                ProgressView().scaleEffect(0.8)
                Text(client.setupState == .checking ? "Checking Environment…" : "Initial Setup in Progress")
                    .font(.system(size: 13, weight: .medium))
            } else if client.setupState == .error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 24))
                Text("Setup Failed")
                    .font(.system(size: 13, weight: .medium))
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
                    Button("Retry") { client.runSetupScript() }.controlSize(.small)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            HStack(alignment: .top, spacing: 10) {
                urlInputSection
                
                Button(action: { client.keepPanelOpen.toggle() }) {
                    Image(systemName: client.keepPanelOpen ? "pin.fill" : "pin")
                        .font(.system(size: 14))
                        .foregroundColor(client.keepPanelOpen ? client.appTheme.accentColor : .secondary)
                        .frame(width: 28, height: 28)
                        .background(client.keepPanelOpen ? client.appTheme.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(6)
                }
                // ensure that the pin button doesn't moved down when the multiple link is selected
                .buttonStyle(.plain)
                .help(client.keepPanelOpen ? "Unpin Window" : "Pin Window Open")
                .padding(.trailing, 12)
                .padding(.top, client.isMultipleLinks ? 6 : 6)
            }

            // To add more padding to the tick box
            HStack {
                Toggle(isOn: Binding(
                    get: { client.isMultipleLinks },
                    set: { val in Task { @MainActor in client.isMultipleLinks = val; client.clearState() } }
                )) {
                    Text("Multiple Links")
                        .font(.system(size: 11))
                }
                .toggleStyle(.checkbox)
                Spacer()
            }
            .padding(.horizontal, 14)

            formatSelectionSection

            videoInfoSection

            if let error = client.infoError {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .padding(.top, 1)
                    Text(error)
                        .font(.system(size: 11))
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
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - URL Input

    private var urlInputSection: some View {
        Group {
            if client.isMultipleLinks {
                ZStack(alignment: .topTrailing) {
                    ZStack(alignment: .topLeading) {
                        if client.urlText.isEmpty {
                            // To match the hint text and cursor perfectly
                            Text("Paste video links (one per line)…")
                                .foregroundColor(Color(NSColor.placeholderTextColor))
                                .font(.system(size: 13))
                                // ALIGN PLACEHOLDER WITH CURSOR
                                .padding(.leading, 5) // Shift left/right
                                .padding(.top, 0)     // Shift up/down
                        }
                        TextEditor(text: $client.urlText)
                            .font(.system(size: 13))
                            .scrollContentBackground(.hidden)
                    }
                    .padding(4)
                    .frame(height: isMultipleLinksCollapsed ? 56 : 88)
                    
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
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                .padding(.leading, 12)
                .padding(.top, 12)
            } else {
                HStack(spacing: 8) {
                    TextField("Paste video link here…", text: $client.urlText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .regular))
                        .focused($isInputFocused)

                    if !client.urlText.isEmpty {
                        Button(action: { client.urlText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 12)
                .padding(.vertical, 10)
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
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .help("ffmpeg not found. Merging/converting may not work.")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
    }

    // MARK: - Video Info Section

    private var videoInfoSection: some View {
        Group {
            if client.isFetchingInfo {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.5)
                    Text("Fetching info…")
                        .font(.system(size: 12))
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
        HStack(alignment: .top, spacing: 12) {
            ThumbnailView(urlString: client.singleVideoThumbnail, width: 100, height: 56)
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 3) {
                Text(client.singleVideoTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)

                if let uploader = client.singleVideoUploader {
                    Text(uploader)
                        .font(.system(size: 11))
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
            
            if client.singleVideoThumbnail != nil {
                Button(action: { client.downloadThumbnailOnly() }) {
                    Image(systemName: "photo.badge.arrow.down")
                        .font(.system(size: 14))
                        .foregroundColor(client.appTheme.accentColor)
                        .frame(width: 28, height: 28)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Download Thumbnail Only")
            }
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
        .padding(.horizontal, 12)
    }

    private var playlistView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(client.playlistTitle)
                    .font(.system(size: 12, weight: .medium))
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
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Text("\(selectedCount)/\(totalCount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(client.videoEntries.indices, id: \.self) { index in
                        playlistItemRow(index: index)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
        .padding(.horizontal, 12)
    }

    private func playlistItemRow(index: Int) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { client.videoEntries[index].isSelected },
                set: { client.videoEntries[index].isSelected = $0 }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            ThumbnailView(urlString: client.videoEntries[index].thumbnailURL, width: 48, height: 28)
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.videoEntries[index].title)
                    .font(.system(size: 11))
                    .lineLimit(1)

                if let duration = client.videoEntries[index].duration {
                    Text(client.formatDuration(duration))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Download Section

    private var downloadSection: some View {
        VStack(spacing: 8) {
            if client.downloadCompleted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text(client.downloadProgressText.contains("Thumbnail") ? "Thumbnail saved" : "Saved to \(client.downloadFolder)").foregroundColor(.green).lineLimit(1)
                    Spacer()
                }
                .font(.system(size: 11))
                .padding(.horizontal, 12)
            }
            
            if let error = client.downloadError {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                    Text(error).foregroundColor(.red).lineLimit(3)
                    Spacer()
                }
                .font(.system(size: 11))
                .padding(.horizontal, 12)
            }

            if client.isDownloading {
                HStack(spacing: 12) {
                    Button(action: { client.stopDownload() }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)

                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: client.downloadPercent)
                            .progressViewStyle(.linear)
                        Text(client.downloadProgressText)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text("\(Int(client.downloadPercent * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .padding(.horizontal, 12)
            } else {
                Button(action: { client.startDownload() }) {
                    Text("Download")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(client.canDownload ? client.appTheme.accentColor : Color(NSColor.unemphasizedSelectedContentBackgroundColor))
                .foregroundColor(client.canDownload ? .white : Color(NSColor.disabledControlTextColor))
                .disabled(!client.canDownload)
                .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - Bottom Bar (Main & Settings)

    private var bottomBar: some View {
        HStack {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if showFormatPriority { showFormatPriority = false }
                    else if showAbout { showAbout = false }
                    else { showSettings.toggle() }
                }
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: (showSettings || showAbout || showFormatPriority) ? "chevron.left" : "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(client.hasUpdateAvailable ? .orange : .secondary)
                    
                    if client.hasUpdateAvailable && !(showSettings || showAbout || showFormatPriority) {
                        Circle().fill(Color.red).frame(width: 5, height: 5).offset(x: 4, y: -2)
                    }
                }
                .frame(width: 30, alignment: .leading)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { NSWorkspace.shared.open(URL(fileURLWithPath: client.downloadFolder)) }) {
                Image(systemName: "folder")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Exit") { NSApplication.shared.terminate(nil) }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .buttonStyle(.plain)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
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
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: { withAnimation { showAbout = true } }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(client.hasUpdateAvailable ? .orange : .secondary)
                        
                        if client.hasUpdateAvailable {
                            Circle().fill(Color.red).frame(width: 5, height: 5).offset(x: 3, y: -1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Download Folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    Text(client.downloadFolder)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose") { chooseDownloadFolder() }
                        .controlSize(.small)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Authentication (For Restricted Sites)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    Text("Browser Cookies")
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: $client.browserCookies) {
                        ForEach(BrowserCookie.allCases) { browser in
                            Text(browser.displayName).tag(browser)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                
                if client.browserCookies != .none {
                    Text("Please ensure you are logged in on the Default Profile.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Post-Processing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                Toggle("Embed Thumbnail", isOn: $client.embedThumbnail)
                    .font(.system(size: 13))
                Toggle("Embed Metadata", isOn: $client.embedMetadata)
                    .font(.system(size: 13))
                Toggle("Download Subtitles", isOn: $client.writeSubtitles)
                    .font(.system(size: 13))
            }
            
            Toggle("Allow Window Dragging", isOn: $client.isWindowMovable)
                .font(.system(size: 13))
            
            Divider().opacity(0.5)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Format Priority")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                HStack {
                    Text("Show/hide and reorder formats")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Edit") {
                        withAnimation { showFormatPriority = true }
                    }
                    .controlSize(.small)
                }
            }

            if !client.ffmpegAvailable {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("ffmpeg not found. Install via: brew install ffmpeg")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    // MARK: - Format Priority Content

    private var formatPriorityContent: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Format Priority")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Reset") { client.resetFormatOrders() }
                    .controlSize(.small)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Video").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
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
                                    .font(.system(size: 12))
                                    .foregroundColor(isHidden ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        }
                        .onMove { indices, newOffset in
                            client.videoFormatOrder.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 22)
                    .frame(height: CGFloat(client.orderedVideoFormats.count * 22))
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                    .cornerRadius(6)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Audio").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
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
                                    .font(.system(size: 12))
                                    .foregroundColor(isHidden ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                        }
                        .onMove { indices, newOffset in
                            client.audioFormatOrder.move(fromOffsets: indices, toOffset: newOffset)
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 22)
                    .frame(height: CGFloat(client.orderedAudioFormats.count * 22))
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                    .cornerRadius(6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
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
        VStack(spacing: 16) {
            Text("About")
                .font(.system(size: 15, weight: .semibold))

            VStack(spacing: 4) {
                if let nsImage = NSImage(named: "AppIcon") {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .cornerRadius(14)
                }
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Latte")
                    .font(.system(size: 14, weight: .bold))
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Button(action: {
                if let url = URL(string: "https://github.com/arinltte/latte/releases/latest") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text(client.hasUpdateAvailable ? "Download New Version (v\(client.updateVersionTag ?? ""))" : "Up to Date")
                    .font(.system(size: 12))
                    .foregroundColor(client.hasUpdateAvailable ? .white : nil)
                    .padding(.horizontal, client.hasUpdateAvailable ? 10 : 0)
                    .padding(.vertical, client.hasUpdateAvailable ? 4 : 0)
                    .background(client.hasUpdateAvailable ? client.appTheme.accentColor : Color.clear)
                    .cornerRadius(6)
            }
            .controlSize(.regular)
            .disabled(!client.hasUpdateAvailable)

            Divider().opacity(0.5)

            HStack {
                Text("Menu Bar Icon")
                    .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 13, weight: .medium))
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

            VStack(spacing: 2) {
                Text("2026 Developed by [arinltte](https://github.com/arinltte)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .tint(client.appTheme.accentColor)

                Text("cjshen00@gmail.com")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(16)
    }
}

// MARK: - Thumbnail Cache

/// Shared in-memory cache for downloaded thumbnail images.
/// Using NSCache so entries are automatically evicted under memory pressure.
/// This prevents re-downloading thumbnails every time the panel is shown
/// (since `hidePanel()` sets `contentView = nil`, destroying the SwiftUI view tree).
private final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 25 * 1024 * 1024 // ~25 MB
    }

    func image(for key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func store(_ image: NSImage, for key: String, cost: Int = 0) {
        cache.setObject(image, forKey: key as NSString, cost: cost)
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
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: min(width, height) * 0.35))
                            .foregroundColor(.secondary.opacity(0.5))
                    )
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .onAppear { loadThumbnail() }
        .onChange(of: urlString) { _, _ in loadedImage = nil; loadThumbnail() }
    }

    private func loadThumbnail() {
        guard let urlString = urlString,
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" else { return }

        // Return cached image immediately if available
        if let cached = ThumbnailCache.shared.image(for: urlString) {
            self.loadedImage = cached
            return
        }

        Task.detached {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard data.count <= 5 * 1024 * 1024 else { return }
                
                if let httpResponse = response as? HTTPURLResponse,
                   let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                   !contentType.hasPrefix("image/") {
                    return
                }
                
                if let image = NSImage(data: data) {
                    ThumbnailCache.shared.store(image, for: urlString, cost: data.count)
                    Task { @MainActor in self.loadedImage = image }
                }
            } catch { }
        }
    }
}
