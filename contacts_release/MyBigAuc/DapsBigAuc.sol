// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "./DapsCollection.sol";

// Преложения по улучшению
// 1. Нужно проверить, что createrOfAuction не может ставить на свой аукцион
// 2. Вызов функции setWinnerAuc можно логически оптимизировать
// 3. Нужно проверить момент, когда никто не выйграл.

contract AuctionEngine is IERC1155Receiver {

    event NFTTransferredToWinner(address contractFrom, address winningBidderTo, uint idNFT, uint amount, uint idAuction);
    event TokensTransferredToOwnerAuc(address contractFrom, address ownerAucTo, uint idToken, uint amount, uint idAuction);
    event StartedAuction(address creater, uint idNFT, uint startPrice, uint idToken, uint idAuction);
    event EndedAuction(address winner, uint idNFT, uint finalPrice, uint idToken, uint idAuction);

    DapsCollection private dapsCollection;

    address private _owner;

    uint private _idAuction;
    mapping(uint => Auction) private _auctions;
    uint[] private _activeAuctions;

    struct Auction {
        address ownerAuc;
        address winner;
        uint startPrice;
        uint finalPrice;
        uint startTime;
        uint duration;
        uint endTime;
        uint idNFT;
        uint idToken;
        bool stopped;
    }


    enum AucState {Pending, Active, Executed, Completed}

    uint private DELAY = 5;
    uint private DURATION = 180;

    mapping(uint => mapping(address => uint)) private _auctionBids;
    mapping(uint => address[]) private _activeBidders;

    constructor (DapsCollection dapsCollection_) {
        _owner = msg.sender;
        dapsCollection = dapsCollection_;
    }

    function getBalanceContract(uint idTokenOrNFT) public view returns(uint){
        return dapsCollection.balanceOf(address(this), idTokenOrNFT);
    }

    function getYourBalance(uint idTokenOrNFT) public view returns(uint) {
        return dapsCollection.balanceOf(msg.sender, idTokenOrNFT);
    }

    function createAuction(uint idNFT_, uint startPrice_, uint idToken_, uint duration_) public returns(uint){
        require(dapsCollection.balanceOf(msg.sender, idNFT_) != 0, "Daps: you don't have a NFT");
        require(duration_ <= 2 days, "Daps: to much duration for auction");
        require(dapsCollection.exists(idToken_), "Daps: this token is not exist");

        uint correctDuration = duration_ == 0 ? DURATION : duration_;

        _idAuction++;
        dapsCollection.safeTransferFrom(msg.sender, address(this), idNFT_, 1, "0x");

        Auction memory newAuc = Auction({
            ownerAuc: msg.sender,
            winner: address(0),
            startPrice: startPrice_,
            finalPrice: 0,
            startTime: block.timestamp + DELAY,
            duration: correctDuration,
            endTime: block.timestamp + DELAY + correctDuration,
            idNFT: idNFT_,
            idToken: idToken_,
            stopped: false
        });
        
        _auctions[_idAuction] = newAuc;
        _activeAuctions.push(_idAuction);

        _activeBidders[_idAuction].push(address(0));
        _auctionBids[_idAuction][msg.sender] = 0;

        emit StartedAuction(msg.sender, idNFT_, startPrice_, idToken_, _idAuction);
        return _idAuction;
    }
    
    function getStateAuc(uint idAuction) public view returns(AucState state) {
        if (_auctions[idAuction].startTime == 0) return AucState.Pending;
        if (block.timestamp >= _auctions[idAuction].startTime && _auctions[idAuction].endTime > block.timestamp) return AucState.Active;
        if (block.timestamp >= _auctions[idAuction].endTime) return AucState.Executed;
    }

    function isCorrectPrice(uint idAuction, uint amount) internal view returns(bool) {
        
        mapping(address => uint) storage bids = _auctionBids[idAuction];

        for (uint i = 0; i < _activeBidders[idAuction].length; i++) {
            address bidder = _activeBidders[idAuction][i];
            uint bidAmount = bids[bidder];

            if (bidAmount == amount) {
                return false;
            }
        }
        return true;
    }
    function offerPrice(uint idAuction, uint amount) public {
        require(getStateAuc(idAuction) == AucState.Active, "Daps: Auction is not active");
        require(amount >= _auctions[idAuction].startPrice, "Daps: Amount should be higher than start bid");
        require(isCorrectPrice(idAuction, amount), "Daps: The exact same amount has already been offered, raise the bid");
        require(_auctionBids[idAuction][msg.sender] == 0, "Daps: You have already bet, first take the previous bet");
        
        _auctionBids[idAuction][msg.sender] = amount;
        _activeBidders[idAuction].push(msg.sender);

        dapsCollection.safeTransferFrom(msg.sender, address(this), _auctions[idAuction].idToken, amount, "0x");
    }

    function takeMoneyFromAuc(uint idAuction, uint amount) public {
        
        require(amount == _auctionBids[idAuction][msg.sender], "Daps: you dont have money on cotract");
        dapsCollection.safeTransferFrom(address(this), msg.sender, _auctions[idAuction].idToken, amount, "0x");

        // Чистим данные о msg.sender из таблиц 
        _auctionBids[idAuction][msg.sender] -= amount;
        removeBidder(idAuction, msg.sender);
    }


    function removeBidder(uint idAuction, address deleteBidder) internal  {
        require(_activeBidders[idAuction].length > 0, "No bidders for this auction");
    
        uint indexToRemove = 0;
        for (uint i = 0; i < _activeBidders[idAuction].length; i++) {
            if (_activeBidders[idAuction][i] == deleteBidder) {
                indexToRemove = i;
                break;
            }
        }   
    
        require(indexToRemove != 0, "Bidder not found");
    
        for (uint i = indexToRemove; i < _activeBidders[idAuction].length - 1; i++) {
            _activeBidders[idAuction][i] = _activeBidders[idAuction][i + 1];
        }
        _activeBidders[idAuction].pop();
    }

    function autoEndAuction(uint idAuction) internal returns(uint maxBid, address winningBidder){
        require(getStateAuc(idAuction) == AucState.Executed, "Daps: The auction is not over");
        Auction storage auction = _auctions[idAuction];
        auction.stopped = true;


        winningBidder = address(0);
        address tempWinner = address(0);
        maxBid = 0;
        (maxBid, tempWinner) = getMaxBid(idAuction);

        if (maxBid > 0) {
            winningBidder = tempWinner;
        }

        if (winningBidder != address(0)) {
            return (maxBid, winningBidder);
        }
        emit EndedAuction(winningBidder, auction.idNFT, maxBid, auction.idToken, idAuction);
        return (maxBid, winningBidder);
    }
    
    function deleteActiveAuc(uint idAuction) internal {
        require(_activeAuctions.length > 0, "Daps: there are no an active auctions");
        uint indexOfDeletingAuc = 0;
        if (_activeAuctions.length > 1) {

            for (uint i = 0; i < _activeAuctions.length; i++) {
                if (_activeAuctions[i] == idAuction) {
                    indexOfDeletingAuc = i;
                    break;
                }
            }
            _activeAuctions[indexOfDeletingAuc] = _activeAuctions[_activeAuctions.length - 1];
        
            _activeAuctions.pop();
        } else {
            _activeAuctions.pop();
        }
    }

    function getMaxBid(uint idAuction) public view returns(uint maxBid, address winningBidder) {
        
        require(_activeBidders[idAuction].length > 0, "Daps: not an active bidders");
        maxBid = 0;
        winningBidder = address(0);
        mapping(address => uint) storage bids = _auctionBids[idAuction];

        for (uint i = 0; i < _activeBidders[idAuction].length; i++) {
            address bidder = _activeBidders[idAuction][i];
            uint bidAmount = bids[bidder];

            if (bidAmount > maxBid) {
            maxBid = bidAmount;
            winningBidder = bidder;
            }
        }
        return (maxBid, winningBidder);
    }

    function setWinnerInAuction(uint idAuction) public {
        require(!_auctions[idAuction].stopped, "Daps: this auction is ower!!!");
        require(block.timestamp >= _auctions[idAuction].endTime, "Daps: this auction is still going on");
        deleteActiveAuc(idAuction);
        autoEndAuction(idAuction);
    }

    function getAllActiveBidders(uint idAuction) public view returns(address[] memory) {
        return _activeBidders[idAuction];
    }

    function getFullInfoAuc(uint idAuction) public view returns(Auction memory) {
        return _auctions[idAuction];
    }

    function getNFTtoWinner(uint idAuction) public {
        address winner = address(0);
        (, winner) = autoEndAuction(idAuction);
        require(winner != address(0), "The winner is not determined");
        require(_auctions[idAuction].stopped, "Daps: auction is not over");
        require(msg.sender == winner, "Daps: You're not a winner");
        require(msg.sender != _auctions[idAuction].winner, "Daps: The winner has already taken NFT");

        _auctions[idAuction].winner = msg.sender;
        dapsCollection.safeTransferFrom(address(this), msg.sender, _auctions[idAuction].idNFT, 1, "0x");
        emit NFTTransferredToWinner(address(this), _auctions[idAuction].winner, _auctions[idAuction].idNFT, 1, idAuction);
        
    }

    function getTokenToOwnerAuc(uint idAuction) public {
        uint maxBid = 0;
        (maxBid ,) = autoEndAuction(idAuction);
        
        require(maxBid != 0, "The max bid is not determined");
        require(_auctions[idAuction].stopped, "Daps: auction is not over");
        require(msg.sender == _auctions[idAuction].ownerAuc, "Daps: you are not an owner of this Auction");
        require(maxBid != _auctions[idAuction].finalPrice, "The creator of the auction has already taken the tokens for sale");

        _auctions[idAuction].finalPrice = maxBid;
        dapsCollection.safeTransferFrom(address(this), _auctions[idAuction].ownerAuc, _auctions[idAuction].idToken, _auctions[idAuction].finalPrice, "0x");
        emit TokensTransferredToOwnerAuc(address(this), _auctions[idAuction].ownerAuc, _auctions[idAuction].idToken, _auctions[idAuction].finalPrice, idAuction);
    }

    function getTokenAuc(uint idAuction) public view returns(uint) {
        return _auctions[idAuction].idToken;
    }

    function getETHbalanceContract() public view returns(uint) {
        return address(this).balance;
    }

    function getTimeAuc(uint idAuction) public view returns(uint) {
        uint time = _auctions[idAuction].endTime - block.timestamp;
        return time;
    }

    function getActiveAucs() public view returns(uint[] memory) {
        return _activeAuctions;
    }

    function getIdNFTinAuc(uint idAuction) public view returns(uint) {
        return _auctions[idAuction].idNFT;
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external pure returns (bytes4) {
        
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external pure returns (bytes4) {
        
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        
        return  interfaceId == type(IERC1155Receiver).interfaceId;
    }
}