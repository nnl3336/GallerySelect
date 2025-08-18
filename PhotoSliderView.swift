//
//  PhotoSliderView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/16.
//

import SwiftUI

struct PhotoSliderView: View {
    @ObservedObject var fetchController: PhotoController
    @State var selectedIndex: Int
    var onClose: () -> Void

    @State private var offset = CGSize.zero
    @State private var currentNote: String = ""
    @State private var currentLiked: Bool = false
    @State private var saveWorkItem: DispatchWorkItem?

    var body: some View {
        let photo = fetchController.photos[selectedIndex]

        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack {
                Image(uiImage: UIImage(data: photo.imageData!)!)
                    .resizable()
                    .scaledToFit()
                    .offset(y: offset.height)
                    .scaleEffect(1 - min(offset.height / 1000, 0.5))
                    .animation(.interactiveSpring(), value: offset)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                if abs(gesture.translation.width) < abs(gesture.translation.height) {
                                    offset = gesture.translation
                                }
                            }
                            .onEnded { _ in
                                if offset.height > 150 { saveAndClose() }
                                else { withAnimation(.spring()) { offset = .zero } }
                            }
                    )

                TextField("キャプションを入力", text: $currentNote)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .onChange(of: currentNote) { _ in
                        scheduleSave()
                    }

                Button(action: {
                    currentLiked.toggle()
                    scheduleSave()
                }) {
                    Image(systemName: currentLiked ? "heart.fill" : "heart")
                        .foregroundColor(.red)
                        .font(.title)
                }
                .padding(.bottom)
            }

            Button(action: saveAndClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .onAppear {
            currentNote = photo.note ?? ""
            currentLiked = photo.isLiked
        }
    }

    private func savePhoto() {
        let photo = fetchController.photos[selectedIndex]
        photo.note = currentNote
        photo.isLiked = currentLiked

        DispatchQueue.global(qos: .background).async {
            do {
                try fetchController.context.save()
                print("保存しました: \(photo.note ?? ""), いいね: \(photo.isLiked)")
            } catch {
                print("保存エラー: \(error)")
            }
        }
    }

    private func saveAndClose() {
        savePhoto()
        onClose()
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { savePhoto() }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem) // 1秒遅延で軽量化
    }
}
