//
//  PhotoDetailViewController.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/24.
//

import SwiftUI


struct PhotoGridView: View {
    let photos: [Photo]
    @Binding var selectedIndex: Int?
    var onClose: (() -> Void)?

    @State private var dragOffset: CGSize = .zero

    @ObservedObject var photoFRCController: PhotoFRCController

    var body: some View {
        ZStack {
            // 1️⃣ サムネイル一覧
            ScrollView {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 3)) {
                    ForEach(photos.indices, id: \.self) { index in
                        if let data = photos[index].imageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 100)
                                .clipped()
                                .onTapGesture {
                                    selectedIndex = index // タップしたら拡大
                                }
                        }
                    }
                }
                .padding()
            }

            // 2️⃣ フルスクリーンページャー
            if let selectedIndex = selectedIndex {
                PhotoDetailPager(
                    photos: photos,
                    selectedIndex: Binding(
                        get: { selectedIndex },
                        set: { self.selectedIndex = $0 }
                    ),
                    onClose: {
                        self.selectedIndex = nil
                    }
                )
                .transition(.opacity)
            }
        }
    }
}

struct PhotoDetailPager: View {
    let photos: [Photo]
    @Binding var selectedIndex: Int
    var onClose: (() -> Void)?

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selectedIndex) {
                ForEach(photos.indices, id: \.self) { index in
                    if let data = photos[index].imageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                            .ignoresSafeArea()
                            .offset(dragOffset)
                            .scaleEffect(scaleForDrag(dragOffset))
                            .highPriorityGesture(
                                DragGesture()
                                    .onChanged { value in
                                        if abs(value.translation.height) > abs(value.translation.width) {
                                            dragOffset = value.translation
                                        }
                                    }
                                    .onEnded { value in
                                        if value.translation.height > 150 ||
                                            value.predictedEndTranslation.height > 250 {
                                            onClose?()
                                        }
                                        dragOffset = .zero
                                    }
                            )
                            .animation(.spring(), value: dragOffset)
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

            Button(action: { onClose?() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .background(Color.black.opacity(backgroundAlpha))
        .ignoresSafeArea()
    }

    private func scaleForDrag(_ offset: CGSize) -> CGFloat {
        let progress = min(max(offset.height / 300, 0), 1)
        return 1 - (0.5 * progress)
    }

    private var backgroundAlpha: Double {
        let progress = min(max(dragOffset.height / 300, 0), 1)
        return Double(0.9 * (1 - progress))
    }
}




/*class PhotoDetailViewController: UIViewController {

    private let imageView = UIImageView()
    private var photo: Photo
    private var originalCenter: CGPoint = .zero

    var onClose: (() -> Void)?

    init(photo: Photo) {
        self.photo = photo
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        setupImageView()
        setupCloseButton()
    }

    private func setupImageView() {
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true

        if let data = photo.imageData, let uiImage = UIImage(data: data) {
            imageView.image = uiImage
        }

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // ドラッグジェスチャー
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        imageView.addGestureRecognizer(pan)
    }

    private func setupCloseButton() {
        let button = UIButton(type: .system)
        button.setTitle("Close", for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: onClose)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)

        switch gesture.state {
        case .began:
            originalCenter = imageView.center
        case .changed:
            imageView.center = CGPoint(x: originalCenter.x + translation.x,
                                       y: originalCenter.y + translation.y)

            // 下方向に動かすほど縮小させる
            let progress = min(abs(translation.y) / 300, 1)
            let scale = 1 - (0.5 * progress)
            imageView.transform = CGAffineTransform(scaleX: scale, y: scale)
            view.backgroundColor = UIColor.black.withAlphaComponent(0.9 * (1 - progress))
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view)
            if translation.y > 150 || velocity.y > 500 {
                // 閾値を超えたら縮小して閉じる
                UIView.animate(withDuration: 0.3, animations: {
                    self.imageView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                    self.imageView.center = CGPoint(x: self.originalCenter.x,
                                                    y: self.view.bounds.height + 200)
                    self.view.backgroundColor = .clear
                }) { _ in
                    self.dismiss(animated: false, completion: self.onClose)
                }
            } else {
                // 元に戻す
                UIView.animate(withDuration: 0.3) {
                    self.imageView.center = self.originalCenter
                    self.imageView.transform = .identity
                    self.view.backgroundColor = UIColor.black.withAlphaComponent(0.9)
                }
            }
        default:
            break
        }
    }
}

struct PhotoDetailView: UIViewControllerRepresentable {
    let photo: Photo
    var onClose: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> PhotoDetailViewController {
        let vc = PhotoDetailViewController(photo: photo)
        vc.onClose = onClose
        return vc
    }

    func updateUIViewController(_ uiViewController: PhotoDetailViewController, context: Context) {
        // 更新処理は特に必要なければ空
    }
}
*/
