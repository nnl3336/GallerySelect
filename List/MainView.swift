//
//  MainView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/18.
//

import SwiftUI

struct MainView: View {
    @ObservedObject var photoController: PhotoController
    @ObservedObject var folderController: FolderController
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
            return photoController.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(30*24*60*60), toGranularity: .month)
            }
        case 1: // 前の月
            return photoController.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(-30*24*60*60), toGranularity: .month)
            }
        case 2: // すべての写真
            return photoController.photos
        default:
            return photoController.photos
        }
    }

    var body: some View {
        NavigationView {
            VStack {
                ScrollViewReader { proxy in
                    ZStack(alignment: .trailing) {
                        // MARK: - PhotoGrid
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(filteredPhotos.indices, id: \.self) { index in
                                    let photo = filteredPhotos[index]
                                    let isSelected = selectedPhotos.contains(index)
                                    
                                    ZStack(alignment: .topTrailing) {
                                        if let data = photo.imageData, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 100)
                                                .clipped()
                                                .cornerRadius(8)
                                                .overlay(
                                                    isSelected ? Color.blue.opacity(0.3).cornerRadius(8) : nil
                                                )
                                        } else {
                                            Color.gray.frame(height: 100).cornerRadius(8)
                                        }

                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.white)
                                                .padding(5)
                                        }
                                    }
                                    .id(index)
                                    .onTapGesture {
                                        if !selectedPhotos.isEmpty {
                                            if isSelected { selectedPhotos.remove(index) }
                                            else { selectedPhotos.insert(index) }
                                        } else {
                                            selectedIndex = index
                                        }
                                    }
                                }
                            }
                            .padding()
                        }

                        // MARK: - FastScrollBar
                        if showFastScroll {
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
                                                        let index = Int(ratio * CGFloat(max(filteredPhotos.count-1, 0)))
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
                        }

                        // MARK: - フルスクリーンスライダー
                        if let index = selectedIndex {
                            PhotoSliderView(
                                photoController: photoController,
                                folderController: folderController,
                                selectedIndex: index,
                                onClose: { selectedIndex = nil }
                            )
                            .zIndex(1)
                        }

                        // MARK: - フローティングボタン
                        VStack { Spacer()
                            HStack {
                                NavigationLink(destination: FolderListView(
                                        photoController: photoController,
                                        folderController: folderController)
                                ) {
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
        // Sheet や FullScreenCover は省略
        .sheet(isPresented: $showPicker) {
            PhotoPicker { images, assets in
                for (i, image) in images.enumerated() {
                    let creationDate = (i < assets.count) ? assets[i].creationDate ?? Date() : Date()
                    photoController.addPhoto(image, creationDate: creationDate)
                }
            }
        }
        .sheet(isPresented: $showFolderSheet) {
            FloatingButtonPanel(
                selectedPhotos: $selectedPhotos,
                showPicker: $showPicker,
                showSearch: $showSearch,
                showFolderSheet: $showFolderSheet,
                photoController: photoController,
                folderController: folderController
            )
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(controller: photoController, isPresented: $showSearch)
        }
        .fullScreenCover(isPresented: $showAlbum) {
            FolderListView(
                   photoController: photoController,
                   folderController: folderController)
        }
    }
}

//

// MARK: - FloatingButtonPanel
struct FloatingButtonPanel: View {
    @Binding var selectedPhotos: Set<Int>
    @Binding var showPicker: Bool
    @Binding var showSearch: Bool
    @Binding var showFolderSheet: Bool
    var photoController: PhotoController
    var folderController: FolderController

    var body: some View {
        VStack { Spacer()
            HStack {
                NavigationLink(destination:  FolderListView(
                    photoController: photoController,
                    folderController: folderController)) {
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

