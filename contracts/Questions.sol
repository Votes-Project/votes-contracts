// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
//
//    ^---^           /  _|_
//   (✓),(✓)     \   /.-. |  .-. .--.
//   (/    )      \ /(   )| '--’ `--.
//  --"---"--      '  `-´ `-'`--’`--’
////////////////////////////////////////

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Questions is AccessControl {

    // Public storage

    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");

    mapping(uint256 => bool) public tokenIDHasQuestion;
    mapping(uint256 => bool) public locked;

    address public immutable votesAddress;

    // Events

    event Submitted(uint256 indexed tokenId, bytes question);
    event Edited(uint256 indexed tokenId, bytes question);
    event Locked(uint256 indexed tokenId);
    event Unlocked(uint256 indexed tokenId);

    // Errors

    error NOT_TOKEN_HOLDER();
    error QUESTION_ALREADY_SUBMITTED();
    error QUESTION_DOES_NOT_EXIST();
    error QUESTION_LOCKED_BY_REVIEWER();

    constructor(address _votesAddress){
        votesAddress = _votesAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REVIEWER_ROLE, msg.sender);
    }

    modifier onlyTokenHolder(uint256 tokenId){
        IERC721 votes = IERC721(votesAddress);
        if (msg.sender != votes.ownerOf(tokenId)){
            revert NOT_TOKEN_HOLDER();
        }
        _;
    }

    function submit(uint256 tokenId, bytes memory question) external onlyTokenHolder(tokenId) {
        if (tokenIDHasQuestion[tokenId]) {
            revert QUESTION_ALREADY_SUBMITTED();
        }
        tokenIDHasQuestion[tokenId] = true;
        emit Submitted(tokenId, question);
    }

    function edit(uint256 tokenId, bytes memory question) external onlyTokenHolder(tokenId) {
        if (!tokenIDHasQuestion[tokenId]) {
            revert QUESTION_DOES_NOT_EXIST();
        }
        if (locked[tokenId]){
            revert QUESTION_LOCKED_BY_REVIEWER();
        }
        emit Edited(tokenId, question);
    }

    function lock(uint256 tokenId) external onlyRole(REVIEWER_ROLE){
        locked[tokenId] = true;
        emit Locked(tokenId);
    }

    function unlock(uint256 tokenId) external onlyRole(REVIEWER_ROLE){
        locked[tokenId] = false;
        emit Unlocked(tokenId);
    }
}
