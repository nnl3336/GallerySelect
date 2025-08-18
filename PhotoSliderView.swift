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
    @State private var saveWorkItem: DispatchWorkItem?

    @State private var localNotes: [Int: String] = [:]
    @State private var localLikes: [Int: Bool] = [:]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.8).ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(fetchController.photos.indices, id: \.self) { index in
                    PhotoSliderPageView(
                        photo: fetchController.photos[index],
                        index: index,
                        localNotes: $localNotes,
                        localLikes: $localLikes,
                        scheduleSave: scheduleSave,
                        offset: $offset
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .onChange(of: selectedIndex) { oldIndex in
                saveCaptionAndLike(at: oldIndex)
            }

            Button(action: saveAndClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }

    private func saveCaptionAndLike(at index: Int) {
        guard index < fetchController.photos.count else { return }
        let photo = fetchController.photos[index]

        photo.note = localNotes[index] ?? photo.note
        photo.isLiked = localLikes[index] ?? photo.isLiked

        do {
            try fetchController.context.save()
            print("保存しました: \(photo.note ?? ""), いいね: \(photo.isLiked) （インデックス \(index)）")
        } catch {
            print("保存エラー: \(error)")
        }
    }

    private func saveAndClose() {
        saveCaptionAndLike(at: selectedIndex)
        onClose()
    }

    private func scheduleSave(index: Int) {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { saveCaptionAndLike(at: index) }
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }
}

// MARK: - ページごとの View に分割
struct PhotoSliderPageView: View {
    var photo: Photo
    var index: Int
    @Binding var localNotes: [Int: String]
    @Binding var localLikes: [Int: Bool]
    var scheduleSave: (Int) -> Void
    @Binding var offset: CGSize

    var body: some View {
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
                            if offset.height > 150 {
                                // 親で閉じる
                                offset = .zero
                            } else {
                                withAnimation(.spring()) { offset = .zero }
                            }
                        }
                )

            let noteBinding = Binding<String>(
                get: { localNotes[index] ?? photo.note ?? "" },
                set: { newValue in
                    localNotes[index] = newValue
                    scheduleSave(index)
                }
            )

            TextField("キャプションを入力", text: noteBinding)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            Button(action: {
                localLikes[index] = !(localLikes[index] ?? photo.isLiked)
                photo.isLiked = localLikes[index]!
                scheduleSave(index)
            }) {
                Image(systemName: (localLikes[index] ?? photo.isLiked) ? "heart.fill" : "heart")
                    .foregroundColor(.red)
                    .font(.title)
            }
            .padding(.bottom)
        }
        .onAppear {
            if localNotes[index] == nil { localNotes[index] = photo.note ?? "" }
            if localLikes[index] == nil { localLikes[index] = photo.isLiked }
        }
    }
}
