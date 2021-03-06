import Foundation
import Dispatch

#if (os(macOS) || os(iOS))
    import Darwin
#if OPENSSL
    import KittenCTLS
#else
    import Security
#endif
#else
    import Glibc
    import KittenCTLS
#endif

public final class TCPSSLClient : TCPClient {
    #if (os(macOS) || os(iOS)) && !OPENSSL
        private let sslClient: SSLContext
        var descrClone: Int32 = 0
    #else
    private let sslClient: UnsafeMutablePointer<SSL>?
    private let sslMethod: UnsafePointer<SSL_METHOD>?
    private let sslContext: UnsafeMutablePointer<SSL_CTX>?
    #endif
    
    let hostname: String
    
    #if (os(macOS) || os(iOS)) && !OPENSSL
        public override init(hostname: String, port: UInt16, onRead: @escaping ReadCallback) throws {
            guard let context = SSLCreateContext(nil, .clientSide, .streamType) else {
                throw TCPError.cannotCreateContext
            }
            
            self.sslClient = context
            self.hostname = hostname
            
            try super.init(hostname: hostname, port: port, onRead: onRead)
            
            // workaround for a swift bug
            descrClone = self.descriptor
            
            var val = 1
            setsockopt(self.descriptor, SOL_SOCKET, SO_NOSIGPIPE, &val, socklen_t(MemoryLayout<Int>.stride))
            
            SSLSetIOFuncs(self.sslClient, { context, data, length in
                let context = context.assumingMemoryBound(to: Int32.self).pointee
                let lengthRequested = length.pointee
                
                var readCount = Darwin.recv(context, data, lengthRequested, 0)
                
                defer { length.initialize(to: readCount) }
                if readCount == 0 {
                    return OSStatus(errSSLClosedGraceful)
                } else if readCount < 0 {
                    readCount = 0
                    
                    switch errno {
                    case ENOENT:
                        return OSStatus(errSSLClosedGraceful)
                    case EAGAIN:
                        return OSStatus(errSSLWouldBlock)
                    case ECONNRESET:
                        return OSStatus(errSSLClosedAbort)
                    default:
                        return OSStatus(errSecIO)
                    }
                }
                
                guard lengthRequested <= readCount else {
                    return OSStatus(errSSLWouldBlock)
                }
                
                return noErr
            }, { context, data, length in
                let context = context.assumingMemoryBound(to: Int32.self).pointee
                let toWrite = length.pointee
                
                var writeCount = Darwin.send(context, data, toWrite, 0)
                
                defer { length.initialize(to: writeCount) }
                if writeCount == 0 {
                    return OSStatus(errSSLClosedGraceful)
                } else if writeCount < 0 {
                    writeCount = 0
                    
                    guard errno == EAGAIN else {
                        return OSStatus(errSecIO)
                    }
                        
                    return OSStatus(errSSLWouldBlock)
                }
                
                guard toWrite <= writeCount else {
                    return Int32(errSSLWouldBlock)
                }
                
                return noErr
            })
            
            self.readSource.setEventHandler(qos: .userInteractive) {
                var read = 0
                let error = SSLRead(self.sslClient, self.incomingBuffer.pointer, Int(UInt16.max), &read)
                
                guard read != 0 else {
                    if error == errSSLWouldBlock {
                        return
                    }
                    
                    self.readSource.cancel()
                    return
                }
                
                self.onRead(self.incomingBuffer.pointer, read)
            }
            
            self.readSource.setCancelHandler(qos: .userInteractive) {
                SSLClose(self.sslClient)
                _ = cClose(self.descriptor)
            }
        }
    
        public override func connect() throws {
            try super.connect(startReading: false)
            
            guard SSLSetConnection(sslClient, &self.descrClone) == 0 else {
                throw TCPError.unableToConnect
            }
            
            var hostname = [Int8](self.hostname.utf8.map { Int8($0) })
            guard SSLSetPeerDomainName(sslClient, &hostname, hostname.count) == 0 else {
                throw TCPError.unableToConnect
            }
            
            var result: Int32
            
            repeat {
                result = SSLHandshake(sslClient)
            } while result == errSSLWouldBlock
            
            guard result == errSecSuccess || result == errSSLPeerAuthCompleted else {
                throw TCPError.unableToConnect
            }
            
            self.readSource.resume()
        }
    #else
        public init(hostname: String, port: UInt16, onRead: @escaping ReadCallback) throws {
            throw TCPError.unsupported
        }
    #endif
    
    /// Sends new data to the client
    public override func send(data pointer: UnsafePointer<UInt8>, withLengthOf length: Int) throws {
        #if (os(macOS) || os(iOS)) && !OPENSSL
            var i = 0
            
            guard SSLWrite(self.sslClient, pointer, length, &i) == noErr, i == length else {
                throw TCPError.sendFailure
            }
        #else
            throw TCPError.unsupported
        #endif
    }
}
