// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/// @title AuctionTypesV1
/// @author Adam Stallard
contract AuctionTypesV1 {

    struct Settings {
        address treasury;
        uint40 duration;
        uint40 timeBuffer;
        uint8 minBidIncrement;
        bool launched;
        uint256 reservePrice;
        address reserveAddress;
        address raffleAddress;
        string votesURI;
        string flashVotesURI;
    }

    struct Auction {
        uint256 tokenId;
        uint256 highestBid;
        address highestBidder;
        uint40 startTime;
        uint40 endTime;
        bool settled;
    }
}
