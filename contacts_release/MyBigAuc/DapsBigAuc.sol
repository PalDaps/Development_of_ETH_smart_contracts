// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "./DapsCollection.sol";

contract AuctionEngine is IERC1155Receiver {

    event NFTTransferredToWinner(address contractFrom, address winningBidderTo, uint idNFT, uint amount);
    event TokensTransferredToOwnerAuc(address contractFrom, address ownerAucTo, uint idToken, uint amount);
    event NFTReturnedToOwnerAuc(address contractFrom, address ownerAucTo, uint idNFT, uint amount);


    DapsCollection private _dapsCollection;

    address private _owner;

    uint private _idAuction;

    // mapping(address => mapping(uint => Auction)) private _auctionsFull;

    mapping(uint => Auction) private _auctions;

    // Описываем какие состояния могут быть у Аукциона
    // Pending - Аукцион не начался
    // Active - Аукцион идет
    // Successeded - Аукцион завершился, найден покупатель
    // Defeated - Аукцион завершился без покупателя 

    enum AucState {Pending, Active, Successeded, Defeated, Executed}

    // Маппинг не проктил, так как по нему нельзя итерироваться 
    // mapping(uint => mapping(address => uint)) Bids;

    // struct Bids {
    //     uint _aucId;
    //     address _bidder;
    //     uint _amount;
    // }

    uint private DELAY = 5;
    uint private DURATION = 180;

    mapping(uint => mapping(address => uint)) private _auctionBids;
    mapping(uint => address[]) private _activeBidders;

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

    uint[] private _activeAuctions;

    constructor (DapsCollection dapsCollection) {
        _owner = msg.sender;
        _dapsCollection = dapsCollection;
    }

    function getBalanceContract(uint idTokenOrNFT) public view returns(uint){
        return _dapsCollection.balanceOf(address(this), idTokenOrNFT);
    }

    function getYourBalance(uint idTokenOrNFT) public view returns(uint) {
        return _dapsCollection.balanceOf(msg.sender, idTokenOrNFT);
    }

    function createAuction(uint idNFT_, uint startPrice_, uint idToken_, uint duration_) public returns(uint){
        
        _idAuction++;
        uint correctDuration = duration_ == 0 ? DURATION : duration_;

        _dapsCollection.safeTransferFrom(msg.sender, address(this), idNFT_, 1, "0x");

        // Bids[] memory initialBids = new Bids[](0);

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
        
        // _auctionsFull[msg.sender][_idAuction] = newAuc;
        _auctions[_idAuction] = newAuc;
        _activeAuctions.push(_idAuction);

            // Для того, чтобы оставить 0 в качества индекса суппорта
        _activeBidders[_idAuction].push(address(0));
        // И заполняем 0 адрес 0 суммой
        _auctionBids[_idAuction][msg.sender] = 0;

        return _idAuction;
    }

    function getStateAuc(uint idAuction) public view returns(AucState) {
        if (_auctions[idAuction].startTime == 0) return AucState.Pending;
        if (block.timestamp >= _auctions[idAuction].startTime && _auctions[idAuction].endTime > block.timestamp) return AucState.Active;
        if (block.timestamp >= _auctions[idAuction].endTime) return AucState.Executed;
    }

    function offerPrice(uint idAuction, uint amount) public {
        require(getStateAuc(idAuction) == AucState.Active, "Daps: Auction is not active");
        require(amount > _auctions[idAuction].finalPrice, "Daps: Amount should be higher than current highest bid");

        _auctionBids[idAuction][msg.sender] = amount;
        _activeBidders[idAuction].push(msg.sender);

        _dapsCollection.safeTransferFrom(msg.sender, address(this), _auctions[idAuction].idToken, amount, "0x");
    }

    function takeMoneyFromAuc(uint idAuction, uint amount) public {

        // Проверка на виннера
        require(amount <= _auctionBids[idAuction][msg.sender], "Daps: you dont have money on cotract");
        _dapsCollection.safeTransferFrom(address(this), msg.sender, _auctions[idAuction].idToken, amount, "0x");

        // Чистим данные о вызывабщем msg.sender из таблиц 
        _auctionBids[idAuction][msg.sender] = 0;
        removeBidder(idAuction, msg.sender);
    }


    // Возникла проблема, что нет индекса, которого нет
    function removeBidder(uint idAuction, address deleteBidder) internal  {
        require(_activeBidders[idAuction].length > 0, "No bidders for this auction");
    
        // Найти индекс удаляемого элемента в массиве
        uint indexToRemove = 0;
        for (uint i = 0; i < _activeBidders[idAuction].length; i++) {
            if (_activeBidders[idAuction][i] == deleteBidder) {
                indexToRemove = i;
                break;
            }
        }   
    
        require(indexToRemove != 0, "Bidder not found");
    
        // Пересоздать массив без удаленного элемента
        // Просто сдвигаем все члены массива на место удаляемого
        for (uint i = indexToRemove; i < _activeBidders[idAuction].length - 1; i++) {
            _activeBidders[idAuction][i] = _activeBidders[idAuction][i + 1];
        }
        _activeBidders[idAuction].pop();
    }

    function endAuction(uint idAuction) public {
        require(msg.sender == _auctions[idAuction].ownerAuc, "Daps: you are not an owner!");
        require(getStateAuc(idAuction) == AucState.Executed, "Daps: The auction is not over");
        Auction storage auction = _auctions[idAuction];
        auction.stopped = true;


        address winningBidder = address(0);
        address tempWinner = address(0);
        uint maxBid = 0;
        (maxBid, tempWinner) = getMaxBid(idAuction);

        deleteActiveAuc(idAuction);

        if (maxBid > 0) {
            winningBidder = tempWinner;
        }

        if (winningBidder != address(0)) {
            _dapsCollection.safeTransferFrom(address(this), winningBidder, auction.idNFT, 1, "0x");

            _dapsCollection.safeTransferFrom(address(this), auction.ownerAuc, auction.idToken, maxBid, "0x");

            emit NFTTransferredToWinner(address(this), winningBidder, auction.idNFT, 1);
            emit TokensTransferredToOwnerAuc(address(this), auction.ownerAuc, auction.idToken, maxBid);
            // Нужно еще обновить информацию в аукционе
            // И удалить данные получается
        } else {
       
            _dapsCollection.safeTransferFrom(address(this), auction.ownerAuc, auction.idNFT, 1, "0x");

            emit NFTReturnedToOwnerAuc(address(this), auction.ownerAuc, auction.idNFT, 1);
        }

    }
    
    function deleteActiveAuc(uint idAuction) internal {
        require(idAuction <= _activeAuctions.length, "Daps: Invalid auction ID");

        // Перемещаем последний элемент массива на место удаляемого элемента
        _activeAuctions[idAuction] = _activeAuctions[_activeAuctions.length - 1];
        
        // Уменьшаем размер массива на 1
        _activeAuctions.pop();
    }

    function getMaxBid(uint idAuction) public view returns(uint maxBid, address winningBidder) {
        
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

    function getTokenAuc(uint idAuction) public view returns(uint) {
        return _auctions[idAuction].idToken;
    }

    function getTimeAuc(uint idAuction) public view returns(uint) {
        uint time = block.timestamp - _auctions[idAuction].startTime;
        return time;
    }

    function getActiveAucs() public view returns(uint[] memory) {
        return _activeAuctions;
    }

    function getIdNFTinAuc(uint idAuction) public view returns(uint) {
        return _auctions[idAuction].idNFT;
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4) {
        
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4) {
        
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        
        return  interfaceId == type(IERC1155Receiver).interfaceId;
    }
}