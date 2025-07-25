// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IZKVerifier {
    function verifyStateProof(
        uint256 blockNumber,
        bytes32 stateToProve,
        bytes memory proof,
        bytes32 transactionsHash
    ) external view returns (bool);
}
