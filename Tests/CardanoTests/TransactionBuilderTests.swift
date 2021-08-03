//
//  TransactionBuilderTests.swift
//  
//
//  Created by Ostap Danylovych on 27.07.2021.
//

import Foundation
import XCTest
@testable import Cardano

final class TransactionBuilderTests: XCTestCase {
    private func genesisId() throws -> TransactionHash {
        try TransactionHash(bytes: Data(repeating: 0, count: 32))
    }
    
    private func rootKey15() throws -> Bip32PrivateKey {
        let entropy: [UInt8] = [0x0c, 0xcb, 0x74, 0xf3, 0x6b, 0x7d, 0xa1, 0x64, 0x9a, 0x81, 0x44, 0x67, 0x55, 0x22, 0xd4, 0xd8, 0x09, 0x7c, 0x64, 0x12];
        return try Bip32PrivateKey(bip39: Data(entropy), password: Data())
    }
    
    private func harden(_ index: UInt32) -> UInt32 {
        index | 0x80_00_00_00
    }
    
    func testTransactionBuilder() throws {
        let _ = Cardano()
        let data28 = Data(repeating: 1, count: 28)
        let data32 = Data(repeating: 1, count: 32)
        let linearFee = try LinearFee(coefficient: 1, constant: 2)
        var transactionBuilder = try TransactionBuilder(
            linearFee: linearFee,
            minimumUtxoVal: 1,
            poolDeposit: 2,
            keyDeposit: 3
        )
        transactionBuilder.fee = 1
        transactionBuilder.ttl = 2
        try transactionBuilder.setCerts(
            certs: [
                Certificate.genesisKeyDelegation(
                    GenesisKeyDelegation(
                        genesishash: GenesisHash(bytes: data28),
                        genesis_delegate_hash: GenesisDelegateHash(bytes: data28),
                        vrf_keyhash: VRFKeyHash(bytes: data32)
                    )
                )
            ]
        )
        try transactionBuilder.setWithdrawals(
            withdrawals: [
                RewardAddress(
                    network: 1,
                    payment: StakeCredential.keyHash(Ed25519KeyHash(bytes: data28))
                ): 1
            ]
        )
        XCTAssertNoThrow(try transactionBuilder.build())
    }

    func testBuildTxWithChange() throws {
        let linearFee = try LinearFee(coefficient: 500, constant: 2)
        var txBuilder = try TransactionBuilder(linearFee: linearFee, minimumUtxoVal: 1, poolDeposit: 1, keyDeposit: 1)
        let spend = try rootKey15()
            .derive(index: harden(1852))
            .derive(index: harden(1815))
            .derive(index: harden(0))
            .derive(index: 0)
            .derive(index: 0)
            .publicKey()
        let changeKey = try rootKey15()
            .derive(index: harden(1852))
            .derive(index: harden(1815))
            .derive(index: harden(0))
            .derive(index: 1)
            .derive(index: 0)
            .publicKey()
        let stake = try rootKey15()
            .derive(index: harden(1852))
            .derive(index: harden(1815))
            .derive(index: harden(0))
            .derive(index: 2)
            .derive(index: 0)
            .publicKey()
        let spendCred = try StakeCredential.keyHash(spend.toRawKey().hash())
        let stakeCred = try StakeCredential.keyHash(stake.toRawKey().hash())
        let addrNet0 = try BaseAddress(
            network: NetworkInfo.testnet.network_id,
            payment: spendCred,
            stake: stakeCred
        ).toAddress()
        try txBuilder.addKeyInput(
            hash: spend.toRawKey().hash(),
            input: TransactionInput(transaction_id: genesisId(), index: 0),
            amount: Value(coin: 1_000_000)
        )
        try txBuilder.addOutput(output: TransactionOutput(address: addrNet0, amount: Value(coin: 10)))
        txBuilder.ttl = 1000
        let changeCred = StakeCredential.keyHash(try changeKey.toRawKey().hash())
        let changeAddr = try BaseAddress(
            network: NetworkInfo.testnet.network_id,
            payment: changeCred,
            stake: stakeCred
        ).toAddress()
        let addedChange = try txBuilder.addChangeIfNeeded(address: changeAddr)
        assert(addedChange)
        XCTAssertEqual(txBuilder.outputs.count, 2)
        XCTAssertEqual(
            try txBuilder.getExplicitInput().checkedAdd(rhs: txBuilder.getImplicitInput()).coin,
            try txBuilder.getExplicitOutput().checkedAdd(rhs: Value(coin: txBuilder.fee!)).coin
        )
        XCTAssertNoThrow(try txBuilder.build())
    }
}
