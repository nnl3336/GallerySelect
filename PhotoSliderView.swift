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
                    Image(uiImage: photos[index])
                        .resizable()
                        .scaledToFit()
                        .tag(index)
                        .offset(y: offset.height)
                        .scaleEffect(1 - min(offset.height / 1000, 0.5))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    if gesture.translation.height > 0 {
                                        offset = gesture.translation
                                    }
                                }
                                .onEnded { gesture in
                                    if gesture.translation.height > 150 {
                                        onClose()
                                    } else {
                                        withAnimation(.spring()) {
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}
