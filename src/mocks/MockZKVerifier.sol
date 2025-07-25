// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZKVerifier} from "../interfaces/IZKVerifier.sol";

contract MockZKVerifier is IZKVerifier {
    function verifyStateProof(
        uint256,
        bytes32,
        bytes calldata,
        bytes32
    ) external pure returns (bool) {
        return true;
    }
}
