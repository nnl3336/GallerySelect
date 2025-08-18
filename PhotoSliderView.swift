//
//  PhotoSliderView.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/16.
//

import SwiftUI
import Combine

struct PhotoSliderView: View {
    @ObservedObject var fetchController: PhotoController
    @State var selectedIndex: Int
    var onClose: () -> Void

    @State private var offset = CGSize.zero
    @State private var localNotes: [Int: String] = [:]
    @State private var localLikes: [Int: Bool] = [:]
    @State private var cancellables = Set<AnyCancellable>()

    // 保存用 PassthroughSubject
    private let saveSubject = PassthroughSubject<Int, Never>()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.8).ignoresSafeArea()

            TabView(selection: $selectedIndex) {
                ForEach(fetchController.photos.indices, id: \.self) { index in
                    VStack {
                        // 画像は事前生成されたサムネイルを使う想定
                        Image(uiImage: fetchController.photos[index].thumbnail!)
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
                            get: { localNotes[index] ?? "" },
                            set: { newValue in
                                localNotes[index] = newValue
                                saveSubject.send(index)
                            }
                        ))

                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onAppear {
                            if localNotes[index] == nil {
                                localNotes[index] = fetchController.photos[index].note ?? ""
                            }
                        }

                        Button(action: {
                            localLikes[index] = !(localLikes[index] ?? fetchController.photos[index].isLiked)
                            fetchController.photos[index].isLiked = localLikes[index]!
                            saveSubject.send(index)
                        }) {
                            Image(systemName: (localLikes[index] ?? fetchController.photos[index].isLiked) ? "heart.fill" : "heart")
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
            .onAppear {
                setupDebouncedSave()
            }

            Button(action: saveAndClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }

    // MARK: - 保存処理

    private func setupDebouncedSave() {
        saveSubject
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { index in
                saveCaptionAndLike(at: index)
            }
            .store(in: &cancellables)
    }

    private func saveCaptionAndLike(at index: Int) {
        guard index < fetchController.photos.count else { return }
        let photo = fetchController.photos[index]
        photo.note = localNotes[index] ?? photo.note
        photo.isLiked = localLikes[index] ?? photo.isLiked

        do {
            try fetchController.context.save()
            print("保存: \(photo.note ?? ""), いいね: \(photo.isLiked) (index \(index))")
        } catch {
            print("保存エラー: \(error)")
        }
    }

    private func saveAndClose() {
        saveCaptionAndLike(at: selectedIndex)
        onClose()
    }
}
