import XCTest
@testable import FileLogging
@testable import Logging

final class JSONFileLogHandlerTests: XCTestCase, Utilities {
    let logFileName = "JSONLogFile.txt"
    
    func testLogToFileUsingBootstrap() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        print("\(logFileURL)")
        let fileLogger = try JSONFileLogging(to: logFileURL)
        // Using `bootstrapInternal` so that running `swift test` won't fail. If using this in production code, just use `bootstrap`.
        LoggingSystem.bootstrapInternal(fileLogger.handler)

        let logger = Logger(label: "Test")
        
        // Not really an error.
        logger.error("Test Test Test")
        
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testLogToFileAppendsAcrossLoggerCalls() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        print("\(logFileURL)")
        let fileLogger = try JSONFileLogging(to: logFileURL)
        // Using `bootstrapInternal` so that running `swift test` won't fail. If using this in production code, just use `bootstrap`.
        LoggingSystem.bootstrapInternal(fileLogger.handler)
        let logger = Logger(label: "Test")
        
        // Not really an error.
        logger.error("Test Test Test")
        let fileSize1 = try getFileSize(file: logFileURL)

        logger.error("Test Test Test")
        let fileSize2 = try getFileSize(file: logFileURL)
        
        XCTAssert(fileSize2 > fileSize1)
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testLogToFileAppendsAcrossConstructorCalls() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        print("\(logFileURL)")
        let fileLogger = try JSONFileLogging(to: logFileURL)

        let logger1 = Logger(label: "Test", factory: fileLogger.handler)
        logger1.error("Test Test Test")
        let fileSize1 = try getFileSize(file: logFileURL)
        
        let logger2 = Logger(label: "Test", factory: fileLogger.handler)
        logger2.error("Test Test Test")
        let fileSize2 = try getFileSize(file: logFileURL)
        
        XCTAssert(fileSize2 > fileSize1)
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    // Adapted from https://nshipster.com/swift-log/
    func testLogToBothFileAndConsole() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        let fileLogger = try JSONFileLogging(to: logFileURL)

        LoggingSystem.bootstrap { label in
            let handlers:[LogHandler] = [
                JSONFileLogHandler(label: label, fileLogger: fileLogger),
                StreamLogHandler.standardOutput(label: label)
            ]

            return MultiplexLogHandler(handlers)
        }
        
        let logger = Logger(label: "Test")
        
        // TODO: Manually check that the output also shows up in the Xcode console.
        logger.error("Test Test Test")
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testLoggingUsingLoggerFactoryConstructor() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        let fileLogger = try JSONFileLogging(to: logFileURL)

        let logger = Logger(label: "Test", factory: fileLogger.handler)
        
        logger.error("Test Test Test")
        let fileSize1 = try getFileSize(file: logFileURL)
        
        logger.error("Test Test Test")
        let fileSize2 = try getFileSize(file: logFileURL)
        
        XCTAssert(fileSize2 > fileSize1)
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testLoggingUsingConvenienceMethod() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)

        let logger = try JSONFileLogging.logger(label: "Foobar", localFile: logFileURL)
        
        logger.error("Test Test Test")
        let fileSize1 = try getFileSize(file: logFileURL)
        
        logger.error("Test Test Test")
        let fileSize2 = try getFileSize(file: logFileURL)
        
        XCTAssert(fileSize2 > fileSize1)
//        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    func testDecodingLog() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        
        let logger = try JSONFileLogging.logger(label: "Foobar", localFile: logFileURL)
        
        logger.error("Test Test Test")
        logger.error("Test Test Test")
        
        let logFile = try LogFile(url: logFileURL)
        debugPrint(logFile.json)
    }
    
    func testClearLog() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        let fileLogger = try JSONFileLogging(to: logFileURL)
        
        let logger = Logger(label: "Test", factory: fileLogger.handler)
        
        logger.error("Test Test Test")
        logger.error("Test Test Test")
        
        var stream = fileLogger.stream
        stream.clear()
        
        let fileSize = try getFileSize(file: logFileURL)
        
        XCTAssert(fileSize == 0, "filesize: \(fileSize)")
    }
    
    func testLogTruncate() throws {
        let logFileURL = try getDocumentsDirectory().appendingPathComponent(logFileName)
        let fileLogger = try JSONFileLogging(to: logFileURL, maxEntries: 5)
        
        let logger = Logger(label: "Test", factory: fileLogger.handler)
        
        logger.error("Test Test Test 1")
        logger.error("Test Test Test 2")
        logger.error("Test Test Test 3")
        logger.error("Test Test Test 4")
        logger.error("Test Test Test 5")
        logger.error("Test Test Test 6")
        
        var stream = fileLogger.stream
        try stream.truncate()
        
        let string = try String(contentsOf: logFileURL)
        // subtract 1 so as not to count the trailing newline
        let lines = string.components(separatedBy: "\n").count - 1
        print(string)
        
        XCTAssert(lines == 5)
    }
}

private extension Encodable {
    var json: String {
        let encoder = JSONEncoder()
//        encoder.outputFormatting = .prettyPrinted
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
}
