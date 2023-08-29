// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract DapsCollection is ERC1155, Ownable, Pausable, ERC1155Burnable, ERC1155Supply {

    mapping(uint => string[2]) nameAndSymb;

    mapping(uint => string) nameOfNFT;

    constructor() ERC1155("") {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // Не протестировано 
    function createToken(string memory name, string memory symb, uint idToken, uint amountOfTotalSupply) public onlyOwner {
        nameAndSymb[idToken][0] = name;
        nameAndSymb[idToken][1] = symb;
        _totalSupply[idToken] += amountOfTotalSupply;
    }

    function getTokenName(uint idToken) public view returns(string memory) {
        return nameAndSymb[idToken][0];
    }

    function getTokenSymb(uint idToken) public view returns(string memory) {
        return nameAndSymb[idToken][1];
    }

    function getNFTName(uint idNFT) public view returns(string memory) {
        return nameOfNFT[idNFT];
    }

    function createNFT(address account, string memory name, uint idNFT) public onlyOwner {
        // idNFT++;
        nameOfNFT[idNFT] = name;
        _mint(account, idNFT, 1, "0x");
    }

    // Поле data, будем выставлять сами
    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}