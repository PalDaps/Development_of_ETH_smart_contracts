// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./DapsERC20.sol";

contract SiriusToken is ERC20 {
    constructor() ERC20("SiriusToken", "SRT", 1000) {}
}