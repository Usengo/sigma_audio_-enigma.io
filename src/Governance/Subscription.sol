// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Subscription is Ownable {
    IERC20 public governanceToken;

    // Subscription price in governance tokens (e.g., 100 tokens per month)
    uint256 public subscriptionPrice;

    // Mapping from user address to subscription expiry time
    mapping(address => uint256) public subscriptions;

    event Subscribed(address user, uint256 expiryTime);

    constructor(address _governanceToken, uint256 _subscriptionPrice) {
        governanceToken = IERC20(_governanceToken);
        subscriptionPrice = _subscriptionPrice;
    }

    /**
     * @dev Subscribe to the platform for a month.
     */
    function subscribe() public {
        require(governanceToken.transferFrom(msg.sender, owner(), subscriptionPrice), "Payment failed");

        uint256 expiryTime = block.timestamp + 30 days;
        subscriptions[msg.sender] = expiryTime;

        emit Subscribed(msg.sender, expiryTime);
    }

    /**
     * @dev Check if a user has an active subscription.
     * @param user The address of the user.
     * @return Whether the user has an active subscription.
     */
    function hasActiveSubscription(address user) public view returns (bool) {
        return subscriptions[user] >= block.timestamp;
    }
}