// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "./Token.sol";

contract AuctionEngine is IERC1155Receiver {

    address private _owner;

    DapsCollection private _tokenOrNFT;

    uint private _aucId;

    mapping(address => mapping(uint => Auction)) private auctionsFull;

    mapping(uint => Auction) private auctions;

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

    uint private DELAY = 15;
    uint private DURATION = 180;

    mapping(uint => mapping(address => uint)) private auctionBids;
    mapping(uint => address[]) private activeBidders;

    struct Auction {
        address _ownerAuc;
        uint _startPrice;
        uint _finalPrice;
        uint _timeStart;
        uint _duration;
        uint _endTime;
        uint _NFT;
        uint _tokenId;
        bool _stopped;
    }

    uint[] private activeAuctions;

    constructor (DapsCollection tokenOrNFT) {
        _owner = msg.sender;
        _tokenOrNFT = tokenOrNFT;
    }

    function getBalanceContract(uint idTokenOrNFT) public view returns(uint){
        return _tokenOrNFT.balanceOf(address(this), idTokenOrNFT);
    }

    function getYourBalance(uint idTokenOrNFT) public view returns(uint) {
        return _tokenOrNFT.balanceOf(msg.sender, idTokenOrNFT);
    }

    function createAuction(uint idNFT, uint startPrice, uint tokenId, uint duration) public returns(uint){
        
        _aucId++;
        uint correctDuration = duration == 0 ? DURATION : duration;

        _tokenOrNFT.safeTransferFrom(msg.sender, address(this), idNFT, 1, "0x");

        // Bids[] memory initialBids = new Bids[](0);

        Auction memory newAuc = Auction({
            _ownerAuc: msg.sender,
            _startPrice: startPrice,
            _finalPrice: 0,
            _timeStart: block.timestamp + DELAY,
            _duration: correctDuration,
            _endTime: block.timestamp + DELAY + correctDuration,
            _NFT: idNFT,
            _tokenId: tokenId,
            // _bids: initialBids, // Инициализируем пустой массив _bids
            _stopped: false
        });
        
        auctionsFull[msg.sender][_aucId] = newAuc;
        auctions[_aucId] = newAuc;
        activeAuctions.push(_aucId);

        // Для того, чтобы оставить 0 в качества индекса суппорта
        activeBidders[_aucId].push(address(0));
        // И заполняем 0 адрес 0 суммой
        auctionBids[_aucId][msg.sender] = 0;

        return _aucId;
    }

    function getStateAuc(uint aucId) public view returns(AucState) {
        if (auctions[aucId]._timeStart == 0) return AucState.Pending;
        if (block.timestamp >= auctions[aucId]._timeStart && auctions[aucId]._endTime > block.timestamp) return AucState.Active;
        // if (auctions[aucId]._timeStart >= auctions[aucId]._endTime) return AucState.Executed;
        if (block.timestamp >= auctions[aucId]._endTime) return AucState.Executed;
    }

    function offerPrice(uint aucId, uint amount) public {
        require(getStateAuc(aucId) == AucState.Active, "Daps: Auction is not active");
        require(amount > auctions[aucId]._finalPrice, "Daps: Amount should be higher than current highest bid");

        auctionBids[aucId][msg.sender] = amount;
        activeBidders[aucId].push(msg.sender);

        _tokenOrNFT.safeTransferFrom(msg.sender, address(this), auctions[aucId]._tokenId, amount, "0x");
    }

    function takeMoneyFromAuc(uint aucId, uint amount) public {

        // Проверка на виннера
        require(amount <= auctionBids[aucId][msg.sender], "Daps: you dont have money on cotract");
        _tokenOrNFT.safeTransferFrom(address(this), msg.sender, auctions[aucId]._tokenId, amount, "0x");

        // Чистим данные о вызывабщем msg.sender из таблиц 
        auctionBids[aucId][msg.sender] = 0;
        removeBidder(aucId, msg.sender);
    }


    // Возникла проблема, что нет индекса, которого нет
    function removeBidder(uint aucId, address deleteBidder) internal  {
        require(activeBidders[aucId].length > 0, "No bidders for this auction");
    
        // Найти индекс удаляемого элемента в массиве
        uint indexToRemove = 0;
        for (uint i = 0; i < activeBidders[aucId].length; i++) {
            if (activeBidders[aucId][i] == deleteBidder) {
                indexToRemove = i;
                break;
            }
        }   
    
        require(indexToRemove != 0, "Bidder not found");
    
        // Пересоздать массив без удаленного элемента
        // Просто сдвигаем все члены массива на место удаляемого
        for (uint i = indexToRemove; i < activeBidders[aucId].length - 1; i++) {
            activeBidders[aucId][i] = activeBidders[aucId][i + 1];
        }
        activeBidders[aucId].pop();
    }

    function endAuction(uint aucId) public {
        require(msg.sender == auctions[aucId]._ownerAuc, "Daps: you are not an owner!");
        require(getStateAuc(aucId) == AucState.Executed, "Daps: The auction is not over");
        Auction storage auction = auctions[aucId];
        auction._stopped = true;


        address winningBidder = address(0);
        address tempWinner = address(0);
        uint maxBid = 0;
        (maxBid, tempWinner) = getMaxBid(aucId);

        deletActiveAuc(aucId);

        if (maxBid > 0) {
            winningBidder = tempWinner;
        }

        if (winningBidder != address(0)) {
            _tokenOrNFT.safeTransferFrom(address(this), winningBidder, auction._NFT, 1, "0x");
        
            _tokenOrNFT.safeTransferFrom(address(this), auction._ownerAuc, auction._tokenId, maxBid, "0x");
            // Нужно еще обновить информацию в аукционе
            // И удалить данные получается
        } else {
       
            _tokenOrNFT.safeTransferFrom(address(this), auction._ownerAuc, auction._NFT, 1, "0x");
        }

    }

    function deletActiveAuc(uint aucId) internal {
        require(aucId <= activeAuctions.length, "Daps: Invalid auction ID");

        // Перемещаем последний элемент массива на место удаляемого элемента
        activeAuctions[aucId] = activeAuctions[activeAuctions.length - 1];
        
        // Уменьшаем размер массива на 1
        activeAuctions.pop();
    }

    function getMaxBid(uint aucId) public view returns(uint maxBid, address winningBidder) {
        
        maxBid = 0;
        winningBidder = address(0);
        mapping(address => uint) storage bids = auctionBids[aucId];

        for (uint i = 0; i < activeBidders[aucId].length; i++) {
            address bidder = activeBidders[aucId][i];
            uint bidAmount = bids[bidder];

            if (bidAmount > maxBid) {
            maxBid = bidAmount;
            winningBidder = bidder;
            }
        }
        return (maxBid, winningBidder);
    }

    function getTokenAuc(uint aucId) public view returns(uint) {
        return auctions[aucId]._tokenId;
    }

    function getTimeAuc(uint aucId) public view returns(uint) {
        uint time = block.timestamp - auctions[aucId]._timeStart;
        return time;
    }

    function getActiveAuctions() public view returns(uint[] memory) {
        return activeAuctions;
    }

    function getIdNFTinAuc(uint aucId) public view returns(uint) {
        return auctions[aucId]._NFT;
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