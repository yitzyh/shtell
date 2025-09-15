//
//  Date+Extensions.swift.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 11/2/24.
//

import Foundation

extension Date {
    func timeAgoShort() -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.minute, .hour, .day, .weekOfMonth, .month, .year]
        formatter.maximumUnitCount = 1

        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "Now"
        }

        return formatter.string(from: self, to: now) ?? "Now"
//        return String(self.timeIntervalSince1970)
    }
}
