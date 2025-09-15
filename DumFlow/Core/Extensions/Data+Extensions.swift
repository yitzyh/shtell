
//
//  Data+Extensuons.swift
//  DumFlow
//
//  Created by Isaac Herskowitz on 4/25/25.
//
import Foundation
import UIKit

extension Data {
  var uiImage: UIImage? { UIImage(data: self) }
}
