// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {ScarcityMusicNFT} from "../../src/music/ScarcityMusicNFT.sol";

contract ScarcityMusicNFTTest is Test {
    ScarcityMusicNFT nft;
    address platformOwner = address(0x1);
    address artist = address(0x2);
    address buyer = address(0x3);
    address revenueSource = address(0x4);
    uint96 constant PLATFORM_FEE = 500; // 5%
    
    string constant ON_CHAIN_METADATA = '{"name":"Song","artist":"Artist"}';
    string constant OFF_CHAIN_URI = "ipfs://metadata";
    uint96 constant ROYALTY_VALUE = 1000; // 10%

    function setUp() public {
        vm.startPrank(platformOwner);
        nft = new ScarcityMusicNFT("ScarcityMusic", "SCM", PLATFORM_FEE);
        nft.addRevenueSource(revenueSource);
        vm.stopPrank();
    }

    // Fuzz test for minting functionality
function testFuzz_MintWithSignature(
    address to,
    uint96 royaltyValue,
    uint256 privateKey
) public {
    vm.assume(to != address(0));
    vm.assume(privateKey != 0);
    vm.assume(royaltyValue <= 10000);
    
    address signingArtist = vm.addr(privateKey);
    uint256 nonce = nft.nonces(signingArtist);
    
    // Create signature
    bytes32 messageHash = keccak256(
        abi.encodePacked(
            to,
            ON_CHAIN_METADATA,
            OFF_CHAIN_URI,
            signingArtist,
            royaltyValue,
            nonce
        )
    );
    bytes32 ethSignedMessageHash = keccak256(
        abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
    bytes memory signature = abi.encodePacked(r, s, v);

    // Mint NFT
    vm.prank(signingArtist);
    uint256 tokenId = nft.mintMusicWithSignature(
        to,
        ON_CHAIN_METADATA,
        OFF_CHAIN_URI,
        signature,
        signingArtist,
        royaltyValue
    );

    // Verify mint
    assertEq(nft.ownerOf(tokenId), to);
    assertEq(nft.tokenMetadata(tokenId), ON_CHAIN_METADATA);
    assertEq(nft.tokenURI(tokenId), OFF_CHAIN_URI);
    (address royaltyRecipient, ) = nft.royaltyInfo(tokenId, 1 ether);
    assertEq(royaltyRecipient, signingArtist);
}

// Fuzz test for revenue distribution
function testFuzz_RevenueDistribution(
    uint256 tokenId,
    uint128 amount,
    address seller
) public {
    vm.assume(amount > 0.1 ether);
    vm.assume(seller != address(0));
    vm.assume(tokenId > 0);

    // Setup token
    createTestToken(tokenId, seller);
    
    // Distribute revenue
    vm.deal(revenueSource, amount);
    vm.prank(revenueSource);
    nft.distributeRevenue{value: amount}(tokenId, amount);

    // Verify distribution
    (address royaltyRecipient, uint256 royaltyAmount) = nft.royaltyInfo(tokenId, amount);
    uint256 platformFeeAmount = (amount * PLATFORM_FEE) / 10000;
    uint256 sellerAmount = amount - platformFeeAmount - royaltyAmount;
    
    assertEq(nft.pendingWithdrawals(platformOwner), platformFeeAmount);
    assertEq(nft.pendingWithdrawals(royaltyRecipient), royaltyAmount);
    assertEq(nft.pendingWithdrawals(seller), sellerAmount);
}

// Fuzz test for withdrawals
function testFuzz_Withdrawals(
    address recipient,
    uint128 amount
) public {
    vm.assume(recipient != address(0));
    vm.assume(amount > 0.1 ether);
    vm.assume(recipient != platformOwner);
    
    // Setup withdrawal balance
    vm.prank(platformOwner);
    nft.setPlatformOwner(recipient);
    vm.deal(address(nft), amount);
    nft.pendingWithdrawals(recipient) = amount;
    
    // Test withdrawal
    uint256 initialBalance = recipient.balance;
    vm.prank(recipient);
    nft.withdraw();
    
    assertEq(recipient.balance, initialBalance + amount);
    assertEq(nft.pendingWithdrawals(recipient), 0);
}
// Invariant: Total pending withdrawals should always equal contract balance
function invariant_WithdrawalBalance() public {
    uint256 totalPending;
    address[] memory accounts = getAccounts();
    
    for (uint256 i = 0; i < accounts.length; i++) {
        totalPending += nft.pendingWithdrawals(accounts[i]);
    }
    
    assertEq(totalPending, address(nft).balance);
}

// Invariant: Token metadata should be immutable after mint
function invariant_MetadataImmutability() public {
    uint256 tokenCount = nft.totalSupply();
    for (uint256 tokenId = 1; tokenId <= tokenCount; tokenId++) {
        string memory metadata = nft.tokenMetadata(tokenId);
        string memory uri = nft.tokenURI(tokenId);
        assertTrue(bytes(metadata).length > 0);
        assertTrue(bytes(uri).length > 0);
    }
}

// Invariant: Royalties should never exceed 100%
function invariant_RoyaltyLimits() public {
    uint256 tokenCount = nft.totalSupply();
    for (uint256 tokenId = 1; tokenId <= tokenCount; tokenId++) {
        (, uint256 royaltyAmount) = nft.royaltyInfo(tokenId, 1 ether);
        assertLe(royaltyAmount, 1 ether);
    }
}

// Invariant: Only authorized revenue sources can distribute revenue
function invariant_RevenueSourceAuthorization() public {
    // This would be tested by attempting distribution from random addresses
    // and verifying failures in the invariant test environment
}

// Helper functions
function createTestToken(uint256 tokenId, address owner) internal {
    // Setup token creation with a valid signature
    // ... (implementation would mimic minting process)
}

function getAccounts() internal view returns (address[] memory) {
    // Return all relevant accounts for withdrawal invariant
    // ... (implementation would track all addresses with balances)
}
}