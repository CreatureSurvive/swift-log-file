//
//  FileHandlerOutputStream.swift
//  
//
//  Created by Dana Buehre on 12/8/23.
//

import Foundation

// Adapted from https://nshipster.com/textoutputstream/
public struct FileHandlerOutputStream: TextOutputStream {
    enum FileHandlerOutputStream: Error {
        case couldNotCreateFile
    }
    
    private let fileHandle: FileHandle

    let encoding: String.Encoding
    let maxEntries: Int
    let url: URL

    init(localFile url: URL, encoding: String.Encoding = .utf8, maxEntries: Int = 2000) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: nil) else {
                throw FileHandlerOutputStream.couldNotCreateFile
            }
        } else {
            try Self.truncateFile(fileURL: url, linesToKeep: maxEntries)
        }
        
        self.url = url
        self.encoding = encoding
        self.maxEntries = maxEntries
        self.fileHandle = try {
            let fileHandle = try FileHandle(forWritingTo: url)
            fileHandle.seekToEndOfFile()
            return fileHandle
        }()
    }

    mutating public func write(_ string: String) {
        if let data = string.data(using: encoding) {
            fileHandle.write(data)
        }
    }
    
    public mutating func clear() {
        fileHandle.truncateFile(atOffset: 0)
        fileHandle.seekToEndOfFile()
    }
    
    public mutating func truncate() {
        try? Self.truncateFile(fileURL: url, linesToKeep: maxEntries)
        fileHandle.seekToEndOfFile()
    }
    
    private static func truncateFile(fileURL: URL, linesToKeep numLines: Int) throws {
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        
        guard !data.isEmpty else { return }
        
        let newline = "\n".data(using: String.Encoding.utf8)!

        var lineNo = 0
        var pos = data.count
        while lineNo <= numLines {
            guard let range = data.range(of: newline, options: [ .backwards ], in: 0..<pos) else {
                return
            }
            lineNo += 1
            pos = range.lowerBound
        }

        let trimmedData = data.subdata(in: (pos+newline.count)..<data.count)
        try trimmedData.write(to: fileURL)
    }
}
