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

    uint256 constant amountPerClaim = 10_000e18; // 10,000 tokens
    ENS constant ens = ENS(0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e);
    INameWrapper immutable nameWrapper;
    bool isClaimOpen = true;

    mapping(bytes dnsEncodedName => bool claimed) public claimedNames;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address initialOwner,
        address nameWrapperAddress
    ) ERC20("Greg", "GREG") Ownable(initialOwner) ERC20Permit("Greg") {
        nameWrapper = INameWrapper(nameWrapperAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * Mint tokens to the sender if they own an ENS name that starts with "greg"
     *
     * @param name ENS name in full format, like "gregskril.eth"
     */
    function claim(string calldata name) public {
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
        _mint(msg.sender, amountPerClaim);
    }

    function closeClaim() public onlyOwner {
        isClaimOpen = false;
    }

    function isEligible(string calldata name) public pure returns (bool) {
        Strings.slice memory nameSlice = name.toSlice();
        Strings.slice memory substringSlice = "greg".toSlice();
        Strings.slice memory delim = ".".toSlice();
        uint256 parts = nameSlice.count(delim);

        // Check if the name is a 2LD
        if (parts != 1) return false;

        // Check if the TLD is .eth
        Strings.slice memory tld = nameSlice.copy().split(delim);
        if (!tld.equals("eth".toSlice())) return false;

        // Check if the name includes "greg"
        if (!nameSlice.contains(substringSlice)) return false;

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
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
