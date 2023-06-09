// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { AuctionStorageV1 } from "./storage/AuctionStorageV1.sol";
import { Votes } from "./Votes.sol";
import { IAuction } from "./lib/interfaces/IAuction.sol";
import { IWETH } from "./lib/interfaces/IWETH.sol";

/// @title Auction
/// @author Adam Stallard
/// @custom:repo https://github.com/Votes-Project/votes-contracts
/// Modified from:
/// - github.com/ourzora/nouns-protocol commit 7299b0c6d00d4c6da066f9160120be268880b10d - MIT license.
/// - NounsAuctionHouse.sol commit 2cbe6c7 - licensed under the BSD-3-Clause license.
/// - Zora V3 ReserveAuctionCoreEth module commit 795aeca - licensed under the GPL-3.0 license.
contract Auction is IAuction, AccessControl, ReentrancyGuard, Pausable, AuctionStorageV1 {

    bytes32 public constant UPDATE_METADATA_ROLE = keccak256("UPDATE_METADATA_ROLE");

    ///                                                          ///
    ///                          IMMUTABLES                      ///
    ///                                                          ///

    /// @notice Initial time buffer for auction bids
    uint40 private immutable INITIAL_TIME_BUFFER = 5 minutes;

    /// @notice Min bid increment BPS
    uint8 private immutable INITIAL_MIN_BID_INCREMENT_PERCENT = 10;

    /// @notice The address of WETH
    address private immutable WETH;

    ///                                                          ///
    ///                          CONSTRUCTOR                     ///
    ///                                                          ///

    /// @param _weth The address of WETH
    /// @param _votes Address of the Votes token contract
    /// @param _treasury The treasury address where ETH will be sent
    /// @param _duration The duration of each auction
    /// @param _reservePrice The reserve price of each auction
    constructor(
        address _weth,
        address _votes,
        address _treasury,
        uint256 _duration,
        uint256 _reservePrice,
        string memory _votesURI,
        string memory _flashVotesURI
    ) payable {
        WETH = _weth;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPDATE_METADATA_ROLE, msg.sender);

        // Pause the contract until the first auction
        _pause();

        // Store the Votes token
        votesToken = Votes(_votes);

        // Store the auction house settings
        settings.duration = SafeCast.toUint40(_duration);
        settings.reservePrice = _reservePrice;
        settings.timeBuffer = INITIAL_TIME_BUFFER;
        settings.minBidIncrement = INITIAL_MIN_BID_INCREMENT_PERCENT;
        settings.votesURI = _votesURI;
        settings.flashVotesURI = _flashVotesURI;

        // Set the reserve, raffle, and treasury addresses to the treasury address for now.
        settings.treasury = _treasury;
        settings.reserveAddress = _treasury;
        settings.raffleAddress = _treasury;
    }

    ///                                                          ///
    ///                          CREATE BID                      ///
    ///                                                          ///

    /// @notice Creates a bid for the current token
    /// @param _tokenId The ERC-721 token id
    function createBid(uint256 _tokenId) external payable nonReentrant {
        // Ensure the bid is for the current token
        if (auction.tokenId != _tokenId) {
            revert INVALID_TOKEN_ID();
        }

        if (block.timestamp < auction.startTime){
            revert AUCTION_NOT_STARTED();
        }

        // Ensure the auction is still active
        if (block.timestamp >= auction.endTime) {
            revert AUCTION_OVER();
        }

        // Cache the amount of ETH attached
        uint256 msgValue = msg.value;

        // Cache the address of the highest bidder
        address lastHighestBidder = auction.highestBidder;

        // Cache the last highest bid
        uint256 lastHighestBid = auction.highestBid;

        // Store the new highest bid
        auction.highestBid = msgValue;

        // Store the new highest bidder
        auction.highestBidder = msg.sender;

        // Used to store whether to extend the auction
        bool extend;

        // Cannot underflow as `_auction.endTime` is ensured to be greater than the current time above
    unchecked {
        // Compute whether the time remaining is less than the buffer
        extend = (auction.endTime - block.timestamp) < settings.timeBuffer;

        // If the auction should be extended
        if (extend) {
            // Update the end time with the additional time buffer
            auction.endTime = uint40(block.timestamp + settings.timeBuffer);
        }
    }

        // If this is the first bid:
        if (lastHighestBidder == address(0)) {
            // Ensure the bid meets the reserve price
            if (msgValue < settings.reservePrice) {
                revert RESERVE_PRICE_NOT_MET();
            }

            // Else this is a subsequent bid:
        } else {
            // Used to store the minimum bid required
            uint256 minBid;

            // Cannot realistically overflow
        unchecked {
            // Compute the minimum bid
            minBid = lastHighestBid + ((lastHighestBid * settings.minBidIncrement) / 100);
        }

            // Ensure the incoming bid meets the minimum
            if (msgValue < minBid) {
                revert MINIMUM_BID_NOT_MET();
            }
            // Ensure that the second bid is not also zero
            if (minBid == 0 && msgValue == 0 && lastHighestBidder != address(0)) {
                revert MINIMUM_BID_NOT_MET();
            }

            // Refund the previous bidder
            _handleOutgoingTransfer(lastHighestBidder, lastHighestBid);
        }

        emit AuctionBid(_tokenId, msg.sender, msgValue, extend, auction.endTime);
    }

    ///                                                          ///
    ///                    SETTLE & CREATE AUCTION               ///
    ///                                                          ///

    /// @notice Settles the current auction and creates the next one
    function settleCurrentAndCreateNewAuction() external nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    /// @dev Settles the current auction
    function _settleAuction() private {
        // Get a copy of the current auction
        Auction memory _auction = auction;

        // Ensure the auction wasn't already settled
        if (auction.settled) revert AUCTION_SETTLED();

        // Ensure the auction had started
        if (_auction.startTime == 0 || _auction.startTime > block.timestamp) revert AUCTION_NOT_STARTED();

        // Ensure the auction is over
        if (block.timestamp < _auction.endTime) revert AUCTION_ACTIVE();

        // Mark the auction as settled
        auction.settled = true;

        // If a bid was placed:
        if (_auction.highestBidder != address(0)) {
            // Cache the amount of the highest bid
            uint256 highestBid = _auction.highestBid;

            // If the highest bid included ETH: Transfer it to the treasury
            if (highestBid != 0) _handleOutgoingTransfer(settings.treasury, highestBid);

            // Transfer the token to the highest bidder
            votesToken.transferFrom(address(this), _auction.highestBidder, _auction.tokenId);

            // Else no bid was placed:
        } else {
            // Transfer the token to the reserve address
            votesToken.transferFrom(address(this), settings.reserveAddress, _auction.tokenId);
        }

        emit AuctionSettled(_auction.tokenId, _auction.highestBidder, _auction.highestBid);
    }

    /// @dev Creates an auction for the next token
    function _createAuction() private returns (bool) {
        uint256 nextTokenId = votesToken.totalSupply();

        uint lastDigit = nextTokenId % 10;

        // Every token with a tokenId ending in `9` is raffled
        bool isRaffle = lastDigit == 9;

        // Cache the current timestamp
        uint256 startTime = block.timestamp;

        if (isRaffle) {
            try votesToken.mint(settings.raffleAddress, settings.votesURI) {
                // set nextTokenId for next auction
                nextTokenId = votesToken.totalSupply();
                // Since there is no auction during a raffle, make the next auction start one duration later
                startTime += settings.duration;
            } catch {
                // Pause the contract if token minting failed
                _pause();
                return false;
            }
        }

        // Used to store the auction end time
        uint256 endTime;

        // Tokens with a tokenId ending in `0` or `5` are "Flash Votes tokens"
        bool isFlash = (lastDigit == 0 || lastDigit == 5);
        string memory uri = isFlash ? settings.flashVotesURI : settings.votesURI;

        // Get the next token available for bidding
        try votesToken.mint(uri) {
            // Store the token id
            auction.tokenId = nextTokenId;

            // Cannot realistically overflow
        unchecked {
            // Compute the auction end time
            endTime = startTime + settings.duration;
        }
            // Store the auction start and end time
            auction.startTime = uint40(startTime);
            auction.endTime = uint40(endTime);

            // Reset data from the previous auction
            auction.highestBid = 0;
            auction.highestBidder = address(0);
            auction.settled = false;

            emit AuctionCreated(nextTokenId, startTime, endTime);
            return true;
        } catch {
            // Pause the contract if token minting failed
            _pause();
            return false;
        }
    }

    /// @notice Start an auction set in the future now.
    function startAuctionEarly() public onlyRole(DEFAULT_ADMIN_ROLE) {
        // Cache the current timestamp
        uint256 newStartTime = block.timestamp;

        if (auction.startTime < newStartTime) {
            revert AUCTION_START_NOT_IN_FUTURE();
        }

        // Used to store the auction end time
        uint256 endTime;

        unchecked {
        // Compute the auction end time
            endTime = newStartTime + settings.duration;
        }

        auction.startTime = uint40(newStartTime);
        auction.endTime = uint40(endTime);
    }

    ///                                                          ///
    ///                             PAUSE                        ///
    ///                                                          ///

    /// @notice Unpauses the auction house
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();

        // If this is the first auction:
        if (!settings.launched) {
            // Mark the auction house as launched
            settings.launched = true;

            // Start the first auction
            if (!_createAuction()) {
                // In cause of failure, revert.
                revert AUCTION_CREATE_FAILED_TO_LAUNCH();
            }
        }
        // Else if the contract was paused and the previous auction was settled:
        else if (auction.settled) {
            // Start the next auction
            _createAuction();
        }
    }

    /// @notice Pauses the auction house
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice Settles the latest auction when the contract is paused
    function settleAuction() external nonReentrant whenPaused {
        _settleAuction();
    }

    ///                                                          ///
    ///                       AUCTION SETTINGS                   ///
    ///                                                          ///

    // The settings object is public, so these can also be retrieved by its getter

    /// @notice The DAO treasury
    function treasury() external view returns (address) {
        return settings.treasury;
    }

    /// @notice The time duration of each auction
    function duration() external view returns (uint256) {
        return settings.duration;
    }

    /// @notice The reserve price of each auction
    function reservePrice() external view returns (uint256) {
        return settings.reservePrice;
    }

    /// @notice The minimum amount of time to place a bid during an active auction
    function timeBuffer() external view returns (uint256) {
        return settings.timeBuffer;
    }

    /// @notice The minimum percentage an incoming bid must raise the highest bid
    function minBidIncrement() external view returns (uint256) {
        return settings.minBidIncrement;
    }

    ///                                                          ///
    ///                       UPDATE SETTINGS                    ///
    ///                                                          ///

    /// @notice Updates the time duration of each auction
    /// @param _duration The new time duration
    function setDuration(uint256 _duration) public onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        settings.duration = SafeCast.toUint40(_duration);

        emit DurationUpdated(_duration);
    }

    /// @notice Updates the reserve price of each auction
    /// @param _reservePrice The new reserve price
    function setReservePrice(uint256 _reservePrice) public onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        settings.reservePrice = _reservePrice;

        emit ReservePriceUpdated(_reservePrice);
    }

    /// @notice Sets the address where the auctioned token is sent if the reserve isn't met
    /// @param reserveAddress The new reserve address
    function setReserveAddress(address reserveAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        settings.reserveAddress = reserveAddress;

        emit ReserveAddressUpdated(reserveAddress);
    }

    /// @notice Sets the address where every tenth token is sent to be raffled
    /// @param raffleAddress The new raffle address
    function setRaffleAddress(address raffleAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        settings.raffleAddress = raffleAddress;

        emit RaffleAddressUpdated(raffleAddress);
    }

    /// @notice Sets the address where auction income is sent
    /// @param _treasury The new treasury address
    function setTreasuryAddress(address _treasury) public onlyRole(DEFAULT_ADMIN_ROLE) {
        settings.treasury = _treasury;

        emit TreasuryAddressUpdated(_treasury);
    }

    /// @notice Updates the time buffer of each auction
    /// @param _timeBuffer The new time buffer
    function setTimeBuffer(uint256 _timeBuffer) public onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        settings.timeBuffer = SafeCast.toUint40(_timeBuffer);

        emit TimeBufferUpdated(_timeBuffer);
    }

    /// @notice Updates the minimum bid increment of each subsequent bid
    /// @param _percentage The new percentage
    function setMinimumBidIncrement(uint256 _percentage) public onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        if (_percentage == 0) {
            revert MIN_BID_INCREMENT_1_PERCENT();
        }

        settings.minBidIncrement = SafeCast.toUint8(_percentage);

        emit MinBidIncrementPercentageUpdated(_percentage);
    }

    /// @notice Sets the metadata URI for all newly minted Votes tokens
    /// @param uri The new URI
    function setVotesURI(string memory uri) public onlyRole(UPDATE_METADATA_ROLE) {
        settings.votesURI = uri;
    }

    /// @notice Sets the metadata URI for all newly minted Flash Votes tokens
    /// @param uri The new URI
    function setFlashVotesURI(string memory uri) public onlyRole(UPDATE_METADATA_ROLE) {
        settings.flashVotesURI = uri;
    }

    ///                                                          ///
    ///                        TRANSFER UTIL                     ///
    ///                                                          ///

    /// @notice Transfer ETH/WETH from the contract
    /// @param _to The recipient address
    /// @param _amount The amount transferring
    function _handleOutgoingTransfer(address _to, uint256 _amount) private {
        // Ensure the contract has enough ETH to transfer
        if (address(this).balance < _amount) revert INSOLVENT();

        // Used to store if the transfer succeeded
        bool success;

        assembly {
        // Transfer ETH to the recipient
        // Limit the call to 50,000 gas
            success := call(50000, _to, _amount, 0, 0, 0, 0)
        }

        // If the transfer failed:
        if (!success) {
            // Wrap as WETH
            IWETH(WETH).deposit{ value: _amount }();

            // Transfer WETH instead
            bool wethSuccess = IWETH(WETH).transfer(_to, _amount);

            // Ensure successful transfer
            if (!wethSuccess) {
                revert FAILING_WETH_TRANSFER();
            }
        }
    }
}