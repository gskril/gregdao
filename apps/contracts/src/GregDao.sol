// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract GregDao is TimelockController {
    // Allow any address to execute a proposal once the timelock has expired
    address[] internal executors = [address(0)];

    constructor(
        address[] memory proposers
    )
        TimelockController(
            172800, // initial minimum delay in seconds for operations (2 days)
            proposers, // accounts to be granted proposer and canceller roles (just the governor)
            executors, // accounts to be granted executor role (any address)
            address(0) // optional account to be granted admin role (disabled)
        )
    {}
}
