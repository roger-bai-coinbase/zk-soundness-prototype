// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZKVerifier} from "./interfaces/IZKVerifier.sol";
import {ITransactionHashes} from "./interfaces/ITransactionHashes.sol";

struct Proposal {
    // L2 block number
    uint256 blockNumber;
    // L2 state
    bytes32 state;
    // When the proposal was proved
    uint256 timestampProved;
}

struct State {
    // L2 block number
    uint256 blockNumber;
    // L2 state
    bytes32 state;
}

contract SimpleRollup {
    // Verifies ZK proofs
    IZKVerifier public zkVerifier;
    // Fetches L2 transaction hashes
    ITransactionHashes public transactionHashes;

    // Verified state
    State public currentState;
    // Proposed state
    Proposal public currentProposal;

    // Time to wait before finalizing a proposal
    uint256 public zkFinalizationDelay;
    // Whether the ZK proof system has failed
    bool public zkFailed;

    address backupProposer;

    event ProposalSubmitted(address proposer, Proposal proposal);
    event ProposalProved(address prover, Proposal proposal);
    event StateUpdated(bytes32 newState);
    event ZKFailed(
        uint256 blockNumber,
        bytes32 proposedState,
        bytes32 alternateState
    );

    constructor(
        IZKVerifier _zkVerifier,
        ITransactionHashes _transactionHashes,
        uint256 _zkFinalizationDelay,
        State memory initialState,
        address _backupProposer
    ) {
        zkVerifier = _zkVerifier;
        transactionHashes = _transactionHashes;
        currentState = initialState;
        zkFinalizationDelay = _zkFinalizationDelay;

        backupProposer = _backupProposer;
    }

    function useZKAgain() external {
        require(zkFailed, "ZK has not failed yet.");
        require(
            msg.sender == backupProposer,
            "Only backup proposer can choose to use ZK again."
        );
        zkFailed = false;
    }

    function propose(uint256 blockNumber, bytes32 state) public {
        require(
            !zkFailed || msg.sender == backupProposer,
            "ZK down. Only backup proposer can propose."
        );
        require(currentProposal.blockNumber == 0, "Proposal has already been submitted.");
        require(
            blockNumber > currentState.blockNumber,
            "Block number is not valid."
        );

        currentProposal = Proposal({
            blockNumber: blockNumber,
            state: state,
            timestampProved: 0
        });

        emit ProposalSubmitted(msg.sender, currentProposal);
    }

    function prove(bytes calldata proof) external {
        require(
            !zkFailed || msg.sender == backupProposer,
            "ZK down. Only backup proposer can provide a proof."
        );
        require(
            currentProposal.timestampProved == 0,
            "Proposal has already been proved."
        );

        Proposal memory proposal = currentProposal;
        require(
            zkVerifier.verifyStateProof(
                proposal.blockNumber,
                proposal.state,
                proof,
                transactionHashes.getTransactionsHash(proposal.blockNumber)
            ),
            "Proof is invalid."
        );

        currentProposal.timestampProved = block.timestamp;

        emit ProposalProved(msg.sender, proposal);
    }

    function finalize() external {
        require(
            currentProposal.timestampProved > 0,
            "Proposal has not been proved yet."
        );
        require(
            block.timestamp - currentProposal.timestampProved >=
                zkFinalizationDelay,
            "Not enough time to enable refutation of proof system."
        );

        currentState = State({
            blockNumber: currentProposal.blockNumber,
            state: currentProposal.state
        });

        delete currentProposal;

        emit StateUpdated(currentState.state);
    }

    function challengeProof(
        bytes32 alternateState,
        bytes calldata proof
    ) external {
        require(!zkFailed, "ZK has already failed.");
        require(
            alternateState != currentProposal.state,
            "Alternate state is the same as the proposed state."
        );

        require(
            currentProposal.timestampProved > 0,
            "Proposal has not been proved yet."
        );
        require(
            block.timestamp - currentProposal.timestampProved <
                zkFinalizationDelay,
            "Proposal is finalized."
        );

        Proposal memory proposal = currentProposal;
        require(
            zkVerifier.verifyStateProof(
                proposal.blockNumber,
                alternateState,
                proof,
                transactionHashes.getTransactionsHash(proposal.blockNumber)
            ),
            "Proof is invalid."
        );

        zkFailed = true;
        delete currentProposal;
        emit ZKFailed(proposal.blockNumber, proposal.state, alternateState);
    }
}
