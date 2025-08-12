// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./GovernanceToken.sol";

contract MusicDAO is Ownable {
    GovernanceToken public governanceToken;

    // Proposal structure
    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        uint256 startTime;
        uint256 endTime;
        bool executed;
    }

    // Mapping from proposal ID to Proposal
    mapping(uint256 => Proposal) public proposals;

    // Mapping from voter address to proposal ID to whether they have voted
    mapping(address => mapping(uint256 => bool)) public hasVoted;

    // Counter for proposal IDs
    uint256 public proposalCount;

    // Voting duration (e.g., 7 days)
    uint256 public constant VOTING_DURATION = 7 days;

    // Event emitted when a new proposal is created
    event ProposalCreated(uint256 id, string description, uint256 startTime, uint256 endTime);

    // Event emitted when a vote is cast
    event VoteCast(address voter, uint256 proposalId, uint256 voteWeight);

    // Event emitted when a proposal is executed
    event ProposalExecuted(uint256 id);

    constructor(address _governanceToken) {
        governanceToken = GovernanceToken(_governanceToken);
    }

    /**
     * @dev Creates a new proposal.
     * @param description A description of the proposal.
     */
    function createProposal(string memory description) public onlyOwner {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + VOTING_DURATION;

        proposalCount++;
        proposals[proposalCount] = Proposal({
            id: proposalCount,
            description: description,
            voteCount: 0,
            startTime: startTime,
            endTime: endTime,
            executed: false
        });

        emit ProposalCreated(proposalCount, description, startTime, endTime);
    }

    /**
     * @dev Allows a token holder to vote on a proposal.
     * @param proposalId The ID of the proposal to vote on.
     */
    function vote(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp >= proposal.startTime, "Voting has not started");
        require(block.timestamp <= proposal.endTime, "Voting has ended");
        require(!hasVoted[msg.sender][proposalId], "Already voted");

        uint256 voteWeight = governanceToken.balanceOf(msg.sender);
        require(voteWeight > 0, "No voting power");

        proposal.voteCount += voteWeight;
        hasVoted[msg.sender][proposalId] = true;

        emit VoteCast(msg.sender, proposalId, voteWeight);
    }

    /**
     * @dev Executes a proposal if it has enough votes.
     * @param proposalId The ID of the proposal to execute.
     */
    function executeProposal(uint256 proposalId) public onlyOwner {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp > proposal.endTime, "Voting has not ended");
        require(!proposal.executed, "Proposal already executed");

        // Example: Require at least 50% of total supply to pass a proposal
        uint256 totalSupply = governanceToken.totalSupply();
        require(proposal.voteCount > totalSupply / 2, "Not enough votes to pass");

        proposal.executed = true;

        // Perform the action described in the proposal (e.g., upgrade contract, change parameters)
        // This is where you would implement the logic for the proposal's action.

        emit ProposalExecuted(proposalId);
    }
}