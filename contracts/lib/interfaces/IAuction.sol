// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/// @title IAuction
/// @author Adam Stallard

interface IAuction {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a bid is placed
    /// @param tokenId The ERC-721 token id
    /// @param bidder The address of the bidder
    /// @param amount The amount of ETH
    /// @param extended If the bid extended the auction
    /// @param endTime The end time of the auction
    event AuctionBid(uint256 tokenId, address bidder, uint256 amount, bool extended, uint256 endTime);

    /// @notice Emitted when an auction is settled
    /// @param tokenId The ERC-721 token id of the settled auction
    /// @param winner The address of the winning bidder
    /// @param amount The amount of ETH raised from the winning bid
    event AuctionSettled(uint256 tokenId, address winner, uint256 amount);

    /// @notice Emitted when an auction is created
    /// @param tokenId The ERC-721 token id of the created auction
    /// @param startTime The start time of the created auction
    /// @param endTime The end time of the created auction
    event AuctionCreated(uint256 tokenId, uint256 startTime, uint256 endTime);

    /// @notice Emitted when the auction duration is updated
    /// @param duration The new auction duration
    event DurationUpdated(uint256 duration);

    /// @notice Emitted when the reserve price is updated
    /// @param reservePrice The new reserve price
    event ReservePriceUpdated(uint256 reservePrice);

    /// @notice Emitted when the reserve address is updated
    /// @param reserveAddress The new reserve address
    event ReserveAddressUpdated(address reserveAddress);

    /// @notice Emitted when the raffle address is updated
    /// @param raffleAddress The new raffle address
    event RaffleAddressUpdated(address raffleAddress);

    /// @notice Emitted when the treasury address is updated
    /// @param treasuryAddress The new treasury address
    event TreasuryAddressUpdated(address treasuryAddress);

    /// @notice Emitted when the min bid increment percentage is updated
    /// @param minBidIncrementPercentage The new min bid increment percentage
    event MinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    /// @notice Emitted when the time buffer is updated
    /// @param timeBuffer The new time buffer
    event TimeBufferUpdated(uint256 timeBuffer);

    ///                                                          ///
    ///                           ERRORS                         ///
    ///                                                          ///

    /// @dev Reverts if a bid is placed for the wrong token
    error INVALID_TOKEN_ID();

    /// @dev Reverts if a bid is placed for an auction that's over
    error AUCTION_OVER();

    /// @dev Reverts if a bid is placed or an attempt to settle is made for an auction that hasn't started
    error AUCTION_NOT_STARTED();

    /// @dev Reverts if attempting to start an auction early if its start date is already passed
    error AUCTION_START_NOT_IN_FUTURE();

    /// @dev Reverts if attempting to settle an active auction
    error AUCTION_ACTIVE();

    /// @dev Reverts if attempting to settle an auction that was already settled
    error AUCTION_SETTLED();

    /// @dev Reverts if a bid does not meet the reserve price
    error RESERVE_PRICE_NOT_MET();

    /// @dev Reverts if a bid does not meet the minimum bid
    error MINIMUM_BID_NOT_MET();

    /// @dev Error for when the bid increment is set to 0.
    error MIN_BID_INCREMENT_1_PERCENT();

    /// @dev Reverts if the contract does not have enough ETH
    error INSOLVENT();

    /// @dev Reverts if the caller was not the contract manager
    error ONLY_MANAGER();

    /// @dev Thrown if the WETH contract throws a failure on transfer
    error FAILING_WETH_TRANSFER();

    /// @dev Thrown if the auction creation failed
    error AUCTION_CREATE_FAILED_TO_LAUNCH();

}
