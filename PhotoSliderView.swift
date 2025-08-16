//
//  PhotoSliderView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/16.
//

import SwiftUI

struct PhotoSliderView: View {
    let photos: [UIImage]
    @State var selectedIndex: Int
    var onClose: () -> Void
    @State private var offset = CGSize.zero
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    ZStack {
                        Image(uiImage: photos[index])
                            .resizable()
                            .scaledToFit()
                            .offset(y: offset.height)
                            .scaleEffect(1 - min(offset.height / 1000, 0.5))
                            .animation(.interactiveSpring(), value: offset)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            // 上にドラッグ用のジェスチャを追加
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if abs(gesture.translation.width) < abs(gesture.translation.height) {
                            offset = gesture.translation
                        }
                    }
                    .onEnded { gesture in
                        if offset.height > 150 {
                            onClose()
                        } else {
                            withAnimation(.spring()) {
                                offset = .zero
                            }
                        }
                    }
            )
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}
