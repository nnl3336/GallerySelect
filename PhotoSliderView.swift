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
    
    @State private var offset = CGSize.zero
    @State private var saveWorkItem: DispatchWorkItem?
    @StateObject private var vm = PhotoSliderViewModel()
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(fetchController.photos.indices, id: \.self) { index in
                    VStack {
                        GeometryReader { geo in
                            Image(uiImage: vm.cachedImage(for: index, photos: fetchController.photos))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .ignoresSafeArea(.all) // セーフエリアも含めて画面いっぱい
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
                        }
                        
                        TextField(
                            "キャプションを入力",
                            text: Binding(
                                get: { vm.localNotes[index] ?? fetchController.photos[index].note ?? "" },
                                set: { newValue in
                                    vm.localNotes[index] = newValue
                                    scheduleSave(index: index)
                                }
                            )
                        )
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        
                        Button(action: {
                            fetchController.photos[index].isLiked.toggle()
                            vm.localLikes[index] = fetchController.photos[index].isLiked
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
        photo.note = vm.localNotes[index] ?? photo.note
        photo.isLiked = vm.localLikes[index] ?? photo.isLiked
        
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
