// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
//
//    ^-^           /  _|_
//   (✓,✓)     \   /.-. |  .-. .--.
//   (/  )      \ /(   )| '--’ `--.
// ---"-"--      '  `-´ `-'`--’`--’
////////////////////////////////////////

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Questions is AccessControl {

    enum QuestionState{ NOT_SUBMITTED, SUBMITTED, APPROVED, FLAGGED, USED }
    struct Question {
        uint modifiedTimestamp;
        QuestionState state;
    }

    // Public storage

    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");

    mapping(uint256 => Question) public questionsByTokenId;

    address public immutable votesAddress;
    uint256 public editFee;

    // Events

    event QuestionSubmitted(uint256 indexed tokenId, bytes question);
    event QuestionEdited(uint256 indexed tokenId, bytes question);
    event QuestionApproved(uint256 indexed tokenId);
    event QuestionUsed(uint256 indexed tokenId);
    event QuestionFlagged(uint256 indexed tokenId);

    // Errors

    error NOT_TOKEN_HOLDER();
    error QUESTION_ALREADY_SUBMITTED();
    error QUESTION_ALREADY_APPROVED();
    error QUESTION_ALREADY_USED();
    error QUESTION_NOT_SUBMITTED();
    error INSUFFICIENT_FEE_FOR_EDIT();
    error FEES_NOT_TRANSFERRED();
    error QUESTION_FLAGGED_AND_MUST_BE_EDITED();
    error WAIT_TIME_NOT_REACHED();

    /// @param _editFee The fee in wei to edit a question.
    constructor(address _votesAddress, uint256 _editFee){
        votesAddress = _votesAddress;
        editFee = _editFee;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REVIEWER_ROLE, msg.sender);
    }

    modifier onlyTokenHolder(uint256 tokenId){
        IERC721 votes = IERC721(votesAddress);
        if (msg.sender != votes.ownerOf(tokenId)) {
            revert NOT_TOKEN_HOLDER();
        }
        _;
    }

    /// @param tokenId The tokenId of the Votes token that the question is for.
    function submit(uint256 tokenId, bytes memory questionData) external onlyTokenHolder(tokenId) {
        Question storage question = questionsByTokenId[tokenId];
        QuestionState state  = question.state;
        if (state == QuestionState.NOT_SUBMITTED) {
            state = QuestionState.SUBMITTED;
            emit QuestionSubmitted(tokenId, questionData);
        } else {
            revert QUESTION_ALREADY_SUBMITTED();
        }
    }

    /// Requires editFee to be paid
    /// @param tokenId The tokenId of the Votes token attached to the question to edit.
    function edit(uint256 tokenId, bytes memory questionData) external payable onlyTokenHolder(tokenId) {
        Question storage question = questionsByTokenId[tokenId];
        QuestionState state  = question.state;
        if (msg.value < editFee) {
            revert INSUFFICIENT_FEE_FOR_EDIT();
        } else if (state == QuestionState.NOT_SUBMITTED) {
            revert QUESTION_NOT_SUBMITTED();
        } else if (state == QuestionState.USED) {
            revert QUESTION_ALREADY_USED();
        } else { // Ok to edit
            state = QuestionState.SUBMITTED;
            emit QuestionEdited(tokenId, questionData);
            question.modifiedTimestamp = block.timestamp;
        }
    }

    function setEditFee(uint256 fee) external onlyRole(REVIEWER_ROLE){
        editFee = fee;
    }

    function transferFees(address destination) external onlyRole(REVIEWER_ROLE) {
        (bool transferred,) = destination.call{value: address(this).balance}("");
        if (!transferred){
            revert FEES_NOT_TRANSFERRED();
        }
    }

    /// @param tokenId The tokenId of the Votes token attached to the question to flag.
    function flag(uint256 tokenId) external onlyRole(REVIEWER_ROLE) {
        Question storage question = questionsByTokenId[tokenId];
        QuestionState state  = question.state;
        if (state == QuestionState.NOT_SUBMITTED) {
            revert QUESTION_NOT_SUBMITTED();
        } else if (state == QuestionState.USED) {
            revert QUESTION_ALREADY_USED();
        }
        state = QuestionState.FLAGGED;
        emit QuestionFlagged(tokenId);
    }

    // TODO: implement queue management (heaps) to determine the next question to use and allow anyone to call "use".
    /// Use the question attached the the tokenID as the next daily question
    /// @param tokenId The tokenId of the Votes token attached to the question to use.
    function use(uint256 tokenId) external onlyRole(REVIEWER_ROLE) {
        Question storage question = questionsByTokenId[tokenId];
        QuestionState state  = question.state;
        if (state != QuestionState.APPROVED){
            approve(tokenId);
        }
        state = QuestionState.USED;
        emit QuestionUsed(tokenId);
    }

    /// If the question attached to the tokenId was submitted more than 1 day ago and hasn't been flagged, approve it.
    /// @param tokenId The tokenId of the Votes token attached to the question to approve.
    function approve(uint256 tokenId) public {
        Question storage question = questionsByTokenId[tokenId];
        QuestionState state  = question.state;
        if(block.timestamp > question.modifiedTimestamp + 1 days && state == QuestionState.SUBMITTED){
            state = QuestionState.APPROVED;
            emit QuestionApproved(tokenId);
        } else if (state == QuestionState.APPROVED) {
            revert QUESTION_ALREADY_APPROVED();
        } else if (state == QuestionState.FLAGGED) {
            revert QUESTION_FLAGGED_AND_MUST_BE_EDITED();
        } else if (state == QuestionState.NOT_SUBMITTED) {
            revert QUESTION_NOT_SUBMITTED();
        } else if (state == QuestionState.USED) {
            revert QUESTION_ALREADY_USED();
        } else if(block.timestamp <= question.modifiedTimestamp + 1 days){
            revert WAIT_TIME_NOT_REACHED();
        }
    }
}
