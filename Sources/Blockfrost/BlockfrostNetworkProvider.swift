//
//  BlockfrostNetworkProvider.swift
//  
//
//  Created by Ostap Danylovych on 28.10.2021.
//

import Foundation
import BlockfrostSwiftSDK
#if !COCOAPODS
import Cardano
#endif

public struct BlockfrostNetworkProvider: NetworkProvider {
    private let config: BlockfrostConfig
    private let addressesApi: CardanoAddressesAPI
    private let transactionsApi: CardanoTransactionsAPI
    
    public init(config: BlockfrostConfig) {
        self.config = config
        addressesApi = CardanoAddressesAPI(config: config)
        transactionsApi = CardanoTransactionsAPI(config: config)
    }
    
    public func getBalance(for address: Address,
                           _ cb: @escaping (Result<UInt64, Error>) -> Void) {
        do {
            let _ = addressesApi.getAddress(address: try address.bech32()) { res in
                cb(res.flatMap { address in
                    Result {
                        try Value(blockfrost: address.amount.map {
                            (unit: $0.unit, quantity: $0.quantity)
                        }).coin
                    }
                })
            }
        } catch {
            self.config.apiResponseQueue.async {
                cb(.failure(error))
            }
        }
    }
    
    public func getTransactions(for address: Address,
                                _ cb: @escaping (Result<[AddressTransaction], Error>) -> Void) {
        do {
            let _ = addressesApi.getAddressTransactionsAll(address: try address.bech32()) { res in
                cb(res.map { transactions in
                    transactions.map { AddressTransaction(blockfrost: $0) }
                })
            }
        } catch {
            self.config.apiResponseQueue.async {
                cb(.failure(error))
            }
        }
    }
    
    public func getTransactionCount(for address: Address,
                                    _ cb: @escaping (Result<Int, Error>) -> Void) {
        do {
            let _ = addressesApi.getAddressDetails(address: try address.bech32()) { res in
                switch res {
                case .success(let details):
                    cb(.success(details.txCount))
                case .failure(let error):
                    print(error)
                    guard let error = error as? ErrorResponse else {
                        cb(.failure(error))
                        return
                    }
                    switch error {
                    case .errorStatus(let int, _, _, _):
                        guard int == 404 else {
                            cb(.failure(error))
                            return
                        }
                        cb(.success(0))
                    default:
                        cb(.failure(error))
                    }
                }
            }
        } catch {
            self.config.apiResponseQueue.async {
                cb(.failure(error))
            }
        }
    }
    
    public func getTransaction(hash: String,
                               _ cb: @escaping (Result<ChainTransaction, Error>) -> Void) {
        let _ = transactionsApi.getTransaction(hash: hash) { res in
            cb(res.map { ChainTransaction(blockfrost: $0) })
        }
    }
    
    public func getUtxos(for addresses: [Address],
                         page: Int,
                         _ cb: @escaping (Result<[UTXO], Error>) -> Void) {
        let b32Addresses: Array<(Address, String)>
        do {
            b32Addresses = try addresses.map { try ($0, $0.bech32()) }
        } catch {
            self.config.apiResponseQueue.async {
                cb(.failure(error))
            }
            return
        }
        b32Addresses.asyncMap { (addrAndB32, mapped) in
            let (address, b32) = addrAndB32
            let _ = self.addressesApi.getAddressUtxos(
                address: b32,
                page: page
            ) { res in
                let result = res.flatMap { res in
                    Result { try res.map { try UTXO(address: address, blockfrost: $0) } }
                }
                mapped(result)
            }
        }.exec { (res: Result<[[UTXO]], Error>) in
            cb(res.map { utxo in utxo.flatMap { $0 } })
        }
    }
    
    public func getUtxos(for transaction: TransactionHash,
                         _ cb: @escaping (Result<[UTXO], Error>) -> Void) {
        do {
            let _ = transactionsApi.getTransactionUtxos(hash: try transaction.bytes().hex()) { res in
                cb(res.flatMap { txContentUtxo in
                    Result { try txContentUtxo.inputs.map { try UTXO(blockfrost: $0) } }
                })
            }
        } catch {
            self.config.apiResponseQueue.async {
                cb(.failure(error))
            }
        }
    }
    
    public func submit(tx: Transaction,
                       _ cb: @escaping (Result<String, Error>) -> Void) {
        do {
            let _ = transactionsApi.submitTransaction(transaction: try tx.bytes()) { res in
                switch res {
                case .success(let hash):
                    cb(.success(hash.trimmingCharacters(in: ["\""])))
                case .failure(let error):
                    self.config.apiResponseQueue.async {
                        cb(.failure(error))
                    }
                }
            }
        } catch {
            self.config.apiResponseQueue.async {
                cb(.failure(error))
            }
        }
    }
}
