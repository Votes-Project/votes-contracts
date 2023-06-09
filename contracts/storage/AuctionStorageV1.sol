// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Votes } from "../Votes.sol";
import { AuctionTypesV1 } from "../types/AuctionTypesV1.sol";

/// @title AuctionStorageV1
/// @author Adam Stallard

contract AuctionStorageV1 is AuctionTypesV1 {
    /// @notice The auction settings
    Settings public settings;

    /// @notice The ERC-721 token
    Votes public votesToken;

    /// @notice The state of the current auction
    Auction public auction;
}
