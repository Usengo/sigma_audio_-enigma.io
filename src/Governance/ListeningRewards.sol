// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ListeningRewards is Ownable {
    IERC20 public governanceToken;

    // Reward amount per stream (e.g., 0.1 tokens per stream)
    uint256 public rewardPerStream;

    // Mapping from user address to total rewards earned
    mapping(address => uint256) public userRewards;

    event RewardEarned(address user, uint256 amount);

    constructor(address _governanceToken, uint256 _rewardPerStream) {
        governanceToken = IERC20(_governanceToken);
        rewardPerStream = _rewardPerStream;
    }

    /**
     * @dev Distribute rewards to a user for listening to a stream.
     * @param user The address of the user.
     */
    function earnReward(address user) public onlyOwner {
        userRewards[user] += rewardPerStream;
        emit RewardEarned(user, rewardPerStream);
    }

    /**
     * @dev Allow users to claim their earned rewards.
     */
    function claimRewards() public {
        uint256 rewards = userRewards[msg.sender];
        require(rewards > 0, "No rewards to claim");

        userRewards[msg.sender] = 0;
        require(governanceToken.transfer(msg.sender, rewards), "Transfer failed");
    }
}