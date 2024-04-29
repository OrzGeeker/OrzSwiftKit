//
//  File.swift
//  
//
//  Created by joker on 2023/2/6.
//

import Foundation

public struct CertbotNginxUbuntu: Certbot {
    
    public static func cert() {
        
        guard Platform.os() == .linux
        else {
            print("You should run this feature on Ubuntu Operating System!!!")
            return
        }
        
        installCertbot()
        
        checkSnapWorkCorrectly()
        
        ensureSnapUpdateToDate()
        
        removeCertbotAuto()
        
        installCertbot()
        
        prepareCertbotCommand()
    }
}

extension CertbotNginxUbuntu {
    /// [Install Snap On Ubuntu](https://snapcraft.io/docs/installing-snap-on-ubuntu)
    static func installSnapOnUbuntu() {
        // sudo apt update
        // sudo apt install snapd
    }
    
    static func checkSnapWorkCorrectly() {
        // $ sudo snap install hello-world
        // hello-world 6.4 from Canonical✓ installed
        // $ hello-world
        // Hello World!
    }
    
    static func ensureSnapUpdateToDate() {
        // sudo snap install core; sudo snap refresh core
    }
    
    static func removeCertbotAuto() {
        
    }
    
    static func installCertbot() {
        
    }
    
    static func prepareCertbotCommand() {
        
    }
    
    static func certNginx() {
        // sudo certbot --nginx
    }
    
    static func getCertsOnly() {
        // sudo certbot certonly --nginx
    }
}

extension String {

#if os(macOS)
    func exec() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = self.components(separatedBy: .whitespaces)
        try process.run()
        process.waitUntilExit()
        return process
    }
#endif
}
