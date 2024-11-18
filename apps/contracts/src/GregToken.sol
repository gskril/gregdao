// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

import "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import "@ensdomains/ens-contracts/contracts/utils/NameEncoder.sol";
import "@ensdomains/ens-contracts/contracts/wrapper/INameWrapper.sol";
import "@ensdomains/ens-contracts/contracts/ethregistrar/IBaseRegistrar.sol";

import "./lib/Strings.sol";

contract GregToken is
    ERC20,
    ERC20Burnable,
    ERC20Pausable,
    Ownable,
    ERC20Permit,
    ERC20Votes
{
    using Strings for *;
    using NameEncoder for string;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error IneligibleName();
    error Unauthorized();
    error AlreadyClaimed();
    error ClaimClosed();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Claim(
        string indexed name,
        address indexed owner,
        uint256 indexed amount
    );
    event CloseClaim();

    /*//////////////////////////////////////////////////////////////
                               PARAMETERS
    //////////////////////////////////////////////////////////////*/

    bool public isClaimOpen = true;
    uint256 public constant minimumMintInterval = 365 days;
    ENS public constant ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    INameWrapper public constant nameWrapper =
        INameWrapper(0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401);
    IBaseRegistrar public constant baseRegistrar =
        IBaseRegistrar(0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85);

    uint256 public nextMint; // Timestamp

    mapping(bytes dnsEncodedName => bool claimed) public claimedNames;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address initialOwner
    ) ERC20("Greg", "GREG") Ownable(initialOwner) ERC20Permit("Greg") {
        nextMint = block.timestamp + minimumMintInterval;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Mint tokens to the sender if they own an ENS name that includes "greg".
     * @param name ENS name in full format, like "gregskril.eth"
     */
    function claim(string calldata name) external onlyClaimOpen {
        (bool eligible, string memory label) = isEligible(name);
        if (!eligible) revert IneligibleName();

        // Find the owner of the name in ENS registry
        (bytes memory dnsEncodedName, bytes32 node) = name.dnsEncodeName();
        address owner = ens.owner(node);

        // If the owner is NameWrapper, check the wrapped owner
        if (owner == address(nameWrapper)) {
            owner = nameWrapper.ownerOf(uint256(node));
        }

        // Check that the sender is the owner of the name
        if (owner != msg.sender) revert Unauthorized();

        // Check that the name hasn't already been claimed
        if (claimedNames[dnsEncodedName]) revert AlreadyClaimed();

        // Check when the name expires
        uint256 tokenId = uint256(keccak256(bytes(label)));
        uint256 expiresAt = baseRegistrar.nameExpires(tokenId);

        // Calculate the amount of tokens to mint based on the time left until expiration
        uint256 timeLeft = expiresAt - block.timestamp;
        uint256 _amount = 1_000e18 * (timeLeft / 365 days); // 1k tokens per year
        uint256 amount = _amount > 5_000e18 ? 5_000e18 : _amount; // Max 5k tokens

        // Mint the tokens
        emit Claim(name, msg.sender, amount);
        claimedNames[dnsEncodedName] = true;
        _mint(msg.sender, amount);
    }

    function isEligible(
        string calldata name
    ) public pure returns (bool, string memory) {
        Strings.slice memory nameSlice = name.toSlice();
        Strings.slice memory substringSlice = "greg".toSlice();
        Strings.slice memory delim = ".".toSlice();
        uint256 parts = nameSlice.count(delim);

        // Check if the name is a 2LD and includes "greg"
        if (parts != 1 || !nameSlice.contains(substringSlice)) {
            return (false, "");
        }

        // Check if the TLD is .eth
        Strings.slice memory label = nameSlice.split(delim); // Take the first part
        Strings.slice memory tld = nameSlice; // Only the TLD is remaining after the previous line
        if (!tld.equals("eth".toSlice())) return (false, "");

        return (true, label.toString());
    }

    /**
     * @dev Let anyone close the claim if the supply is over 5M
     */
    function closeClaim() external onlyClaimOpen {
        // 5M tokens represents 5k registration years of "greg" .eth names
        // 1k claims if each name claims max amount
        if (totalSupply() < 5_000_000e18) revert Unauthorized();

        isClaimOpen = false;
        emit CloseClaim();
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Mints new tokens. Can only be executed once per year and cannot exceed 5% of the current supply.
     * @param to The address to mint the new tokens to.
     * @param amount The quantity of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        uint256 mintCap = 500; // 5%

        // Check that the mint amount is less than the mint cap
        if (amount > (totalSupply() * mintCap) / 10000) {
            revert Unauthorized();
        }

        // Check that the mint interval has passed
        if (block.timestamp < nextMint) {
            revert Unauthorized();
        }

        nextMint = block.timestamp + minimumMintInterval;
        _mint(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyClaimOpen() {
        if (!isClaimOpen) revert ClaimClosed();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           REQUIRED OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(
        address owner
    ) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
