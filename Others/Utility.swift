//
//  Utility.swift
//  GallerySelect
//
//  Created by Yuki Sasaki on 2025/08/19.
//

import Foundation

struct DateUtils {
    static let photoLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"  // 年/月/日
        // formatter.dateFormat = "MM/dd"    // 年なしならこっち
        return formatter
    }()
    
    // 任意で短縮版
    static func string(from date: Date) -> String {
        return photoLabelFormatter.string(from: date)
    }
}
