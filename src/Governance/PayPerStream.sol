// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Subscription.sol"; // Import the Subscription contract

contract PayPerStream is Ownable {
    IERC20 public governanceToken;
    Subscription public subscriptionContract;

    // Price per stream in governance tokens (e.g., 1 token per stream)
    uint256 public streamPrice;

    event StreamPurchased(address user, uint256 streamId);

    constructor(address _governanceToken, uint256 _streamPrice, address _subscriptionContract) {
        governanceToken = IERC20(_governanceToken);
        streamPrice = _streamPrice;
        subscriptionContract = Subscription(_subscriptionContract);
    }

    /**
     * @dev Purchase a single stream.
     * @param streamId The ID of the stream being purchased.
     */
    function purchaseStream(uint256 streamId) public {
        uint256 price = streamPrice;

        // Apply 50% discount for subscribers
        if (subscriptionContract.hasActiveSubscription(msg.sender)) {
            price = price / 2;
        }

        require(governanceToken.transferFrom(msg.sender, owner(), price), "Payment failed");

        emit StreamPurchased(msg.sender, streamId);
    }
}