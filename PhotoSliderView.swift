//
//  PhotoSliderView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/16.
//

import SwiftUI

struct PhotoSliderView: View {
    @ObservedObject var fetchController: PhotoController // ←追加
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
                    VStack {
                        Image(uiImage: UIImage(data: fetchController.photos[index].imageData!)!)
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
                            get: { localNotes[index] ?? fetchController.photos[index].note ?? "" },
                            set: { newValue in
                                localNotes[index] = newValue
                                scheduleSave(index: index) // 入力中は非同期で遅延保存
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)

                        Button(action: {
                            fetchController.photos[index].isLiked.toggle()
                            scheduleSave(index: index)
                        }) {
                            Image(systemName: fetchController.photos[index].isLiked ? "heart.fill" : "heart")
                                .foregroundColor(.red)
                                .font(.title)
                        }
                        .padding(.bottom)
                    }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
    }
}
