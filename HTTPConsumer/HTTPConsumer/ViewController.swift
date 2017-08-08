//
//  ViewController.swift
//  HTTPConsumer
//
//  Created by James William Graham on 7/9/17.
//  Copyright © 2017 caffeine. All rights reserved.
//

import UIKit
import Lynx
class ViewController: UIViewController {

    let server = try! HTTPServer(hostname: "127.0.0.1", port: 8080) { (re, client) in

    }
    override func viewDidLoad() {
        do {
            try server.start()
        }
        catch (let error) {
            print("caught error \(error)")
        }
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

