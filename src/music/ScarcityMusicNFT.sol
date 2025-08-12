// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

/**
 * @title ScarcityMusicNFT
 * @notice ERC721-based music NFT with on-chain + off-chain metadata,
 *         EIP-2981 royalties, and EIP-712 artist-signed mint authorization.
 * @dev Features:
 *      - EIP-712 typed data signatures for artist-approved minting
 *      - On-chain + off-chain metadata separation
 *      - EIP-2981 standard royalty reporting
 *      - Platform fee mechanism
 *      - Controlled revenue distribution from authorized sources
 */
contract ScarcityMusicNFT is ERC721, Ownable, IERC2981, ReentrancyGuard, EIP712 {
    using Counters for Counters.Counter;
    using SafeCast for uint256;
    using ECDSA for bytes32;

    Counters.Counter private _tokenIds;

    /// @notice Platform fee in basis points (1% = 100)
    uint96 public platformFee;

    /// @notice Address receiving platform fees
    address public platformOwner;

    /// @dev Mapping tokenId → on-chain metadata string
    mapping(uint256 => string) private _tokenMetadata;

    /// @dev Mapping tokenId → off-chain metadata URI (e.g. IPFS/Arweave)
    mapping(uint256 => string) private _tokenURIs;

    /// @notice Tracks pending withdrawals for each address
    mapping(address => uint256) public pendingWithdrawals;

    /// @notice Nonce tracking per artist to prevent signature replay
    mapping(address => uint256) public nonces;

    /// @notice Authorized addresses allowed to send revenue
    mapping(address => bool) public revenueSources;

    /// @dev Struct for storing royalty information per token
    struct RoyaltyInfo {
        address recipient;
        uint96 royaltyFraction;
    }

    mapping(uint256 => RoyaltyInfo) private _tokenRoyalties;

    /// @notice Emitted when a music NFT is minted
    event MusicMinted(
        address indexed artist,
        uint256 indexed tokenId,
        address indexed to,
        string onChainMetadata,
        string offChainURI
    );

    /// @notice Emitted when revenue is distributed
    event RevenueDistributed(
        uint256 indexed tokenId,
        uint256 amount,
        address artist,
        address seller
    );

    /// @notice Emitted when a withdrawal occurs
    event Withdrawal(address indexed recipient, uint256 amount);

    /// @notice Emitted when revenue source permissions are updated
    event RevenueSourceUpdated(address indexed source, bool allowed);

    /// @dev EIP-712 Mint typed data hash definition
    bytes32 public constant MINT_TYPEHASH =
        keccak256(
            "Mint(address artist,address to,string onChainMetadata,string offChainURI,address royaltyRecipient,uint96 royaltyValue,uint256 nonce)"
        );

    /**
     * @notice Contract constructor
     * @param name ERC721 token name
     * @param symbol ERC721 token symbol
     * @param _platformFee Platform fee in basis points
     */
    constructor(
        string memory name,
        string memory symbol,
        uint96 _platformFee
    ) ERC721(name, symbol) EIP712(name, "1") {
        require(_platformFee <= 10000, "Invalid platform fee");
        platformFee = _platformFee;
        platformOwner = msg.sender;
        revenueSources[msg.sender] = true;
    }

    /**
     * @notice Mint a music NFT authorized by the artist via EIP-712 signature
     * @dev Prevents replay attacks by incrementing nonce per artist.
     * @param artist The artist's address (signer)
     * @param to Recipient of the minted NFT
     * @param onChainMetadata On-chain metadata (short form)
     * @param offChainURI URI for extended metadata and asset pointers
     * @param signature Artist's EIP-712 signature
     * @param royaltyRecipient Address receiving royalties
     * @param royaltyValue Royalty percentage in basis points
     * @return tokenId Newly minted token ID
     */
    function mintMusicWithSignature(
        address artist,
        address to,
        string memory onChainMetadata,
        string memory offChainURI,
        bytes memory signature,
        address royaltyRecipient,
        uint96 royaltyValue
    ) external nonReentrant returns (uint256 tokenId) {
        require(artist != address(0), "Invalid artist");
        require(to != address(0), "Invalid recipient");
        require(royaltyRecipient != address(0), "Invalid royalty recipient");
        require(royaltyValue <= 10000, "Royalty value too high");
        require(bytes(onChainMetadata).length > 0, "Empty metadata");
        require(bytes(offChainURI).length > 0, "Empty URI");
        require(platformFee + royaltyValue <= 10000, "Total fees > 100%");

        bytes32 structHash = keccak256(
            abi.encode(
                MINT_TYPEHASH,
                artist,
                to,
                keccak256(bytes(onChainMetadata)),
                keccak256(bytes(offChainURI)),
                royaltyRecipient,
                royaltyValue,
                nonces[artist]
            )
        );

        bytes32 digest = _hashTypedDataV4(structHash);

        bool valid = SignatureChecker.isValidSignatureNow(artist, digest, signature);
        require(valid, "Invalid or unauthorized signature");

        nonces[artist]++;

        _tokenIds.increment();
        tokenId = SafeCast.toUint256(_tokenIds.current());
        _mint(to, tokenId);

        _setTokenMetadata(tokenId, onChainMetadata);
        _setTokenURI(tokenId, offChainURI);

        _setTokenRoyalty(tokenId, royaltyRecipient, royaltyValue);

        emit MusicMinted(artist, tokenId, to, onChainMetadata, offChainURI);

        return tokenId;
    }

    /**
     * @notice Internal helper to set on-chain metadata
     * @param tokenId NFT ID
     * @param metadata On-chain metadata string
     */
    function _setTokenMetadata(uint256 tokenId, string memory metadata) internal {
        require(_exists(tokenId), "Nonexistent token");
        require(bytes(metadata).length > 0, "Empty metadata");
        _tokenMetadata[tokenId] = metadata;
    }

    /**
     * @notice Internal helper to set off-chain metadata URI
     * @param tokenId NFT ID
     * @param uri URI string
     */
    function _setTokenURI(uint256 tokenId, string memory uri) internal {
        require(_exists(tokenId), "Nonexistent token");
        require(bytes(uri).length > 0, "Empty URI");
        _tokenURIs[tokenId] = uri;
    }

    /**
     * @notice Get off-chain metadata URI for a token
     * @param tokenId NFT ID
     * @return string Metadata URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Nonexistent token");
        return _tokenURIs[tokenId];
    }

    /**
     * @notice Get on-chain metadata for a token
     * @param tokenId NFT ID
     * @return string On-chain metadata
     */
    function tokenMetadata(uint256 tokenId) public view returns (string memory) {
        require(_exists(tokenId), "Nonexistent token");
        return _tokenMetadata[tokenId];
    }

    /**
     * @notice Distribute revenue for a specific token from an authorized source
     * @dev Splits payment into platform fee, artist royalty, and seller proceeds.
     * @param tokenId NFT ID
     * @param amount Revenue amount in wei
     */
    function distributeRevenue(uint256 tokenId, uint256 amount) external payable nonReentrant {
        require(revenueSources[msg.sender], "Unauthorized source");
        require(_exists(tokenId), "Nonexistent token");
        require(amount > 0, "Invalid amount");
        require(msg.value == amount, "Payment mismatch");

        address seller = ownerOf(tokenId);
        require(seller != address(0), "Token not owned");

        uint256 platformFeeAmount = (amount * platformFee) / 10000;
        (address artist, uint256 royaltyAmount) = royaltyInfo(tokenId, amount);

        require(royaltyAmount + platformFeeAmount <= amount, "Excessive royalties/fees");

        pendingWithdrawals[platformOwner] += platformFeeAmount;
        if (royaltyAmount > 0 && artist != address(0)) {
            pendingWithdrawals[artist] += royaltyAmount;
        }

        uint256 sellerAmount = amount - platformFeeAmount - royaltyAmount;
        if (sellerAmount > 0) {
            pendingWithdrawals[seller] += sellerAmount;
        }

        emit RevenueDistributed(tokenId, amount, artist, seller);
    }

    /**
     * @notice Withdraw accumulated funds
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds available");
        pendingWithdrawals[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        emit Withdrawal(msg.sender, amount);
    }

    /**
     * @dev Internal function to set token royalties
     * @param tokenId NFT ID
     * @param recipient Royalty recipient
     * @param value Royalty percentage in basis points
     */
    function _setTokenRoyalty(
        uint256 tokenId,
        address recipient,
        uint96 value
    ) internal {
        require(_exists(tokenId), "Nonexistent token");
        require(value <= 10000, "Royalty too high");
        _tokenRoyalties[tokenId] = RoyaltyInfo(recipient, value);
    }

    /**
     * @notice Returns royalty information for a token sale
     * @param tokenId NFT ID
     * @param salePrice Sale price in wei
     * @return receiver Royalty recipient address
     * @return royaltyAmount Amount owed in wei
     */
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) public view override returns (address receiver, uint256 royaltyAmount) {
        RoyaltyInfo memory royalty = _tokenRoyalties[tokenId];
        if (royalty.recipient == address(0) || royalty.royaltyFraction == 0) {
            return (address(0), 0);
        }
        royaltyAmount = (salePrice * royalty.royaltyFraction) / 10000;
        return (royalty.recipient, royaltyAmount);
    }

    /**
     * @notice Update platform fee
     * @param newFee New fee in basis points
     */
    function setPlatformFee(uint96 newFee) external onlyOwner {
        require(newFee <= 10000, "Invalid fee");
        platformFee = newFee;
    }

    /**
     * @notice Update platform owner address
     * @param newOwner New owner address
     */
    function setPlatformOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        platformOwner = newOwner;
    }

    /**
     * @notice Authorize a new revenue source
     * @param source Address to authorize
     */
    function addRevenueSource(address source) external onlyOwner {
        require(source != address(0), "Invalid address");
        revenueSources[source] = true;
        emit RevenueSourceUpdated(source, true);
    }

    /**
     * @notice Remove authorization for a revenue source
     * @param source Address to revoke
     */
    function removeRevenueSource(address source) external onlyOwner {
        revenueSources[source] = false;
        emit RevenueSourceUpdated(source, false);
    }

    /**
     * @inheritdoc ERC721
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
