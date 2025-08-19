//
//  PhotoSliderView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/16.
//

import SwiftUI
import Combine

struct PhotoSliderView: View {
    @Binding var selectedIndex: Int?
    @Binding var photos: [Photo]
    var namespace: Namespace.ID

    var body: some View {
        if let selectedIndex {
            TabView(selection: $selectedIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    PhotoDetailView(
                        selectedIndex: $selectedIndex,
                        photo: $photos[index],
                        namespace: index == selectedIndex ? namespace : Namespace().wrappedValue
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color.black.opacity(0.9))
            .ignoresSafeArea()
        }
    }
}


struct PhotoDetailView: View {
    @Binding var selectedIndex: Int?
    @Binding var photo: Photo
    var namespace: Namespace.ID

    @State private var offsetY: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack {
                Spacer()

                if let data = photo.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .matchedGeometryEffect(id: photo.id, in: namespace)
                        .offset(y: offsetY)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offsetY = value.translation.height
                                }
                                .onEnded { value in
                                    if value.translation.height > 150 {
                                        withAnimation(.spring()) {
                                            selectedIndex = nil
                                            offsetY = 0
                                        }
                                    } else {
                                        withAnimation(.spring()) {
                                            offsetY = 0
                                        }
                                    }
                                }
                        )
                }
                // キャプション
                TextField("キャプションを入力", text: Binding(
                    get: { photo.note ?? "" },
                    set: { photo.note = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // 閉じるボタン
            Button(action: {
                withAnimation(.spring()) {
                    selectedIndex = nil
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .transition(.opacity)
        .zIndex(1)
    }
}

//

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
