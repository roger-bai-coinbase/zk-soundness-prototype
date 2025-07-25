// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ITransactionHashes} from "../interfaces/ITransactionHashes.sol";

contract MockTransactionHashes is ITransactionHashes {
    uint256 internal immutable STARTING_BLOCK;

    // block number -> transactions hash
    mapping(uint256 => bytes32) internal transactionsHashes;

    constructor(uint256 _startingBlock) {
        STARTING_BLOCK = _startingBlock;
    }

    function getTransactionsHash(
        uint256 blockNumber
    ) external view returns (bytes32) {
        return transactionsHashes[blockNumber];
    }

    function updateTransactionsHash(
        uint256 blockNumber,
        bytes32 transactionsHash
    ) external {
        transactionsHashes[blockNumber] = transactionsHash;
    }

    function startingBlock() external view returns (uint256) {
        return STARTING_BLOCK;
    }
}
