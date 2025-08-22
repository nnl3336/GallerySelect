//
//  Photo+CoreDataProperties.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/22.
//
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var creationDate: Date?
    @NSManaged public var currentDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var imageData: Data?
    @NSManaged public var imageURL: String?
    @NSManaged public var isLiked: Bool
    @NSManaged public var modificationDate: Date?
    @NSManaged public var note: String?
    
    @NSManaged public var folder: Folder?

}

extension Photo : Identifiable {

}
