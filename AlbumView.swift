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
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                ForEach(controller.photos.indices, id: \.self) { index in
                    if let imageData = controller.photos[index].imageData,
                       let uiImage = UIImage(data: imageData) {
                        HStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipped()
                                .cornerRadius(8)
                            
                            Text(controller.photos[index].note ?? "キャプションなし")
                        }
                    }
                }
            }
            .navigationTitle("アルバム")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { isPresented = false }
                }
            }
        }
    }
}
