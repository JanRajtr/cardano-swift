//
//  NetworkProvider.swift
//  
//
//  Created by Yehor Popovych on 27.10.2021.
//

import Foundation
#if !COCOAPODS
import CardanoCore
#endif

public protocol NetworkProvider {
    func getTransactions(for address: Address,
                         _ cb: @escaping (Result<[AddressTransaction], Error>) -> Void)
    
    func getTransactionCount(for address: Address,
                             _ cb: @escaping (Result<Int, Error>) -> Void)
    
    func getTransaction(hash: String,
                        _ cb: @escaping (Result<Any, Error>) -> Void)
    
    func getUtxos(for addresses: [Address],
                  page: Int,
                  _ cb: @escaping (Result<[UTXO], Error>) -> Void)
    
    func submit(tx: TransactionBody,
                metadata: TransactionMetadata?,
                _ cb: @escaping (Result<Transaction, Error>) -> Void)
}
