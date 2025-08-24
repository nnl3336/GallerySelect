//
//  PhotoDetailViewController.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/24.
//

import SwiftUI

class DraggablePhotoViewController: UIViewController {
    let imageView = UIImageView()
    var photo: Photo
    var onClose: (() -> Void)?

    private var originalCenter: CGPoint = .zero

    init(photo: Photo) {
        self.photo = photo
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupImageView()
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

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        imageView.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)

        switch gesture.state {
        case .began:
            originalCenter = imageView.center
        case .changed:
            imageView.center = CGPoint(x: originalCenter.x + translation.x,
                                       y: originalCenter.y + translation.y)
            let progress = min(abs(translation.y)/300,1)
            let scale = 1 - (0.5*progress)
            imageView.transform = CGAffineTransform(scaleX: scale, y: scale)
        case .ended, .cancelled:
            if translation.y > 150 {
                UIView.animate(withDuration: 0.3, animations: {
                    self.imageView.transform = CGAffineTransform(scaleX:0.1, y:0.1)
                    self.imageView.center = CGPoint(x:self.originalCenter.x, y:self.view.bounds.height+200)
                }) { _ in
                    self.onClose?()
                }
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.imageView.center = self.originalCenter
                    self.imageView.transform = .identity
                }
            }
        default: break
        }
    }
}

class PhotoDetailViewController: UIPageViewController, UIPageViewControllerDataSource {

    private var photos: [Photo]
    private var currentIndex: Int

    var onClose: (() -> Void)?

    init(photos: [Photo], startIndex: Int = 0) {
        self.photos = photos
        self.currentIndex = startIndex
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        modalPresentationStyle = .overFullScreen
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self

        setViewControllers([photoVC(at: currentIndex)], direction: .forward, animated: false)
    }

    private func photoVC(at index: Int) -> DraggablePhotoViewController {
        let vc = DraggablePhotoViewController(photo: photos[index])
        vc.onClose = { [weak self] in self?.dismiss(animated: true, completion: self?.onClose) }
        return vc
    }

    // MARK: - UIPageViewControllerDataSource

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard currentIndex > 0 else { return nil }
        return photoVC(at: currentIndex - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard currentIndex < photos.count - 1 else { return nil }
        return photoVC(at: currentIndex + 1)
    }
}
