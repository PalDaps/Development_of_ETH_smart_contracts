// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AuctionEngine {

    // ������ ��������, ������� ������������� �������
    address public owner;

    // ��������� ��������, ������� ������� � ���, ������� ����� ������ �������
    uint constant DURATION = 2 days;

    // ������� ����� ���� � ������� �������� ��������
    uint constant FEE = 10;

    struct Auction {
        
        // �������, ������� ������� ���-��
        address payable seller;

        // ����������� ����
        uint startingPrice;

        // ��������� ���� �� ������� ���������� ����� ����
        uint finalPrice;

        // ����� �������� �������
        uint startAt;

        // ����� ����������� �������
        uint endsAt;

        // ������� ����� ���������� �� ������� �� ����
        uint discountRate;

        // ��, ��� �� ������� 
        string item;

        // ���������� � ��� ���������� �� ������� ��� ���
        bool stopped;
    }

    // ������������ ������ ��������� ��� �������� ������
    Auction[] public auctions;

    event AuctionCreated(uint index, string itemName, uint startingPrice, uint duration);

    event AuctionEnded(uint index, uint finalPrice, address winner);

    constructor() {
        owner = msg.sender;
    }

    // ������� ��� �������� ���������
    function createAuction(uint _startingPrice, uint _discountRate, string calldata _item, uint _duration) external {

        // ��������� �������� _duration
        uint duration = _duration == 0 ? DURATION : _duration;

        // ��������, ��� _startingPrice ����� ���������� ��������. �� ���� �� ������ �� ��� � ����� ��� ������������
        // _discountRate � _duration
        require(_startingPrice >= _discountRate * duration, "Daps: Incorrect starting price");

        Auction memory newAuction = Auction({
            seller: payable(msg.sender),
            startingPrice: _startingPrice,
            finalPrice: _startingPrice,
            discountRate: _discountRate,
            
            // �������� ����� �� �������� �������
            startAt: block.timestamp,
            endsAt: block.timestamp + duration,
            item: _item,
            stopped: false
        });

        auctions.push(newAuction);

        emit AuctionCreated(auctions.length - 1, _item, _startingPrice, duration);
    }

    // �������, ������� ��������� ����� ���� �� ������� ������ �������
    function getPriceFor(uint index) public view returns(uint) {
        
        // ���������� ������, ������ ��� ����� ������ ������� ������, � ������ ��� ������ �� �����
        Auction memory cAuction = auctions[index];

        // ������� �� ������ ���� ����������
        require(!cAuction.stopped, "Daps: This Auc was stopped!");

        // ������� ������ ������� � ������ ��������
        uint elapsed = block.timestamp - cAuction.startAt;

        // ������� ��� ����� ������� ������������ ����������� �������
        // ��� ������ ������ �������, ��� ������ ����� ������
        uint discount = cAuction.discountRate * elapsed;

        return cAuction.startingPrice - discount;
    }

    // �������, ������� �������� ��� ���-���� ������
    function buy(uint index) external payable {
        
        Auction memory cAuction = auctions[index];

        require(!cAuction.stopped, "Daps: This Auc was stopped!");

        // ��� ����� ����� ��� �� �������
        require(block.timestamp < cAuction.endsAt, "Daps: This Auc was ended!!!");

        // ����� ������ ���� �� �����, ������� ����� ������ ���� �������
        uint cPrice = getPriceFor(index);

        // ��������� �������� �� ��� ���������� ����� ��� ���
        require(msg.value >= cPrice, "Daps: not enough money");

        // ���� ��� � ������� ������ �� ����� ���������� � ������������� �������
        cAuction.stopped = true;

        // ������������� ��������� ��������� ���� ����� ��������
        cAuction.finalPrice = cPrice;

        // � ����� ���� ��� ����������, �� ���� ������ �� ��������� ������� ��� �����-�� ��������
        // ������� �� ������ ����� ����������
        uint refund = msg.value - cPrice;

        // ���� ������ ������ ����, �� ���������� ��� ����� msg.sender
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        // ������ ��������������� �������� ����� ��������� ����, ������ ����� ��������� msg.sender
        // �� �� �����������, ��� FEE ��������� ������ �� ������ ��������� ��������
        cAuction.seller.transfer(cPrice - ((cPrice * FEE)/100));

        emit AuctionEnded(index, cPrice, msg.sender);
    }
}