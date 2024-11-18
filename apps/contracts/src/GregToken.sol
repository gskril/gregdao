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

    event Claim(string indexed name, address indexed owner);

    /*//////////////////////////////////////////////////////////////
                               PARAMETERS
    //////////////////////////////////////////////////////////////*/

    bool public isClaimOpen = true;
    uint256 public constant minimumMintInterval = 365 days;
    ENS public constant ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);

    uint256 public nextMint; // Timestamp
    INameWrapper public immutable nameWrapper;

    mapping(bytes dnsEncodedName => bool claimed) public claimedNames;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address initialOwner,
        address nameWrapperAddress
    ) ERC20("Greg", "GREG") Ownable(initialOwner) ERC20Permit("Greg") {
        nameWrapper = INameWrapper(nameWrapperAddress);
        nextMint = block.timestamp + minimumMintInterval;
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Mint tokens to the sender if they own an ENS name that includes "greg".
     * @param name ENS name in full format, like "gregskril.eth"
     */
    function claim(string calldata name) external {
        if (!isClaimOpen) revert ClaimClosed();
        if (!isEligible(name)) revert IneligibleName();

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

        // Mint the tokens
        emit Claim(name, msg.sender);
        claimedNames[dnsEncodedName] = true;
        _mint(msg.sender, 10_000e18); // 10k tokens
    }

    function isEligible(string calldata name) public pure returns (bool) {
        Strings.slice memory nameSlice = name.toSlice();
        Strings.slice memory substringSlice = "greg".toSlice();
        Strings.slice memory delim = ".".toSlice();
        uint256 parts = nameSlice.count(delim);

        // Check if the name is a 2LD
        if (parts != 1) return false;

        // Check if the name includes "greg"
        if (!nameSlice.contains(substringSlice)) return false;

        // Check if the TLD is .eth
        nameSlice.split(delim); // Drop the first part, leaving just the TLD
        Strings.slice memory tld = nameSlice;
        if (!tld.equals("eth".toSlice())) return false;

        return true;
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

    function closeClaim() external onlyOwner {
        isClaimOpen = false;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
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
