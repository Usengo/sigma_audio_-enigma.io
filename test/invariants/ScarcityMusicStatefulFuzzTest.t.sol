// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {ScarcityMusicNFT} from "../../src/music/ScarcityMusicNFT.sol";
contract ScarcityMusicStatefulFuzzTest is Test {
    ScarcityMusicNFT private scarcityMusic;
    address private owner;
    address private user;

    // Track minted token IDs and their details
    struct TokenDetails {
        address owner;
        string onChainMetadata;
        string offChainURI;
        address royaltyRecipient;
        uint96 royaltyValue;
    }
    mapping(uint256 => TokenDetails) private mintedTokens;
    uint256 private lastTokenId;

    function setUp() public {
        owner = address(this);
        user = address(0x1234);
        scarcityMusic = new ScarcityMusicNFT("ScarcityMusicNFT", "SM", 500); // 5% platform fee
    }

    /**
     * @dev Stateful fuzz test for the `mintMusicNFT` function.
     * @param to The address that will own the minted NFT.
     * @param onChainMetadata The on-chain metadata.
     * @param offChainURI The off-chain metadata URI.
     * @param royaltyRecipient The address to receive royalties.
     * @param royaltyValue The royalty percentage in basis points.
     */
    function testFuzz_StatefulMintMusicNFT(
    address to,
    string memory onChainMetadata,
    string memory offChainURI,
    address royaltyRecipient,
    uint96 royaltyValue
) public {
    // Ensure `to` and `royaltyRecipient` are not zero addresses
    vm.assume(to != address(0));
    vm.assume(royaltyRecipient != address(0));

    // Ensure `royaltyValue` does not exceed 100% (10,000 basis points)
    vm.assume(royaltyValue <= 10000);

    // Record the current token ID counter
    uint256 initialTokenId = scarcityMusic.tokenIds();

    // Set up expected event emission BEFORE the mint operation
    vm.expectEmit(true, true, true, true);
    emit ScarcityMusicNFT.MusicMinted(initialTokenId + 1, onChainMetadata, offChainURI, to);

    // Execute as owner
    vm.prank(scarcityMusic.owner());
    
    // Mint the NFT
    uint256 newTokenId = scarcityMusic.mintMusicNFT(
        to,
        onChainMetadata,
        offChainURI,
        royaltyRecipient,
        royaltyValue
    );

    // Store token details for later verification
    mintedTokens[newTokenId] = TokenDetails({
        owner: to,
        onChainMetadata: onChainMetadata,
        offChainURI: offChainURI,
        royaltyRecipient: royaltyRecipient,
        royaltyValue: royaltyValue
    });

    // Invariant 1: Token ID should increment by 1
    assertEq(newTokenId, initialTokenId + 1, "Token ID did not increment correctly");

    // Invariant 2: Token should be owned by the `to` address
    assertEq(scarcityMusic.ownerOf(newTokenId), to, "Token ownership mismatch");

    // Invariant 3: On-chain metadata should match the input
    assertEq(scarcityMusic.tokenMetadata(newTokenId), onChainMetadata, "On-chain metadata mismatch");

    // Invariant 4: Off-chain metadata URI should match the input
    assertEq(scarcityMusic.tokenURI(newTokenId), offChainURI, "Off-chain metadata URI mismatch");

    // Invariant 5: Royalty information should match the input
    (address recipient, uint256 royaltyAmount) = scarcityMusic.royaltyInfo(newTokenId, 100 ether);
    assertEq(recipient, royaltyRecipient, "Royalty recipient mismatch");
    assertEq(royaltyAmount, (100 ether * royaltyValue) / 10000, "Royalty amount mismatch");

    // Invariant 6: No duplicate token IDs
    assertFalse(mintedTokens[newTokenId].owner == address(0), "Duplicate token ID detected");

    // Update the last token ID
    lastTokenId = newTokenId;
}
    /**
     * @dev Verify invariants after all fuzz runs.
     */
    function invariant_checkState() public view {
        // Check that all minted tokens have consistent state
        for (uint256 i = 1; i <= lastTokenId; i++) {
            TokenDetails memory details = mintedTokens[i];

            // Verify token ownership
            assertEq(scarcityMusic.ownerOf(i), details.owner, "Token ownership mismatch");

            // Verify on-chain metadata
            assertEq(scarcityMusic.tokenMetadata(i), details.onChainMetadata, "On-chain metadata mismatch");

            // Verify off-chain metadata URI
            assertEq(scarcityMusic.tokenURI(i), details.offChainURI, "Off-chain metadata URI mismatch");

            // Verify royalty information
            (address recipient, uint256 royaltyAmount) = scarcityMusic.royaltyInfo(i, 100 ether);
            assertEq(recipient, details.royaltyRecipient, "Royalty recipient mismatch");
            assertEq(royaltyAmount, (100 ether * details.royaltyValue) / 10000, "Royalty amount mismatch");
        }
    }
}