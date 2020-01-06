//
// This file is part of Canvas.
// Copyright (C) 2019-present  Instructure, Inc.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

#if DEBUG

import Foundation

struct IPCError: Error {
    let message: String
}

class IPCServer {
    let machPortName: String
    let messagePort: CFMessagePort

    func handler(msgid: Int32, data: Data?) -> Data? {
        fatalError("handler(msgid:data:) must be overridden")
    }

    static var knownIPCServers = [CFMessagePort: IPCServer]()

    init(machPortName: String, runOnMainQueue: Bool) {
        self.machPortName = machPortName
        let handlerWrapper: CFMessagePortCallBack = { port, msgid, data, _ in
            IPCServer.knownIPCServers[port!]!.handler(msgid: msgid, data: data as Data?).map { Unmanaged.passRetained($0 as CFData) }
        }
        guard let port = CFMessagePortCreateLocal(kCFAllocatorDefault, self.machPortName as CFString, handlerWrapper, nil, nil) else {
            fatalError("Couldn't create mach port \(machPortName)")
        }
        messagePort = port
        IPCServer.knownIPCServers[port] = self
        if runOnMainQueue {
            CFMessagePortSetDispatchQueue(port, DispatchQueue.main)
        } else {
            let thread = Thread {
                let loop = CFRunLoopGetCurrent()
                let source = CFMessagePortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
                CFRunLoopAddSource(loop, source, .defaultMode)
                CFRunLoopRun()
                print("run loop exited!")
            }
            thread.name = "ipc-server"
            thread.start()
        }
    }
}

class IPCAppServer: IPCServer {
    static func portName(id: String) -> String {
        "com.instructure.icanvas.ui-test-app-\(id)"
    }

    override func handler(msgid: Int32, data: Data?) -> Data? {
        guard
            let data = data,
            let helper = try? JSONDecoder().decode(UITestHelpers.Helper.self, from: data)
        else {
            fatalError("bad IPC request")
        }
        return UITestHelpers.shared?.run(helper)
    }

    init(machPortName: String) {
        super.init(machPortName: machPortName, runOnMainQueue: true)
    }
}

enum IPCDriverServerMessage {
    case urlRequest(_ request: URLRequest)
}

extension IPCDriverServerMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case request
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let request = try container.decodeIfPresent(URLRequest.self, forKey: .request) {
            self = .urlRequest(request)
        } else {
            throw DecodingError.typeMismatch(type(of: self), .init(codingPath: container.codingPath, debugDescription: "Couldn't decode \(type(of: self))"))
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .urlRequest(let request):
            try container.encode(request, forKey: .request)
        }
    }
}

protocol IPCDriverServerDelegate: class {
    func handler(_ message: IPCDriverServerMessage) -> Data?
}

class IPCDriverServer: IPCServer {
    static func portName(id: String) -> String {
        "com.instructure.icanvas.ui-test-driver-\(id)"
    }

    override func handler(msgid: Int32, data: Data?) -> Data? {
        guard
            let data = data,
            let message = try? JSONDecoder().decode(IPCDriverServerMessage.self, from: data)
            else {
                fatalError("bad IPC request")
        }
        return delegate!.handler(message)
    }

    weak var delegate: IPCDriverServerDelegate?
    init (machPortName: String, delegate: IPCDriverServerDelegate?) {
        super.init(machPortName: machPortName, runOnMainQueue: false)
        self.delegate = delegate
    }
}

class IPCClient {
    var messagePort: CFMessagePort?
    var serverPortName: String
    var openTimeout: TimeInterval

    init(serverPortName: String, timeout: TimeInterval = 60.0) {
        self.serverPortName = serverPortName
        self.openTimeout = timeout
    }

    func openMessagePort() throws {
        let deadline = Date().addingTimeInterval(openTimeout)
        repeat {
            if let port = CFMessagePortCreateRemote(kCFAllocatorDefault, serverPortName as CFString) {
                messagePort = port
                return
            }
            sleep(1)
        } while Date() < deadline
        throw IPCError(message: "client couldn't connect to server port \(serverPortName)")
    }

    func requestRemote<R: Codable>(_ request: R) throws -> Data? {
        if messagePort == nil || !CFMessagePortIsValid(messagePort) {
            try openMessagePort()
        }

        var responseData: Unmanaged<CFData>?
        let requestData = (try? JSONEncoder().encode(request))!
        let status = CFMessagePortSendRequest(messagePort, 0, requestData as CFData, 1000, 1000, CFRunLoopMode.defaultMode.rawValue, &responseData)
        guard status == kCFMessagePortSuccess else {
            throw IPCError(message: "IPCClient.requestRemote: error sending IPC request")
        }
        return responseData?.takeRetainedValue() as Data?
    }
}

#endif
