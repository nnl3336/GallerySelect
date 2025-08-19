//
//  AlbumView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/18.
//

import SwiftUI

struct FolderListView: View {
    @ObservedObject var controller: PhotoController
    @State private var selectedFolder: Folder? = nil

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(controller.folders, id: \.self) { folder in
                        NavigationLink(destination: AlbumView(folder: folder, controller: controller)) {
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


// MARK: - AlbumView（仮）
struct AlbumView: View {
    var folder: Folder
    @ObservedObject var controller: PhotoController
    @State private var selectedIndex: Int? = nil

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    @Namespace private var namespace

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

            // スライダー表示
            // MainView の拡大スライダー呼び出し
            // MainView の拡大スライダー呼び出し
            PhotoSliderView(
                selectedIndex: $selectedIndex,
                photos: .constant(folder.photosArray),
                namespace: namespace
            )
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


// 写真セルを別Viewに切り出し
struct PhotoCell: View {
    var photo: Photo
    var cachedImage: UIImage
    
    var body: some View {
        Image(uiImage: cachedImage)
            .resizable()
            .scaledToFill()
    }
}
