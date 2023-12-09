import Logging
import Foundation

public struct FileLogging {
    let stream: FileHandlerOutputStream
    private var localFile: URL
    
    public init(to localFile: URL, maxEntries: Int = 2000) throws {
        self.stream = try FileHandlerOutputStream(localFile: localFile, maxEntries: maxEntries)
        self.localFile = localFile
    }
    
    public func handler(label: String) -> FileLogHandler {
        return FileLogHandler(label: label, fileLogger: self)
    }
    
    public static func logger(label: String, localFile url: URL, maxEntries: Int = 2000) throws -> Logger {
        let logging = try FileLogging(to: url, maxEntries: maxEntries)
        return Logger(label: label, factory: logging.handler)
    }
}

// Adapted from https://github.com/apple/swift-log.git
        
/// `FileLogHandler` is a simple implementation of `LogHandler` for directing
/// `Logger` output to a local file. Appends log output to this file, even across constructor calls.
public struct FileLogHandler: LogHandler {
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
    
    public init(label: String, fileLogger: FileLogging) {
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
        stream.write("\(self.timestamp()) \(level) \(self.label) :\(prettyMetadata.map { " \($0)" } ?? "") \(message)\n")
    }

    private func prettify(_ metadata: Logger.Metadata) -> String? {
        return !metadata.isEmpty ? metadata.map { "\($0)=\($1)" }.joined(separator: " ") : nil
    }

    private func timestamp() -> String {
        var buffer = [Int8](repeating: 0, count: 255)
        var timestamp = time(nil)
        let localTime = localtime(&timestamp)
        strftime(&buffer, buffer.count, "%Y-%m-%dT%H:%M:%S%z", localTime)
        return buffer.withUnsafeBufferPointer {
            $0.withMemoryRebound(to: CChar.self) {
                String(cString: $0.baseAddress!)
            }
        }
    }
}
