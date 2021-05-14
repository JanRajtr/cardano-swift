//
//  Ed25519Signature.swift
//  
//
//  Created by Ostap Danylovych on 13.05.2021.
//

import Foundation
import CCardano

public class Ed25519Signature {
    private var signature: CCardano.Ed25519Signature
    
    init(signature: CCardano.Ed25519Signature) {
        self.signature = signature
    }
    
    public convenience init(data: Data) throws {
        try self.init(signature: CCardano.Ed25519Signature(data: data))
    }
    
    public func data() throws -> Data {
        try signature.data()
    }
    
    public func hex() throws -> String {
        try signature.hex()
    }
    
    public func clone() throws -> Ed25519Signature {
        return try Ed25519Signature(signature: signature.clone())
    }
    
    deinit {
        signature.free()
    }
}

extension CCardano.Ed25519Signature: CPtr {
    typealias Value = Ed25519Signature
    
    func copied() -> Ed25519Signature {
        Ed25519Signature(signature: self)
    }
    
    mutating func free() {
        cardano_ed25519_signature_free(&self)
    }
}

extension CCardano.Ed25519Signature {
    public init(data: Data) throws {
        self = try data.withCData { bytes in
            RustResult<Self>.wrap { result, error in
                cardano_ed25519_signature_from_bytes(bytes, result, error)
            }
        }.get()
    }
    
    public func data() throws -> Data {
        var data = try RustResult<CData>.wrap { result, error in
            cardano_ed25519_signature_to_bytes(self, result, error)
        }.get()
        return data.owned()
    }
    
    public func hex() throws -> String {
        var chars = try RustResult<CharPtr>.wrap { result, error in
            cardano_ed25519_signature_to_hex(self, result, error)
        }.get()
        return chars.owned()
    }
    
    public func clone() throws -> Self {
        try RustResult<Self>.wrap { result, error in
            cardano_ed25519_signature_clone(self, result, error)
        }.get()
    }
}
