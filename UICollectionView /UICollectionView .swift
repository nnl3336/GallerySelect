//
//  UICollectionView .swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/20.
//

import SwiftUI


// MARK: - SwiftUI MainView
struct MainView: View {
    @ObservedObject var photocontroller: PhotoController
    @ObservedObject var foldercontroller: FolderController

    @ObservedObject var selectionManager: PhotoSelectionManager   // ← 追加

    @State private var selectedIndex: Int? = nil
    @State private var selectedPhotos: Set<Int> = []
    @State private var showPicker: Bool = false
    @State private var showSearch: Bool = false
    @State private var showFolderSheet: Bool = false
    @State private var showAlbum: Bool = false
    @State private var segmentSelection: Int = 2
    @State private var showFastScroll: Bool = false
    @State private var dragPosition: CGFloat = 0

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    let segments = ["後ろの月", "前の月", "すべての写真"]

    // MARK: - フィルタリング・グループ化
    var filteredPhotos: [Photo] {
        switch segmentSelection {
        case 0: // 後ろの月
            return photocontroller.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(30*24*60*60), toGranularity: .month)
            }
        case 1: // 前の月
            return photocontroller.photos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return Calendar.current.isDate(date, equalTo: Date().addingTimeInterval(-30*24*60*60), toGranularity: .month)
            }
        default: // すべての写真
            return photocontroller.photos
        }
    }

    var groupedByMonth: [String: [Photo]] {
        Dictionary(grouping: filteredPhotos) { photo in
            let date = photo.creationDate ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM"
            return formatter.string(from: date)
        }
    }

    var monthStartIndex: [String: Int] {
        var dict: [String: Int] = [:]
        let sortedMonths = groupedByMonth.keys.sorted(by: >)
        for month in sortedMonths {
            if let firstPhoto = groupedByMonth[month]?.first,
               let index = filteredPhotos.firstIndex(of: firstPhoto) {
                dict[month] = index
            }
        }
        return dict
    }

    func scrollIndex(fromDrag value: CGFloat, totalHeight: CGFloat) -> Int {
        let y = min(max(value, 0), totalHeight)
        let ratio = y / totalHeight
        return Int(ratio * CGFloat(max(filteredPhotos.count-1, 0)))
    }

    var body: some View {
        NavigationView {
            VStack {
                ScrollViewReader { proxy in
                    ZStack(alignment: .trailing) {
                        GeometryReader { geo in
                            PhotoView(
                                photocontroller: photocontroller,
                                selectionManager: selectionManager  // ← 追加
                            )
                            .frame(width: geo.size.width, height: geo.size.height)
                        }

                        if showFastScroll {
                            VStack {
                                Spacer()
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 30, height: 150)
                                    .cornerRadius(15)
                                    .overlay(
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 30, height: 30)
                                            .offset(y: dragPosition)
                                            .gesture(
                                                DragGesture()
                                                    .onChanged { value in
                                                        dragPosition = value.location.y - 75
                                                        let index = scrollIndex(fromDrag: value.location.y, totalHeight: 150)
                                                        withAnimation(.linear(duration: 0.05)) {
                                                            proxy.scrollTo(index, anchor: .top)
                                                        }
                                                    }
                                            )
                                    )
                                Spacer()
                            }
                            .frame(width: 40)
                            .padding(.trailing, 8)
                        }

                        if let index = selectionManager.selectedIndex {
                            PhotoSliderView(
                                fetchController: photocontroller,
                                selectedIndex: index,
                                onClose: { selectionManager.selectedIndex = nil }
                            )
                            .zIndex(1)
                        }

                        FloatingButtonPanel(
                            selectedPhotos: $selectedPhotos,
                            showPicker: $showPicker,
                            showSearch: $showSearch,
                            showFolderSheet: $showFolderSheet,
                            photocontroller: photocontroller,       // ← PhotoController を渡す
                            foldercontroller: foldercontroller // ← FolderController を渡す
                        )


                    }
                    .onAppear {
                        if let lastIndex = filteredPhotos.indices.last {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }

                    if selectedIndex == nil {
                        Picker("", selection: $segmentSelection) {
                            ForEach(0..<segments.count, id: \.self) { i in
                                Text(segments[i])
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        .background(.ultraThinMaterial)
                        .onChange(of: segmentSelection) { newValue in
                            let month = segments[newValue]
                            if let index = monthStartIndex[month] {
                                withAnimation { proxy.scrollTo(index, anchor: .top) }
                            } else if month == "すべての写真" {
                                proxy.scrollTo(0, anchor: .top)
                            }
                        }
                    }
                }

                if !selectedPhotos.isEmpty {
                    HStack {
                        Spacer()
                        Button("cancel") { selectedPhotos.removeAll() }
                            .padding(.leading)
                        Spacer()
                    }
                }
            }
            .navigationTitle("写真")
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            PhotoPicker { images, assets in
                for (i, image) in images.enumerated() {
                    let creationDate = (i < assets.count) ? assets[i].creationDate ?? Date() : Date()
                    photocontroller.addPhoto(image, creationDate: creationDate)
                }
            }
        }
        .sheet(isPresented: $showFolderSheet) {
            FolderSheetView(
                isPresented: $showFolderSheet,
                selectedPhotos: .constant([]),
                photos: photocontroller.photos
            )
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView(controller: photocontroller, isPresented: $showSearch)
        }
        .fullScreenCover(isPresented: $showAlbum) {
            FolderListView(photocontroller: photocontroller, foldercontroller: foldercontroller)
        }
    }
}

// MARK: - PhotoView (UICollectionView wrapped)
struct PhotoView: UIViewRepresentable {
    @ObservedObject var photocontroller: PhotoController
    @ObservedObject var selectionManager: PhotoSelectionManager   // ← 追加

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        layout.scrollDirection = .vertical

        // 3列で画面幅に収める
        let numberOfColumns: CGFloat = 3
        let totalSpacing = layout.minimumInteritemSpacing * (numberOfColumns - 1)
        let width = (UIScreen.main.bounds.width - totalSpacing) / numberOfColumns
        layout.itemSize = CGSize(width: width, height: width)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.allowsMultipleSelection = true
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        return collectionView
    }



    func updateUIView(_ uiView: UICollectionView, context: Context) {
        uiView.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, controller: photocontroller)
    }

    // MARK: - Coordinator
    // MARK: - Coordinator
    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        var parent: PhotoView
        var controller: PhotoController

        init(parent: PhotoView, controller: PhotoController) {
            self.parent = parent
            self.controller = controller
        }

        // MARK: - 長押しで最初の選択
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let collectionView = gesture.view as? UICollectionView else { return }

            let point = gesture.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: point) {
                let photo = controller.photos[indexPath.item]
                guard let id = photo.id else { return } // UUID を取得

                // 選択状態に追加
                parent.selectionManager.selectedPhotos.insert(id)
                collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
            }
        }

        // MARK: - タップで選択/解除
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let photo = controller.photos[indexPath.item]
            guard let id = photo.id else { return }

            if parent.selectionManager.selectedPhotos.contains(id) {
                // 既に選択済みなら解除
                parent.selectionManager.selectedPhotos.remove(id)
                collectionView.deselectItem(at: indexPath, animated: true)
            } else {
                // 選択に追加
                parent.selectionManager.selectedPhotos.insert(id)
            }

            print("Selected photos: \(parent.selectionManager.selectedPhotos)")
        }

        // MARK: - UICollectionViewDataSource
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            controller.photos.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
            let photo = controller.photos[indexPath.item]
            cell.configure(with: photo)
            return cell
        }
    }
}

// MARK: - UICollectionViewCell
class PhotoCell: UICollectionViewCell {
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with photo: Photo) {
        if let data = photo.imageData, let uiImage = UIImage(data: data) {
            imageView.image = uiImage
        } else {
            imageView.image = nil
        }
    }
}


class PhotoCollectionViewController: UICollectionViewController {

    var photos: [Photo] = []

    init() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 5
        super.init(collectionViewLayout: layout)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .white
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.allowsMultipleSelection = true
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        cell.configure(with: photos[indexPath.item])
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Selected photo at \(indexPath.item)")
    }
}
