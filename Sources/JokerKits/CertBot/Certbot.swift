//
//  Certbot.swift
//  
//
//  Created by joker on 2022/10/19.
//

import Foundation

/// [Certbot Doc](https://eff-certbot.readthedocs.io/en/stable/index.html)
/// [Snap](https://certbot.eff.org/instructions)
public protocol Certbot {
    static func cert()
}
