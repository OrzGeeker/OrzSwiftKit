//
//  FileManagerTests.swift
//  
//
//  Created by joker on 2022/10/9.
//

import XCTest
@testable import JokerKits

final class FileManagerTests: XCTestCase {
    
    private let tempTestDir = NSString.path(withComponents: [
        NSTemporaryDirectory(),
        "test"
    ])
    
    private func deleteTempTestDirIfExist() throws {
        // 如果有之前用过的测试目录，先删除
        if tempTestDir.isDirPath() {
            try FileManager.default.removeItem(atPath: tempTestDir)
        }
    }
    
    override func setUpWithError() throws {
        try deleteTempTestDirIfExist()
    }

    override func tearDownWithError() throws {
        try deleteTempTestDirIfExist()
    }
    
    
    func testMakeDir() throws {
        let path = NSString.path(withComponents: [
            tempTestDir,
            "dir"
        ])
        try path.makeDirIfNeed()
        XCTAssertTrue(path.isDirPath())
    }
    
    func testMoveDir() throws {
        let originPath = NSString.path(withComponents: [
            tempTestDir,
            "origin"
        ])
        try originPath.makeDirIfNeed()
        
        let targetPath = NSString.path(withComponents: [
            tempTestDir,
            "target"
        ])
        
        try FileManager.moveFile(fromFilePath: originPath, toFilePath: targetPath, overwrite: true)
        XCTAssertFalse(originPath.isExist())
        XCTAssertTrue(targetPath.isExist() && targetPath.isDirPath())
    }

    func testAllSubDir() throws {
        try ["first","second"]
            .map { NSString.path(withComponents: [tempTestDir, $0]) }
            .forEach { try $0.makeDirIfNeed() }
        
        let dirs = try FileManager.allSubDir(in: tempTestDir)
        XCTAssertTrue(dirs?.count == 2)
    }

    func testAllFiles() throws {
        let notExistTxtDir = NSString.path(withComponents: [
            tempTestDir,
            "noTxtDir"
        ])
        try notExistTxtDir.makeDirIfNeed()
        
        let noTxtFiles = FileManager.allFiles(in: notExistTxtDir, ext: "txt")
        XCTAssertTrue(noTxtFiles?.count == 0)
        


        let existTxtDir = NSString.path(withComponents: [
            tempTestDir,
            "txtDir"
        ])
        try existTxtDir.makeDirIfNeed()
        let txtFilePath = NSString.path(withComponents: [
            existTxtDir,
            "txtTestFile.txt"
        ])
        FileManager.default.createFile(atPath: txtFilePath, contents: "Just A Test File".data(using: .utf8))

        let txtFiles = FileManager.allFiles(in: existTxtDir, ext: "txt")
        XCTAssertTrue(txtFiles!.count == 1)
    }
}
