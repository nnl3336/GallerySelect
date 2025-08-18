//
//  AlbumView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/18.
//

import SwiftUI

// MARK: - AlbumView（仮）
struct AlbumView: View {
    @ObservedObject var controller: PhotoController
    
    // 画像キャッシュ用
    @State private var imageCache: [Int: UIImage] = [:]
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(controller.photos.indices, id: \.self) { index in
                    PhotoCell(photo: controller.photos[index], cachedImage: cachedImage(for: index))
                        .frame(height: 100)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture {
                            print("写真 \(index) タップ")
                            // 必要なら選択やスライダー表示を追加
                        }
                }
            }
            .padding()
        }
        .navigationTitle("アルバム")
    }
    
    // キャッシュを利用して UIImage を取得
    private func cachedImage(for index: Int) -> UIImage {
        if let img = imageCache[index] { return img }
        if let data = controller.photos[index].imageData,
           let img = UIImage(data: data) {
            imageCache[index] = img
            return img
        }
        return UIImage()
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
