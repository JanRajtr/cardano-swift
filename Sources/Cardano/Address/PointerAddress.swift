//
//  PointerAddress.swift
//  
//
//  Created by Ostap Danylovych on 09.08.2021.
//

import Foundation
import CCardano

public struct PointerAddress {
    private var network: NetworkId
    public private(set) var payment: StakeCredential
    public private(set) var stake: Pointer
    
    init(pointerAddress: CCardano.PointerAddress) {
        network = pointerAddress.network
        payment = pointerAddress.payment.copied()
        stake = pointerAddress.stake
    }
    
    public init(network: NetworkId, payment: StakeCredential, stake: Pointer) {
        self.network = network
        self.payment = payment
        self.stake = stake
    }
    
    public func toAddress() throws -> Address {
        fatalError()
    }
    
    func withCPointerAddress<T>(
        fn: @escaping (CCardano.PointerAddress) throws -> T
    ) rethrows -> T {
        try payment.withCCredential { payment in
            try fn(CCardano.PointerAddress(network: network, payment: payment, stake: stake))
        }
    }
}

extension CCardano.PointerAddress: CPtr {
    typealias Val = PointerAddress
    
    func copied() -> PointerAddress {
        PointerAddress(pointerAddress: self)
    }
    
    mutating func free() {}
}
