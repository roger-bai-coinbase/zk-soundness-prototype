// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {MockZKVerifier} from "../src/mocks/MockZKVerifier.sol";
import {MockTransactionHashes} from "../src/mocks/MockTransactionHashes.sol";
import {State, SimpleRollup} from "../src/SimpleRollup.sol";

contract SimpleRollupTest is Test {
    SimpleRollup simpleRollup;
    MockZKVerifier mockZKVerifier;
    MockTransactionHashes mockTransactionHashes;

    address backupProposer = vm.addr(1);
    uint256 zkFinalizationDelay = 1 days;
    uint256 startingL2Block = vm.randomUint(100);

    function setUp() public {
        mockZKVerifier = new MockZKVerifier();
        mockTransactionHashes = new MockTransactionHashes(startingL2Block);
        simpleRollup = new SimpleRollup(
            mockZKVerifier,
            mockTransactionHashes,
            zkFinalizationDelay,
            State({
                blockNumber: startingL2Block,
                state: keccak256(abi.encode(startingL2Block))
            }),
            backupProposer
        );
    }

    function testPropose() public {
        vm.expectRevert("Block number is not valid.");
        simpleRollup.propose(
            startingL2Block,
            keccak256(abi.encode(startingL2Block))
        );

        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );

        (
            uint256 blockNumber,
            bytes32 state,
            uint256 timestampProved
        ) = simpleRollup.currentProposal();
        assertEq(blockNumber, startingL2Block + 1);
        assertEq(state, keccak256(abi.encode(startingL2Block + 1)));
        assertEq(timestampProved, 0);

        vm.expectRevert("Proposal has already been submitted.");
        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );
    }

    function testProposeOnlyBackupProposer() public {
        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );
        simpleRollup.prove(abi.encode(0x1234));

        simpleRollup.challengeProof(
            keccak256(abi.encode(0x1234)),
            abi.encode(0x1234)
        );
        assertEq(simpleRollup.zkFailed(), true);

        vm.expectRevert("ZK down. Only backup proposer can propose.");
        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );

        vm.prank(backupProposer);
        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );

        (
            uint256 blockNumber,
            bytes32 state,
            uint256 timestampProved
        ) = simpleRollup.currentProposal();
        assertEq(blockNumber, startingL2Block + 1);
        assertEq(state, keccak256(abi.encode(startingL2Block + 1)));
        assertEq(timestampProved, 0);
    }

    function testProve() public {
        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );
        simpleRollup.prove(abi.encode(0x1234));

        (
            uint256 blockNumber,
            bytes32 state,
            uint256 timestampProved
        ) = simpleRollup.currentProposal();
        assertEq(blockNumber, startingL2Block + 1);
        assertEq(state, keccak256(abi.encode(startingL2Block + 1)));
        assertEq(timestampProved, block.timestamp);

        vm.expectRevert("Proposal has already been proved.");
        simpleRollup.prove(abi.encode(0x1));
    }

    function testProveOnlyBackupProposer() public {
        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );
        simpleRollup.prove(abi.encode(0x1234));

        simpleRollup.challengeProof(
            keccak256(abi.encode(0x1234)),
            abi.encode(0x1234)
        );
        assertEq(simpleRollup.zkFailed(), true);

        vm.prank(backupProposer);
        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );

        vm.expectRevert("ZK down. Only backup proposer can provide a proof.");
        simpleRollup.prove(abi.encode(0x1234));

        vm.prank(backupProposer);
        simpleRollup.prove(abi.encode(0x1234));

        (
            uint256 blockNumber,
            bytes32 state,
            uint256 timestampProved
        ) = simpleRollup.currentProposal();
        assertEq(blockNumber, startingL2Block + 1);
        assertEq(state, keccak256(abi.encode(startingL2Block + 1)));
        assertEq(timestampProved, block.timestamp);
    }

    function testFinalize() public {
        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );

        vm.expectRevert("Proposal has not been proved yet.");
        simpleRollup.finalize();

        simpleRollup.prove(abi.encode(0x1234));

        vm.expectRevert(
            "Not enough time to enable refutation of proof system."
        );
        simpleRollup.finalize();

        vm.warp(block.timestamp + zkFinalizationDelay);
        simpleRollup.finalize();

        (uint256 blockNumber, bytes32 state) = simpleRollup.currentState();
        assertEq(blockNumber, startingL2Block + 1);
        assertEq(state, keccak256(abi.encode(startingL2Block + 1)));
    }

    function testChallengeProof() public {
        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );

        vm.expectRevert("Proposal has not been proved yet.");
        simpleRollup.challengeProof(
            keccak256(abi.encode(0x1234)),
            abi.encode(0x1234)
        );

        simpleRollup.prove(abi.encode(0x1234));

        vm.expectRevert("Alternate state is the same as the proposed state.");
        simpleRollup.challengeProof(
            keccak256(abi.encode(startingL2Block + 1)),
            abi.encode(0x1234)
        );

        simpleRollup.challengeProof(
            keccak256(abi.encode(0x1234)),
            abi.encode(0x1235)
        );

        assertEq(simpleRollup.zkFailed(), true);
        (
            uint256 blockNumber,
            bytes32 state,
            uint256 timestampProved
        ) = simpleRollup.currentProposal();
        assertEq(blockNumber, 0);
        assertEq(state, bytes32(0));
        assertEq(timestampProved, 0);

        vm.expectRevert("ZK has already failed.");
        simpleRollup.challengeProof(
            keccak256(abi.encode(0x1234)),
            abi.encode(0x1234)
        );
    }

    function testCannotChallengeProofAfterFinalize() public {
        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );
        simpleRollup.prove(abi.encode(0x1234));

        vm.warp(block.timestamp + zkFinalizationDelay);

        vm.expectRevert("Proposal is finalized.");
        simpleRollup.challengeProof(
            keccak256(abi.encode(0x1234)),
            abi.encode(0x1234)
        );
    }

    function testUseZKAgain() public {
        vm.expectRevert("ZK has not failed yet.");
        simpleRollup.useZKAgain();

        simpleRollup.propose(
            startingL2Block + 1,
            keccak256(abi.encode(startingL2Block + 1))
        );
        simpleRollup.prove(abi.encode(0x1234));

        simpleRollup.challengeProof(
            keccak256(abi.encode(0x1234)),
            abi.encode(0x1234)
        );
        assertEq(simpleRollup.zkFailed(), true);

        vm.expectRevert("Only backup proposer can choose to use ZK again.");
        simpleRollup.useZKAgain();

        vm.prank(backupProposer);
        simpleRollup.useZKAgain();

        assertEq(simpleRollup.zkFailed(), false);
    }
}
