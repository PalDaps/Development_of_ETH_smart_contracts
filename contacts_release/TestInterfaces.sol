// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

abstract contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// Хотим проверить реализует ли такой интерфейс смарт-контракт MyContract

interface MyDesiredInterface {
    function someFunction() external;
}

contract MyContract is MyDesiredInterface, IERC165 {
    function someFunction() external override {}

    function supportsInterface(bytes4 interfaceId) external view override returns (bool) {
        return interfaceId == type(MyDesiredInterface).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}

// Контракт, который будет проверять реализует ли MyContract интерфейс MyDesiredInterface
contract InterfaceChecker {
    IERC165 public instanceToCheck;

    constructor(address _instanceToCheck) {
        instanceToCheck = IERC165(_instanceToCheck);
    }

    function checkForDesiredInterface() external view returns (bool) {
        bytes4 desiredInterfaceId = type(MyDesiredInterface).interfaceId;
        return instanceToCheck.supportsInterface(desiredInterfaceId);
    }
}



