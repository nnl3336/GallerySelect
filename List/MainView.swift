//
//  MainView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/18.
//

import SwiftUI

// MARK: - SwiftUI MainView
struct MainView: View {
    @ObservedObject var controller: PhotoController
    @State private var selectedIndex: Int? = nil
    @State private var selectedPhotos = Set<Int>()
    @State private var showPicker = false
    @State private var showSearch = false
    @State private var showFolderSheet = false
    @State private var showAlbum = false
    @State private var segmentSelection = 2
    @State private var showFastScroll = false
    @State private var dragPosition: CGFloat = 0

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let segments = ["後ろの月", "前の月", "すべての写真"]

    var filteredPhotos: [Photo] {
        switch segmentSelection {
        case 0: // 後ろの月
            return controller.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(30*24*60*60), toGranularity: .month)
            }
        case 1: // 前の月
            return controller.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(-30*24*60*60), toGranularity: .month)
            }
        case 2: // すべての写真
            return controller.photos
        default:
            return controller.photos
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                PhotoGrid(
                    controller: controller,
                    selectedIndex: $selectedIndex,
                    selectedPhotos: $selectedPhotos,
                    showFastScroll: $showFastScroll,
                    dragPosition: $dragPosition,
                    columns: columns,
                    filteredPhotos: filteredPhotos
                )

                if selectedIndex == nil {
                    Picker("", selection: $segmentSelection) {
                        ForEach(0..<segments.count, id: \.self) { i in
                            Text(segments[i])
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }

                if !selectedPhotos.isEmpty {
                    HStack {
                        Spacer()
                        Button("cancel") { selectedPhotos.removeAll() }
                        Spacer()
                    }
                    .padding(.leading)
                }
            }
            .navigationTitle("写真")
        }
    }
}

struct FastScrollBar: View {
    @Binding var dragPosition: CGFloat
    let filteredPhotosCount: Int
    let proxy: ScrollViewProxy   // ← ここは直接型として指定

    var body: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 30, height: 150)
                .cornerRadius(15)
                .overlay(
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 30, height: 30)
                        .offset(y: dragPosition)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let totalHeight: CGFloat = 150
                                    let y = min(max(value.location.y, 0), totalHeight)
                                    dragPosition = y - totalHeight/2
                                    let ratio = y / totalHeight
                                    let index = Int(ratio * CGFloat(max(filteredPhotosCount-1, 0)))
                                    withAnimation(.linear(duration: 0.05)) {
                                        proxy.scrollTo(index, anchor: .top)
                                    }
                                }
                        )
                )
            Spacer()
        }
        .frame(width: 40)
        .padding(.trailing, 8)
        .transition(.opacity)
        .animation(.easeInOut, value: dragPosition)
    }
}

struct PhotoGrid: View {
    @ObservedObject var controller: PhotoController
    @Binding var selectedIndex: Int?
    @Binding var selectedPhotos: Set<Int>
    @Binding var showFastScroll: Bool
    @Binding var dragPosition: CGFloat
    let columns: [GridItem]
    let filteredPhotos: [Photo]

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filteredPhotos.indices, id: \.self) { index in
                            let photo = filteredPhotos[index]
                            let isSelected = selectedPhotos.contains(index)

                            PhotoGridCell(photo: photo, isSelected: isSelected)
                                .id(index)
                                .onTapGesture {
                                    if !selectedPhotos.isEmpty {
                                        if isSelected {
                                            selectedPhotos.remove(index)
                                        } else {
                                            selectedPhotos.insert(index)
                                        }
                                    } else {
                                        selectedIndex = index
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        if isSelected {
                                            selectedPhotos.remove(index)
                                        } else {
                                            selectedPhotos.insert(index)
                                        }
                                    } label: {
                                        Label(
                                            isSelected ? "選択解除" : "選択",
                                            systemImage: "checkmark.circle"
                                        )
                                    }

                                    if let uiImage = photo.thumbnail {
                                        Button {
                                            controller.saveImageToCameraRoll(uiImage)
                                        } label: {
                                            Label("保存", systemImage: "square.and.arrow.down")
                                        }
                                    }

                                    Button {
                                        controller.deletePhoto(at: index)
                                    } label: {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                    .gesture(DragGesture()
                        .onChanged { _ in showFastScroll = true }
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                showFastScroll = false
                            }
                        }
                    )
                }

                // 右端スクロールバー
                if showFastScroll {
                    FastScrollBar(
                        dragPosition: $dragPosition,
                        filteredPhotosCount: filteredPhotos.count,
                        proxy: proxy
                    )
                }

                // フルスクリーンスライダー
                if let index = selectedIndex {
                    PhotoSliderView(
                        fetchController: controller,
                        selectedIndex: index,
                        onClose: { selectedIndex = nil }
                    )
                    .zIndex(1)
                }

                // フローティングボタン
                FloatingButtonPanel(
                    selectedPhotos: $selectedPhotos,
                    showPicker: .constant(false),
                    showSearch: .constant(false),
                    showFolderSheet: .constant(false),
                    controller: controller
                )
            }
        }
    }
}

//

struct PhotoGridCell: View {
    var photo: Photo
    var isSelected: Bool
    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 100)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        isSelected ? Color.blue.opacity(0.3).cornerRadius(8) : nil
                    )
                    .contentShape(Rectangle())
            } else {
                Color.gray.frame(height: 100).cornerRadius(8)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .padding(5)
            }
        }
        .onAppear {
            if thumbnail == nil, let data = photo.imageData,
               let uiImage = UIImage(data: data) {
                DispatchQueue.global(qos: .userInitiated).async {
                    let resized = uiImage.resize(to: CGSize(width: 150, height: 150))
                    DispatchQueue.main.async {
                        thumbnail = resized
                    }
                }
            }
        }
    }
}

//

struct FloatingButtonPanel: View {
    @Binding var selectedPhotos: Set<Int>
    @Binding var showPicker: Bool
    @Binding var showSearch: Bool
    @Binding var showFolderSheet: Bool
    var controller: PhotoController

    var body: some View {
        VStack { Spacer()
            HStack {
                NavigationLink(destination: FolderListView(controller: controller)) {
                    Image(systemName: "photo.on.rectangle")
                        .floatingStyle(color: .blue)
                }
                Button { showFolderSheet = true } label: {
                    Image(systemName: "folder.badge.plus")
                        .floatingStyle(color: .purple)
                }
                Spacer()
                Button { showSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                        .floatingStyle(color: .green)
                }
                Button { showPicker = true } label: {
                    Image(systemName: "plus")
                        .floatingStyle(color: .orange)
                }
            }
            .padding(.bottom, 30)
        }
    }
}

class ImageCache: ObservableObject {
    @Published var cache: [String: UIImage] = [:]

    func image(for key: String) -> UIImage? {
        cache[key]
    }

    func set(_ image: UIImage, for key: String) {
        cache[key] = image
    }
}
