// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./DapsIERC20.sol";

contract ERC20 is IERC20 {
    uint totalTokens;
    address owner;
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowances;
    string name;
    string symbol;

    constructor(string memory _name, string memory _symbol, uint _initialSupply) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        mint(_initialSupply, owner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not an owner");
        _;
    }

    modifier enoughTokens(address _from, uint _amount) {
        require(balanceOf(_from) >= _amount, "Not enought Tokens");
        _;
    }

    function getName() external view returns(string memory) {
        return name;
    }

    function getSymbol() external view returns(string memory) {
        return symbol;
    }

    function decimals() external pure returns(uint) {
        return 18;
    }

    function totalSupply() external view returns(uint) {
        return totalTokens;
    }

    function balanceOf(address _account) public view returns(uint) {
        return balances[_account];
    }

    function transfer(address _to, uint _amount) external enoughTokens(msg.sender, _amount) {
        beforeTokenTransfer(msg.sender, _to, _amount);
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
        afterTokenTransfer(msg.sender, _to, _amount);
        emit Transfer(msg.sender, _to, _amount);
    }

    function allowance(address _owner, address _spender) public view returns(uint) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint _amount) public {
        _approve(msg.sender, _spender, _amount);
    }

    function _approve(address _sender, address _spender, uint _amount) internal virtual {
        allowances[_sender][_spender] = _amount;
        emit Approve(_sender, _spender, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint _amount) public enoughTokens(_sender, _amount) {
        beforeTokenTransfer(_sender, _recipient, _amount);
        allowances[_sender][_recipient] -= _amount;
        balances[_sender] -= _amount;
        balances[_recipient] += _amount;
        afterTokenTransfer(_sender, _recipient, _amount);
        emit Transfer(_sender, _recipient, _amount);
    }

    function mint(uint _amount, address _shop) public onlyOwner {
        beforeTokenTransfer(address(0), _shop, _amount);
        balances[_shop] += _amount;
        totalTokens += _amount;
        afterTokenTransfer(address(0), _shop, _amount);
        emit Transfer(address(0), _shop, _amount);
    }

    function burn(address _from, uint _amount) public onlyOwner {
        beforeTokenTransfer(_from, address(0), _amount);
        balances[_from] -= _amount;
        totalTokens -= _amount;
        afterTokenTransfer(_from, address(0), _amount);
    }

    function beforeTokenTransfer(address _from, address _to, uint _amount) internal virtual {}

    function afterTokenTransfer(address _from, address _to, uint _amount) internal virtual {}
}