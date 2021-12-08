import Foundation
#if os(iOS) || os(macOS)
import MetricKit
#endif

public class DiagnosticPayload: DiagnosticPayloadProtocol, Codable {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()

        // "2020-10-10 19:35:24 +0000"
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"

        return formatter
    }()

    enum CodingKeys: String, CodingKey {
        case timeStampBegin
        case timeStampEnd
        case internalCrashDiagnostics = "crashDiagnostics"
        case hangDiagnostics
        case cpuExceptionDiagnostics
        case diskWriteExceptionDiagnostics
    }

    public let timeStampBegin: Date
    public let timeStampEnd: Date
    private let internalCrashDiagnostics: [CrashDiagnostic]?
    public let hangDiagnostics: [HangDiagnostic]?
    public let cpuExceptionDiagnostics: [CPUExceptionDiagnostic]?
    public let diskWriteExceptionDiagnostics: [DiskWriteExceptionDiagnostic]?

    public static func from(data: Data) throws -> DiagnosticPayload {
        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .formatted(DiagnosticPayload.dateFormatter)

        return try decoder.decode(DiagnosticPayload.self, from: data)
    }

    #if os(iOS) || os(macOS)
    @available(iOS 14.0, macOS 12.0, *)
    public static func from(payload: MXDiagnosticPayload) throws -> DiagnosticPayload {
        let data = payload.jsonRepresentation()

        return try from(data: data)
    }
    #endif

    public init(timeStampBegin: Date, timeStampEnd: Date, crashDiagnostics: [CrashDiagnostic]?, hangDiagnostics: [HangDiagnostic]?, cpuExceptionDiagnostics: [CPUExceptionDiagnostic]?, diskWriteExceptionDiagnostics: [DiskWriteExceptionDiagnostic]?) {
        self.timeStampBegin = timeStampBegin
        self.timeStampEnd = timeStampEnd
        self.internalCrashDiagnostics = crashDiagnostics
        self.hangDiagnostics = hangDiagnostics
        self.cpuExceptionDiagnostics = cpuExceptionDiagnostics
        self.diskWriteExceptionDiagnostics = diskWriteExceptionDiagnostics
    }

    public var crashDiagnostics: [CrashDiagnosticProtocol]? {
        return internalCrashDiagnostics
    }

    public func jsonRepresentation() -> Data {
        let encoder = JSONEncoder()

        encoder.dateEncodingStrategy = .formatted(DiagnosticPayload.dateFormatter)

        return (try? encoder.encode(self)) ?? Data()
    }
}

public class CrashMetaData: MetaDataProtocol, Codable {
    public let deviceType: String
    public let applicationBuildVersion: String
    public let applicationVersion: String
    public let osVersion: String
    public let platformArchitecture: String
    public let regionFormat: String
    public let virtualMemoryRegionInfo: String?
    public let exceptionType: Int?
    public let terminationReason: String?
    public let exceptionCode: Int?
    public let signal: Int?

    enum CodingKeys: String, CodingKey {
        case virtualMemoryRegionInfo
        case terminationReason
        case exceptionCode = "exceptionCode"
        case signal = "signal"
        case exceptionType = "exceptionType"
        case applicationBuildVersion = "appBuildVersion"
        case applicationVersion = "appVersion"
        case osVersion
        case platformArchitecture
        case regionFormat
        case deviceType

    }

    public init(deviceType: String, applicationBuildVersion: String, applicationVersion: String, osVersion: String, platformArchitecture: String, regionFormat: String, virtualMemoryRegionInfo: String?, exceptionType: Int?, terminationReason: String?, exceptionCode: Int?, signal: Int?) {
        self.deviceType = deviceType
        self.applicationBuildVersion = applicationBuildVersion
        self.applicationVersion = applicationVersion
        self.osVersion = osVersion
        self.platformArchitecture = platformArchitecture
        self.regionFormat = regionFormat
        self.virtualMemoryRegionInfo = virtualMemoryRegionInfo
        self.exceptionType = exceptionType
        self.terminationReason = terminationReason
        self.exceptionCode = exceptionCode
        self.signal = signal
    }

    public init(diagnostic: CrashDiagnosticProtocol) {
        self.deviceType = diagnostic.metaData.deviceType
        self.applicationBuildVersion = diagnostic.metaData.applicationBuildVersion
        self.applicationVersion = diagnostic.applicationVersion
        self.osVersion = diagnostic.metaData.osVersion
        self.platformArchitecture = diagnostic.metaData.platformArchitecture
        self.regionFormat = diagnostic.metaData.regionFormat
        self.virtualMemoryRegionInfo = diagnostic.virtualMemoryRegionInfo
        self.exceptionType = diagnostic.exceptionType?.intValue
        self.terminationReason = diagnostic.terminationReason
        self.exceptionCode = diagnostic.exceptionCode?.intValue
        self.signal = diagnostic.signal?.intValue
    }

    public func jsonRepresentation() -> Data {
        return (try? JSONEncoder().encode(self)) ?? Data()
    }
}

public class CrashDiagnostic: Codable {
    public let version: String
    private let internalMetaData: CrashMetaData
    private let internalCallStackTree: CallStackTree

    enum CodingKeys: String, CodingKey {
        case version
        case internalMetaData = "diagnosticMetaData"
        case internalCallStackTree = "callStackTree"
    }

    public init(metaData: CrashMetaData, callStackTree: CallStackTree) {
        self.version = "1.0.0"
        self.internalMetaData = metaData
        self.internalCallStackTree = callStackTree
    }

    public var applicationVersion: String {
        return internalMetaData.applicationVersion
    }

    public var virtualMemoryRegionInfo: String? {
        return internalMetaData.virtualMemoryRegionInfo
    }

    public func jsonRepresentation() -> Data {
        return (try? JSONEncoder().encode(self)) ?? Data()
    }
}

extension CrashDiagnostic: CrashDiagnosticProtocol {
    public var metaData: MetaDataProtocol {
        return internalMetaData
    }

    public var terminationReason: String? {
        return internalMetaData.terminationReason
    }

    public var signal: NSNumber? {
        return internalMetaData.signal.map({ NSNumber(value: $0) })
    }

    public var exceptionCode: NSNumber? {
        return internalMetaData.exceptionCode.map({ NSNumber(value: $0) })
    }

    public var callStackTree: CallStackTreeProtocol {
        return internalCallStackTree
    }

    public var exceptionType: NSNumber? {
        return internalMetaData.exceptionType.map({ NSNumber(value: $0) })
    }
}

public class HangMetaData: MetaDataProtocol, Codable {
    public let deviceType: String
    public let applicationBuildVersion: String
    public let applicationVersion: String
    public let osVersion: String
    public let platformArchitecture: String
    public let regionFormat: String
    private let hangDuration: String

    enum CodingKeys: String, CodingKey {
        case applicationBuildVersion = "appBuildVersion"
        case applicationVersion = "appVersion"
        case osVersion
        case platformArchitecture
        case regionFormat
        case deviceType
        case hangDuration
    }

    public init(deviceType: String, applicationBuildVersion: String, applicationVersion: String, osVersion: String, platformArchitecture: String, regionFormat: String) {
        self.deviceType = deviceType
        self.applicationBuildVersion = applicationBuildVersion
        self.applicationVersion = applicationVersion
        self.osVersion = osVersion
        self.platformArchitecture = platformArchitecture
        self.regionFormat = regionFormat
        self.hangDuration = ""
    }

    public init(diagnostic: HangDiagnostic) {
        self.deviceType = diagnostic.metaData.deviceType
        self.applicationBuildVersion = diagnostic.metaData.applicationBuildVersion
        self.applicationVersion = diagnostic.applicationVersion
        self.osVersion = diagnostic.metaData.osVersion
        self.platformArchitecture = diagnostic.metaData.platformArchitecture
        self.regionFormat = diagnostic.metaData.regionFormat
        self.hangDuration = ""
    }

    public func jsonRepresentation() -> Data {
        return (try? JSONEncoder().encode(self)) ?? Data()
    }
}

public class HangDiagnostic: DiagnosticProtocol, Codable {
    public let version: String
    private let internalMetaData: HangMetaData
    private let internalCallStackTree: CallStackTree

    enum CodingKeys: String, CodingKey {
        case version
        case internalMetaData = "diagnosticMetaData"
        case internalCallStackTree = "callStackTree"
    }

    public init(metaData: HangMetaData, callStackTree: CallStackTree) {
        self.version = "1.0.0"
        self.internalMetaData = metaData
        self.internalCallStackTree = callStackTree
    }

    public func jsonRepresentation() -> Data {
        return (try? JSONEncoder().encode(self)) ?? Data()
    }

    public var metaData: MetaDataProtocol {
        return internalMetaData
    }

    public var callStackTree: CallStackTreeProtocol {
        return internalCallStackTree
    }

    public var applicationVersion: String {
        return internalMetaData.applicationVersion
    }
}

public class CPUExceptionMetaData: MetaDataProtocol, Codable {
    public let deviceType: String
    public let applicationBuildVersion: String
    public let applicationVersion: String
    public let osVersion: String
    public let platformArchitecture: String
    public let regionFormat: String
    private let totalCPUTime: String
    private let totalSampledTime: String

    enum CodingKeys: String, CodingKey {
        case applicationBuildVersion = "appBuildVersion"
        case applicationVersion = "appVersion"
        case osVersion
        case platformArchitecture
        case regionFormat
        case deviceType
        case totalCPUTime
        case totalSampledTime
    }

    public init(deviceType: String, applicationBuildVersion: String, applicationVersion: String, osVersion: String, platformArchitecture: String, regionFormat: String) {
        self.deviceType = deviceType
        self.applicationBuildVersion = applicationBuildVersion
        self.applicationVersion = applicationVersion
        self.osVersion = osVersion
        self.platformArchitecture = platformArchitecture
        self.regionFormat = regionFormat
        self.totalCPUTime = ""
        self.totalSampledTime = ""
    }

    public init(diagnostic: CPUExceptionDiagnostic) {
        self.deviceType = diagnostic.metaData.deviceType
        self.applicationBuildVersion = diagnostic.metaData.applicationBuildVersion
        self.applicationVersion = diagnostic.applicationVersion
        self.osVersion = diagnostic.metaData.osVersion
        self.platformArchitecture = diagnostic.metaData.platformArchitecture
        self.regionFormat = diagnostic.metaData.regionFormat
        self.totalCPUTime = ""
        self.totalSampledTime = ""
    }

    public func jsonRepresentation() -> Data {
        return (try? JSONEncoder().encode(self)) ?? Data()
    }
}

public class CPUExceptionDiagnostic: DiagnosticProtocol, Codable {
    public let version: String
    private let internalMetaData: CPUExceptionMetaData
    private let internalCallStackTree: CallStackTree

    enum CodingKeys: String, CodingKey {
        case version
        case internalMetaData = "diagnosticMetaData"
        case internalCallStackTree = "callStackTree"
    }

    public init(metaData: CPUExceptionMetaData, callStackTree: CallStackTree) {
        self.version = "1.0.0"
        self.internalMetaData = metaData
        self.internalCallStackTree = callStackTree
    }

    public func jsonRepresentation() -> Data {
        return (try? JSONEncoder().encode(self)) ?? Data()
    }

    public var metaData: MetaDataProtocol {
        return internalMetaData
    }

    public var callStackTree: CallStackTreeProtocol {
        return internalCallStackTree
    }

    public var applicationVersion: String {
        return internalMetaData.applicationVersion
    }
}

public class DiskWriteExceptionMetaData: MetaDataProtocol, Codable {
    public let deviceType: String
    public let applicationBuildVersion: String
    public let applicationVersion: String
    public let osVersion: String
    public let platformArchitecture: String
    public let regionFormat: String
    private let writesCaused: String

    enum CodingKeys: String, CodingKey {
        case applicationBuildVersion = "appBuildVersion"
        case applicationVersion = "appVersion"
        case osVersion
        case platformArchitecture
        case regionFormat
        case deviceType
        case writesCaused
    }

    public init(deviceType: String, applicationBuildVersion: String, applicationVersion: String, osVersion: String, platformArchitecture: String, regionFormat: String) {
        self.deviceType = deviceType
        self.applicationBuildVersion = applicationBuildVersion
        self.applicationVersion = applicationVersion
        self.osVersion = osVersion
        self.platformArchitecture = platformArchitecture
        self.regionFormat = regionFormat
        self.writesCaused = ""
    }

    public init(diagnostic: DiskWriteExceptionDiagnostic) {
        self.deviceType = diagnostic.metaData.deviceType
        self.applicationBuildVersion = diagnostic.metaData.applicationBuildVersion
        self.applicationVersion = diagnostic.applicationVersion
        self.osVersion = diagnostic.metaData.osVersion
        self.platformArchitecture = diagnostic.metaData.platformArchitecture
        self.regionFormat = diagnostic.metaData.regionFormat
        self.writesCaused = ""
    }

    public func jsonRepresentation() -> Data {
        return (try? JSONEncoder().encode(self)) ?? Data()
    }
}

public class DiskWriteExceptionDiagnostic: DiagnosticProtocol, Codable {
    public let version: String
    private let internalMetaData: DiskWriteExceptionMetaData
    private let internalCallStackTree: CallStackTree

    enum CodingKeys: String, CodingKey {
        case version
        case internalMetaData = "diagnosticMetaData"
        case internalCallStackTree = "callStackTree"
    }

    public init(metaData: DiskWriteExceptionMetaData, callStackTree: CallStackTree) {
        self.version = "1.0.0"
        self.internalMetaData = metaData
        self.internalCallStackTree = callStackTree
    }

    public func jsonRepresentation() -> Data {
        return (try? JSONEncoder().encode(self)) ?? Data()
    }

    public var metaData: MetaDataProtocol {
        return internalMetaData
    }

    public var callStackTree: CallStackTreeProtocol {
        return internalCallStackTree
    }

    public var applicationVersion: String {
        return internalMetaData.applicationVersion
    }
}
