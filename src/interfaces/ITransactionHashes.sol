// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITransactionHashes {
    function getTransactionsHash(
        uint256 blockNumber
    ) external view returns (bytes32);
    function startingBlock() external view returns (uint256);
    function updateTransactionsHash(
        uint256 blockNumber,
        bytes32 transactionsHash
    ) external;
}
