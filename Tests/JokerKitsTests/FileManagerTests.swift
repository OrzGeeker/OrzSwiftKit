//
//  FileManagerTests.swift
//
//
//  Created by joker on 2022/10/9.
//

import Foundation
import Testing

@testable import JokerKits

@Suite
class FileManagerTests {
    
    private let tempTestDir = NSString.path(withComponents: [
        NSTemporaryDirectory(),
        "test",
        UUID().uuidString,
    ])
    
    private func deleteTempTestDirIfExist() throws {
        // 如果有之前用过的测试目录，先删除
        if tempTestDir.isDirPath() {
            try FileManager.default.removeItem(atPath: tempTestDir)
        }
    }
    
    init() throws {
        try deleteTempTestDirIfExist()
    }
    
    deinit {
        try? deleteTempTestDirIfExist()
    }
    
    @Test
    func makeDir() throws {
        let path = NSString.path(withComponents: [
            tempTestDir,
            "dir",
        ])
        try path.makeDirIfNeed()
        #expect(path.isDirPath(), "make dir failed!")
    }
    
    @Test
    func moveDir() throws {
        let originPath = NSString.path(withComponents: [
            tempTestDir,
            "origin",
        ])
        try originPath.makeDirIfNeed()
        
        let targetPath = NSString.path(withComponents: [
            tempTestDir,
            "target",
        ])
        
        try FileManager.moveFile(fromFilePath: originPath, toFilePath: targetPath, overwrite: true)
        #expect(!originPath.isExist())
        #expect(targetPath.isExist() && targetPath.isDirPath())
    }
    
    @Test
    func allSubDir() throws {
        try ["first", "second"]
            .map { NSString.path(withComponents: [tempTestDir, $0]) }
            .forEach { try $0.makeDirIfNeed() }
        
        let dirs = try FileManager.allSubDir(in: tempTestDir)
        #expect(dirs?.count == 2)
    }
    
    @Test
    func allFiles() throws {
        let notExistTxtDir = NSString.path(withComponents: [
            tempTestDir,
            "noTxtDir",
        ])
        try notExistTxtDir.makeDirIfNeed()
        
        let noTxtFiles = FileManager.allFiles(in: notExistTxtDir, ext: "txt")
        #expect(noTxtFiles?.count == 0)
        
        let existTxtDir = NSString.path(withComponents: [
            tempTestDir,
            "txtDir",
        ])
        try existTxtDir.makeDirIfNeed()
        let txtFilePath = NSString.path(withComponents: [
            existTxtDir,
            "txtTestFile.txt",
        ])
        FileManager.default.createFile(
            atPath: txtFilePath, contents: "Just A Test File".data(using: .utf8))
        
        let txtFiles = FileManager.allFiles(in: existTxtDir, ext: "txt")
        #expect(txtFiles?.count == 1)
    }
    
    @Test
    func testMakeDirIfNotExist() throws {
        let testDirPath = NSString.path(withComponents: [
            tempTestDir,
            "testDir",
        ])
        if FileManager.default.fileExists(atPath: testDirPath) {
            try FileManager.default.removeItem(atPath: testDirPath)
        }
        #expect(testDirPath.isDirPath() == false)
        try testDirPath.makeDirIfNeed()
        #expect(testDirPath.isDirPath() == true)
    }
}
