//
//  File.swift
//  
//
//  Created by Dana Buehre on 12/8/23.
//

import Logging
import Foundation

public struct JSONFileLogging {
    public let stream: FileHandlerOutputStream
    private var localFile: URL
    
    public init(to localFile: URL, maxEntries: Int = 2000) throws {
        self.stream = try FileHandlerOutputStream(localFile: localFile, maxEntries: maxEntries)
        self.localFile = localFile
    }
    
    public func handler(label: String) -> JSONFileLogHandler {
        return JSONFileLogHandler(label: label, fileLogger: self)
    }
    
    public static func logger(label: String, localFile url: URL, maxEntries: Int = 2000) throws -> Logger {
        let logging = try JSONFileLogging(to: url, maxEntries: maxEntries)
        return Logger(label: label, factory: logging.handler)
    }
}

// Adapted from https://github.com/apple/swift-log.git
        
/// `FileLogHandler` is a simple implementation of `LogHandler` for directing
/// `Logger` output to a local file. Appends log output to this file, even across constructor calls.
public struct JSONFileLogHandler: LogHandler {
    private let stream: FileHandlerOutputStream
    private var label: String
    
    public var logLevel: Logger.Level = .info

    private var prettyMetadata: String?
    public var metadata = Logger.Metadata() {
        didSet {
            self.prettyMetadata = self.prettify(self.metadata)
        }
    }

    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return self.metadata[metadataKey]
        }
        set {
            self.metadata[metadataKey] = newValue
        }
    }
    
    public init(label: String, fileLogger: JSONFileLogging) {
        self.label = label
        self.stream = fileLogger.stream
    }

    public init(label: String, localFile url: URL, maxEntries: Int = 2000) throws {
        self.label = label
        self.stream = try FileHandlerOutputStream(localFile: url, maxEntries: maxEntries)
    }

    public func log(level: Logger.Level,
                    message: Logger.Message,
                    metadata: Logger.Metadata?,
                    source: String,
                    file: String,
                    function: String,
                    line: UInt) {
        let prettyMetadata = metadata?.isEmpty ?? true
            ? self.prettyMetadata
            : self.prettify(self.metadata.merging(metadata!, uniquingKeysWith: { _, new in new }))

        var stream = self.stream
        stream.write(LogFile.Log(
            date: Date(),
            level: level.rawValue,
            category: self.label,
            message: "\(prettyMetadata.map { " \($0)" } ?? "") \(message)"
        ))
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        return !metadata.isEmpty ? metadata.map { "\($0)=\($1)" }.joined(separator: " ") : nil
    }
}

private let encoder = JSONEncoder()

public struct LogFile: Codable {
    
    public struct Log: Codable, Hashable {
        let date: Date
        let level: String
        let category: String
        let message: String
    }
    
    public let logs: [Log]

    public init(logs: [Log]) {
        self.logs = logs
    }
    
    public init(url: URL) throws {
        let decoder = JSONDecoder()
        let string = try String(contentsOf: url)
        let lines = string.components(separatedBy: "\n").compactMap({ $0.data(using: .utf8) })
        let logs = lines.compactMap({ try? decoder.decode(Log.self, from: $0) })
        self.init(logs: logs)
    }
}

private extension FileHandlerOutputStream {
    mutating func write(_ log: LogFile.Log) {
        if let data = try? encoder.encode(log),
           let string = String(data: data, encoding: .utf8) {
            write(string + "\n")
        }
    }
}
