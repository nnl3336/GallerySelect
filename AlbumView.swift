//
//  AlbumView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/18.
//

import SwiftUI

struct FolderListView: View {
    @ObservedObject var photoController: PhotoController
    @ObservedObject var folderController: FolderController
    @State private var selectedFolder: Folder? = nil

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(folderController.folders, id: \.self) { folder in
                        NavigationLink(destination: AlbumView(folder: folder,
                                                              photoController: photoController,
                                                              folderController: folderController
                                                             )) {
                            ZStack {
                                Color.gray.opacity(0.3)
                                    .cornerRadius(8)
                                Text(folder.name ?? "無名")
                                    .foregroundColor(.black)
                                    .padding()
                            }
                            .frame(height: 100)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("フォルダ一覧")
        }
    }
}

struct AlbumView: View {
    var folder: Folder
    @ObservedObject var photoController: PhotoController
    @ObservedObject var folderController: FolderController
    @State private var selectedIndex: Int? = nil

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(folder.photosArray.indices, id: \.self) { index in
                        let photo = folder.photosArray[index]
                        if let data = photo.imageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 100)
                                .clipped()
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectedIndex = index
                                }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(folder.name ?? "フォルダ")

            if let index = selectedIndex {
                PhotoSliderView(
                    photoController: photoController,
                    folderController: folderController,
                    photos: folder.photosArray,   // ← フォルダ内の写真配列
                    selectedIndex: index,
                    onClose: { selectedIndex = nil }
                )
                .zIndex(1)
            }
        }
    }
}


extension Folder {
    // NSSet を配列に変換して、作成日順でソート
    var photosArray: [Photo] {
        (photos?.allObjects as? [Photo])?.sorted {
            $0.creationDate ?? Date() < $1.creationDate ?? Date()
        } ?? []
    }
}


