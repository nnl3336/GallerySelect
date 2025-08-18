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
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(controller.photos.indices, id: \.self) { index in
                    if let imageData = controller.photos[index].imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("アルバム")
    }
}
