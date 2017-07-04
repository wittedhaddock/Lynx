import Dispatch

/// Vapor API
public final class VaporStyleRouter : TrieRouter {
    /// Creates a new router
    public init() {
        super.init(startingTokensWith: 0x3a)
    }
    
    /// Registers a route
    fileprivate func register(_ path: [String], method: Method, handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
        self.register(at: path, method: method) { request, client in
            do {
                let response = try handler(request)
                
                try response.makeResponse().send(to: client)
            } catch {
                client.close()
            }
        }
    }
    
    /// Registers a get route
    public func get(_ path: String..., handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
        self.register(path, method: .get, handler: handler)
    }
    
    /// Registers a put route
    public func put(_ path: String..., handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
       self.register(path, method: .get, handler: handler)
    }
    
    /// Registers a post route
    public func post(_ path: String..., handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
        self.register(path, method: .post, handler: handler)
    }
    
    /// Registers a delete route
    public func delete(_ path: String..., handler: @escaping ((Request) throws -> (ResponseRepresentable))) {
        self.register(path, method: .delete, handler: handler)
    }
    
    /// All open websockets
    public var websockets = [Int : WebSocket]()
    
    /// Next identifier
    private var nextID: Int = 0
    
    let queue = DispatchQueue(label: "org.openkitten.lynx.websocketpool", qos: .userInteractive)
    
    /// Registers a websocket route
    public func websocket(_ path: String..., handler: @escaping ((WebSocket) throws -> ())) {
        self.register(at: path, method: .get) { request, client in
            do {
                let websocket: WebSocket = try self.queue.sync {
                    guard let websocket = try WebSocket(from: request, to: client, identifiedBy: self.nextID) else {
                        throw WebSocketError.couldNotConnect
                    }
                    
                    defer { self.nextID = self.nextID &+ 1}
                    
                    self.websockets[self.nextID] = websocket
                    
                    return websocket
                }
                
                try handler(websocket)
            } catch {
                client.close()
            }
        }
    }
}

/// Something that can be crafted from a path component
public protocol PathComponentInitializable {
    init?(from string: String) throws
}

/// Makes a string craftable from a path component
extension String : PathComponentInitializable {
    /// Initializes a string from a path component
    public init?(from string: String) throws {
        self = string
    }
}

/// Error that gets thrown when extracting a path component into an entity isn't possible
public struct InvalidExtractionError : Error {}

extension Request {
    /// Extracts a type from a PathComponent
    public func extract<PCI: PathComponentInitializable>(_ initializable: PCI.Type, from token: String) throws -> PCI? {
        guard let value = self.url.tokens[token] else {
            throw InvalidExtractionError()
        }
        
        return try PCI(from: value)
    }
}