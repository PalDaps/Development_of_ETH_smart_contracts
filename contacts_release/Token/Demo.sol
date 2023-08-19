// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Этим контрактом мы будем управлять, то есть для него будем делать Dao
// Что все дейсвтия и транзакции выполнялись не напрямую, а через это контракт получается

// Также будем использовать для голосования токен SiriusToken
// Чтобы все кто обладает этим токеном могли учавствовать в голосовании

contract Demo {
    string public message;

    mapping(address => uint) public balances;

    address public owner;

    constructor() {
        owner = msg.sender;
    }   

    // Функция для назначения нового владельца
    function transferOwnership(address _to) external {
        require(msg.sender == owner);
        owner = _to;
    }

    function pay(string calldata _message) external payable {
        message = _message;
        balances[msg.sender] = msg.value;
    }
}