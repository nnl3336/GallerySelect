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
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.8).ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(fetchController.photos.indices, id: \.self) { index in
                    let photo = fetchController.photos[index]
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

                        TextField("キャプションを入力", text: Binding(
                            get: { index == selectedIndex ? currentNote : photo.note ?? "" },
                            set: { newValue in
                                if index == selectedIndex { currentNote = newValue }
                                scheduleSave()
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                        Button(action: {
                            if index == selectedIndex { currentLiked.toggle() }
                            scheduleSave()
                        }) {
                            Image(systemName: (index == selectedIndex ? currentLiked : photo.isLiked) ? "heart.fill" : "heart")
                                .foregroundColor(.red)
                                .font(.title)
                        }
                        .padding(.bottom)
                    }
                    .tag(index)
                    .onAppear {
                        if index == selectedIndex {
                            currentNote = photo.note ?? ""
                            currentLiked = photo.isLiked
                        }
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .onChange(of: selectedIndex) { _ in
                savePhoto()
            }

            Button(action: saveAndClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }

    private func savePhoto() {
        guard fetchController.photos.indices.contains(selectedIndex) else { return }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }
}
