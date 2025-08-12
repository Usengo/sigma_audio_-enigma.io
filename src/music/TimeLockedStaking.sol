// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TimeLockedStaking is ReentrancyGuard, Ownable {
    IERC20 public governanceToken; // Governance token for staking
    IERC20 public rewardsToken; // Token users earn as rewards

    struct Stake {
        uint256 amount; // Staked amount
        uint256 lockUpPeriod; // Lock-up period in seconds
        uint256 stakedAt; // Timestamp when the stake was made
        uint256 rewardRate; // Reward rate for this stake
        bool isActive; // Whether the stake is active
        uint256 penaltyAmount; // Penalty for early withdrawal
    }

    mapping(address => Stake[]) public stakes; // User stakes
    mapping(uint256 => uint256) public rewardRates; // Reward rates for different lock-up periods

    event Staked(address indexed user, uint256 amount, uint256 lockUpPeriod);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);
    event RewardClaimed(address indexed user, uint256 reward);
    event EarlyWithdrawal(address indexed user, uint256 stakeIndex, uint256 penalty);
    event RewardRateUpdated(uint256 lockUpPeriod, uint256 newRate);

    constructor(address _governanceToken, address _rewardsToken) {
        governanceToken = IERC20(_governanceToken);
        rewardsToken = IERC20(_rewardsToken);

        // Set reward rates for different lock-up periods (e.g., 30 days, 90 days, 180 days)
        rewardRates[30 days] = 100; // 100 tokens per second per staked token
        rewardRates[90 days] = 300; // 300 tokens per second per staked token
        rewardRates[180 days] = 600; // 600 tokens per second per staked token
    }

    /**
     * @dev Stake governance tokens with a chosen lock-up period.
     * @param amount The amount of tokens to stake.
     * @param lockUpPeriod The lock-up period in seconds.
     */
    function stake(uint256 amount, uint256 lockUpPeriod) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        require(rewardRates[lockUpPeriod] > 0, "Invalid lock-up period");

        // Transfer tokens from the user to the contract
        require(
            governanceToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        // Create a new stake
        stakes[msg.sender].push(Stake({
            amount: amount,
            lockUpPeriod: lockUpPeriod,
            stakedAt: block.timestamp,
            rewardRate: rewardRates[lockUpPeriod],
            isActive: true,
            penaltyAmount: 0
        }));

        emit Staked(msg.sender, amount, lockUpPeriod);
    }

    /**
     * @dev Stop staking early and apply a 10% penalty.
     * @param stakeIndex The index of the stake to stop.
     */
    function stopStakingEarly(uint256 stakeIndex) external nonReentrant {
        require(stakeIndex < stakes[msg.sender].length, "Invalid stake index");
        Stake storage userStake = stakes[msg.sender][stakeIndex];
        require(userStake.isActive, "Stake is already stopped");

        // Calculate 10% penalty
        uint256 penalty = (userStake.amount * 10) / 100;
        userStake.penaltyAmount = penalty;

        // Mark the stake as inactive
        userStake.isActive = false;

        emit EarlyWithdrawal(msg.sender, stakeIndex, penalty);
    }

    /**
     * @dev Withdraw staked tokens after the lock-up period expires.
     * @param stakeIndex The index of the stake to withdraw.
     */
    function withdraw(uint256 stakeIndex) external nonReentrant {
        require(stakeIndex < stakes[msg.sender].length, "Invalid stake index");

        Stake storage userStake = stakes[msg.sender][stakeIndex];
        require(block.timestamp >= userStake.stakedAt + userStake.lockUpPeriod, "Lock-up period not expired");

        // Calculate rewards
        uint256 reward = calculateReward(msg.sender, stakeIndex);

        // Transfer staked tokens and rewards to the user
        uint256 amountToTransfer = userStake.amount;
        if (!userStake.isActive) {
            // Deduct the penalty if the stake was stopped early
            amountToTransfer -= userStake.penaltyAmount;
            require(
                governanceToken.transfer(owner(), userStake.penaltyAmount),
                "Penalty transfer failed"
            );
        }

        require(
            governanceToken.transfer(msg.sender, amountToTransfer),
            "Staked tokens transfer failed"
        );
        require(
            rewardsToken.transfer(msg.sender, reward),
            "Rewards transfer failed"
        );

        // Remove the stake
        stakes[msg.sender][stakeIndex] = stakes[msg.sender][stakes[msg.sender].length - 1];
        stakes[msg.sender].pop();

        emit Withdrawn(msg.sender, amountToTransfer, reward);
    }

    /**
     * @dev Claim rewards for a specific stake.
     * @param stakeIndex The index of the stake to claim rewards for.
     */
    function claimReward(uint256 stakeIndex) external nonReentrant {
        require(stakeIndex < stakes[msg.sender].length, "Invalid stake index");

        // Calculate rewards
        uint256 reward = calculateReward(msg.sender, stakeIndex);

        // Transfer rewards to the user
        require(
            rewardsToken.transfer(msg.sender, reward),
            "Rewards transfer failed"
        );

        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @dev Calculate rewards for a specific stake.
     * @param user The address of the user.
     * @param stakeIndex The index of the stake.
     * @return The calculated reward.
     */
    function calculateReward(address user, uint256 stakeIndex) public view returns (uint256) {
        Stake storage userStake = stakes[user][stakeIndex];
        uint256 stakedDuration = block.timestamp - userStake.stakedAt;
        return userStake.amount * userStake.rewardRate * stakedDuration / 1e18;
    }

    /**
     * @dev Update the reward rate for a specific lock-up period (only owner).
     * @param lockUpPeriod The lock-up period in seconds.
     * @param newRate The new reward rate.
     */
    function updateRewardRate(uint256 lockUpPeriod, uint256 newRate) external onlyOwner {
        require(newRate > 0, "Reward rate must be greater than 0");
        rewardRates[lockUpPeriod] = newRate;
        emit RewardRateUpdated(lockUpPeriod, newRate);
    }

    /**
     * @dev Get the total staked amount for a user.
     * @param user The address of the user.
     * @return The total staked amount.
     */
    function getTotalStaked(address user) external view returns (uint256) {
        uint256 totalStaked = 0;
        for (uint256 i = 0; i < stakes[user].length; i++) {
            totalStaked += stakes[user][i].amount;
        }
        return totalStaked;
    }
}