//
//  PhotoSliderView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/16.
//

import SwiftUI
import Combine

struct PhotoSliderView: View {
    var photos: [Photo]           // <- 外部から渡す
    @State var selectedIndex: Int
    var onClose: () -> Void

    @State private var showOverlay = true
    @State private var dragOffset = CGSize.zero
    @StateObject private var vm = PhotoSliderViewModel()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    GeometryReader { geo in
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .foregroundColor(.white)

                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: showOverlay ? .always : .never))
            
            if showOverlay {
                Button(action: { onClose() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                }
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    if abs(value.translation.height) > 150 {
                        withAnimation(.spring()) {
                            onClose()
                        }
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = .zero
                        }
                    }
                }
        )
    }

    private func scaleForDrag() -> CGFloat {
        let maxOffset: CGFloat = 500
        let offsetY = min(abs(dragOffset.height), maxOffset)
        let scale = 1 - (offsetY / maxOffset) * 0.5
        return max(scale, 0.5)
    }
}

//

