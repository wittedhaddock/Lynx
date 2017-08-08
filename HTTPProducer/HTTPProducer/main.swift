//
//  main.swift
//  HTTPProducer
//
//  Created by James William Graham on 7/9/17.
//  Copyright © 2017 caffeine. All rights reserved.
//

import Foundation
import Lynx
let serv = try! HTTPServer { (re, client) in
    print("headers: \(re.headers) \n method: \(re.method) \nurl: \(re.url)")
    var data = [UInt8]()
    for (i, j) in re.body!.enumerated() {
        data.append(j)
    }
    try! client.send(data: [0])
}

try! serv.start()

