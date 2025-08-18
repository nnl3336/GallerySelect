//
//  PhotoSliderView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/16.
//

import SwiftUI
import Combine

class PhotoSliderViewModel: ObservableObject {
    @Published var localNotes: [Int: String] = [:]
    @Published var localLikes: [Int: Bool] = [:]
    
    private(set) var imageCache: [Int: UIImage] = [:]
    
    func cachedImage(for index: Int, photos: [Photo]) -> UIImage {
        if let img = imageCache[index] { return img }
        if let data = photos[index].imageData, let img = UIImage(data: data) {
            imageCache[index] = img
            return img
        }
        return UIImage()
    }
}

struct PhotoSliderView: View {
    @ObservedObject var fetchController: PhotoController
    @State var selectedIndex: Int
    var onClose: () -> Void

    @State private var showOverlay = true  // ← オーバーレイ表示/非表示
    @State private var offset = CGSize.zero
    @StateObject private var vm = PhotoSliderViewModel()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(fetchController.photos.indices, id: \.self) { index in
                    GeometryReader { geo in
                        Image(uiImage: vm.cachedImage(for: index, photos: fetchController.photos))
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .onTapGesture {
                                withAnimation {
                                    showOverlay.toggle()  // ← タップでトグル
                                }
                            }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: showOverlay ? .always : .never))
            
            if showOverlay {
                Button(action: {
                    onClose()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                }
            }
        }
    }
}
