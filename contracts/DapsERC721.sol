// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ***********************************************************************************************************************************************
library Strings {
    function toString(uint _value) internal pure returns(string memory) {
        if (_value == 0) {
            return "0";
        }
        uint temp = _value;
        uint digits;
        while (temp !=0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits -=1; // digits--; 
            buffer[digits] = bytes1(uint8(48 + uint256(_value%10)));
            _value /= 10; 
        }
        return string(buffer); 
    } 
}
// ***********************************************************************************************************************************************

interface IERC721 {

    event Transfer(address indexed _from, address indexed _to, uint indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function balanceOf(address _owner) external view returns(uint);

    function ownerOf(uint _tokenId) external view returns(address);

    function safeTransferFrom(address _from, address _to, uint _tokenId) external;

    // function safeTransferFrom(address _from, address _to, uint _tokenId, bytes calldata data) external;

    function transferFrom(address _from, address _to, uint _tokenId) external;

    function approve(address _to, uint _tokenId) external;

    function setApprovalForAll(address _operator, bool _approved) external;

    function getApproved(uint _tokenId) external view returns(address);

    function isApprovedForAll(address _owner, address _operator) external view returns(bool);

}

interface IERC721Metadata is IERC721 {
    function getName() external view returns(string memory);

    function getSymbol() external view returns(string memory);

    function tokenURI(uint _tokenId) external view returns(string memory);
}

// ���� ��������� ������� ��� � ���, ������������ �� ��������� ����� �������� �����-���� ��������� ��� ���
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns(bool);
}

contract ERC165 is IERC165 {
    function supportsInterface(bytes4 interfaceId) public view virtual returns(bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// ***********************************************************************************************************************************************
interface IERC721Receiver {

    // ��� ������� ��������� ������ � ����� ������� bytes4.
    // �������� ���������� NFT ������ ������������� ��� ����� ������� � ��� ������� ������ ���������� ����������
    // ������������������ ����.
    function OnERC721Received(address _operator, address _to, uint _tokenId, bytes calldata data) external returns(bytes4);
}

// ������ ��������� ������� �������� NFT � ������������� ������� OnERC721Received()
// contract ContractRecipientNFT is IERC721Receiver {

//     // ��������� �������
//     function OnERC721Received(address _operator, address _to, uint _tokenId, bytes calldata data) external returns(bytes4) {

//         return IERC721Receiver.OnERC721Received.selector;
//     }
// }
// ***********************************************************************************************************************************************

contract ERC721 is ERC165, IERC721Metadata {

    // ��������� ������� toString
    using Strings for uint;

    string public name;
    string public symbol;

    // �������, ������� �������� ���������� � ��� ������� � address NFT(uint)
    mapping(address => uint) balances; 

    // �������, ������� �������� ���������� � ���, ���(address) ������� ���������� NFT(uint)
    mapping(uint => address) owners; 

    // �������, ������� �������� ���������� � ���, ���(address) ����� ��������� ���������� NFT(uint)
    mapping(uint => address) tokenApprovals; 

    // �������, ������� ��������� ���������� � ���, ����� �� ���������� ������(������ address(operator)) ���������(bool) 
    // ����� NFT ������� ����������� ������(����� address(�������� NFT))
    mapping(address => mapping(address => bool)) operatorApprovals; 
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    // �����������, ������� ��������� ������ �� ���������� NFT(_tokenId) � ������
    modifier _requireMinted(uint _tokenId) {
        require(_exists(_tokenId), "Not minted");
        _;
    }

    // ��������� ���� �� � NFT(_tokenId) �������� c ������� �������� owners
    function _exists(uint _tokenId) internal view returns(bool){
        return owners[_tokenId] != address(0);
    }

    // ������ �����
    function getName() public view returns(string memory) {
        return name;
    }

    // ������ �������
     function getSymbol() public view returns(string memory) {
        return symbol;
     }
    

    // ���������� ��������
    function safeTransferFrom(address _from, address _to, uint _tokenId) public {
        // ������� �������� �� msg.sender ���������� ����� ��� ���������� NFT(_tokenId)
        require (_isApprovedOrWner(msg.sender, _tokenId), "Not an owner or Approved person");

        // ���������� � ������� _safeTransfer()
        _safeTransfer(_from, _to, _tokenId);
    }

    // ��������� ���������� ��������
    function _safeTransfer(address _from, address _to, uint _tokenId) internal {
        
        // ���������� � ������� _transfer()
        _transfer(_from, _to, _tokenId);

        // ���������� ��� � ��� �������� ���������� ������� _safeTransfer()
        // ������: ����� �� ����� _to ������� NFT(_tokenId) ��� ���.
        // ��������������� ����� �� ������� ����� �� ���������� ������� NFT ��� ���.
        // �������� ����� �� ��������� �� ����� smart-contract'a, � �� �� ����� ��������
        // �������, ���� �� ��������� �� ����� ��������, �� ���� ����� �������� ������ ����� �� ������� _checkOnERC721Received
        // ���� ����� �������� �� �������� �� ��� ������� ��� ��� ������� ������ �����-������ ������, �� ������� NFR �� �������������

        require(_checkOnERC721Received(_from, _to, _tokenId), "Not an ERC721 receiver");
    }

    // ����� �� ����� _to ������� NFT(_tokenId) ��� ���
    function _checkOnERC721Received(address _from, address _to, uint _tokenId) private returns(bool) {

        // ���������, �������� �� ������ _to ����� ���������� ��� ���.
        // �������� �����
        if (_to.code.length > 0) {
            
            // ����� ������������ ������� � ������� ����� try � catch

            // ����������� _to � ������ ���� IERC721Receiver, ����� ���������� ������� ������� OnERC721Received()
            // ������ �� �������� � ������� msg.sender, _from, _tokenId, bytes("") � ��� ������� ���� ��� ����� �� �� ��������
            // 
            try IERC721Receiver(_to).OnERC721Received(msg.sender, _from, _tokenId, bytes("")) returns(bytes4 ret) {
                return ret == IERC721Receiver.OnERC721Received.selector;
            } catch(bytes memory reason) {
                
                // ���� ����� ������� OnERC721Received() ����������� � �������, �� �� ������������
                // � ���������� reason ������ ��������� �� ������

                // ����� ���������� �� ��������� ��������� IERC721Receiver
                // � �� ����� ������� OnERC721Received()

                // ��� ����� revert?
                // ������� revert � Solidity ������������ ��� ����, ����� ������� ���������� � �������� ��� ��������� ���������, 
                // ������� ��������� � ���������� �� ����� �������. ��� ��������� ����������, ��� ��������� �����-��������� 
                // ��������� ���������� � ������ ������ ��� ����� �����-���� ������� ��������� �� �����������.
                if (reason.length == 0) {

                    // ���� ��������� �� ������ �����������, ��� ����� ��������� �� ��, ��� �����-�������� _to �� ��������� ��������� IERC721Receiver � �� ����� ������� OnERC721Received.

                    // ����� revert("Not ERC721 receiver"); ���������� � ���������� "Not ERC721 receiver", ���������� 
                    // ����������� ���������� � ���, ��� ��������-���������� �� ������������� ���������.
                    revert("Not ERC721 receiver");
                } else {

                    // ���� � reason ���-�� �����, �� �� ������ ��� ��������
                    assembly {
                        
                        // ���� ��
                        // ���� ���� �����-�� ��������� �� ������ (�� ���� ����� reason ������ 0), �� ��� ��������� �� ������ ��������� � ������� ������-����������.

                        // � ���� ����� ������������ ������-��������� Solidity (���� Yul) ��� �������� ���������� ������, 
                        // ������� ������ �������� _to. ��� ��������� �������� ������� ������� ������.
                        revert(add(32, reason), mload(reason))
                    }
                }
            }

        }
        else return true;
    } 

    // ���������� ��� ������� ������ NFT(_tokenId)
    function ownerOf(uint _tokenId) public view _requireMinted(_tokenId) returns(address){
        return owners[_tokenId];
    }

    // ���������� ����� ������ �� ����� � _owner
    function balanceOf(address _owner) public view returns(uint) {
        require(_owner != address(0), "zero address");
        return balances[_owner]; 
    }

    // ������� �������� ��� basedURI
    function _baseURI() internal pure virtual returns(string memory) {
        return "";
    }

    // ������, ��� ����� ��������� NFT
    function tokenURI(uint _tokenId) public view _requireMinted(_tokenId) virtual returns(string memory) {

        // baseURI 
        // ��� ���� �� ���������, ��� ����� NFT
        // ipfs://123 ->  ipfs://
        // example.com/nfts/123 -> example.com/nfts/

        string memory baseURI = _baseURI();

        return bytes(baseURI).length > 0 ?

            // �� ����� tokeId � ����������� � ���� ��� ����� example.com/nfts/
            string(abi.encodePacked(baseURI, _tokenId.toString())) :

            // ���� baseURI �����������, �� ���������� ������ ������ ��� NFT
            "";

    } 

    //������ ���������� �� ���������� NFT ����-��
    function approve(address _to, uint _tokenId) public _requireMinted(_tokenId) {
        address owner = ownerOf(_tokenId);
        require(_to != address(0), "_to is address(0)");
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "You are not an owner");
        require(_to != owner, "Cannot be approve to self");
        tokenApprovals[_tokenId] = _to;

        emit Approval(owner, _to, _tokenId);
    }

    // �������, ������� ������� � ���, ��� ����� �� _operator ��������� ����� NFT ������� ������(_owner)
    function isApprovedForAll(address _owner, address _operator) public view returns(bool) {
        return operatorApprovals[_owner][_operator];
    }

    // �������, ������� ������� � ���, ��� ����� ��������� ���������� NFT(_tokenId)
    function getApproved(uint _tokenId) public view _requireMinted(_tokenId) returns(address) {
        return tokenApprovals[_tokenId];
    }

    // ��������� ������(_operator) ��������� ����� �������� msg.sender
    function setApprovalForAll(address _operator, bool _approved) public {
        require(msg.sender != _operator, "Can not approve to self");
        operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    // ���������� �������
    // ������ ����� NFT � ������ � ������� �� ����� �����(_to)
    function _safeMint(address _to, uint _tokenId) internal virtual {
        _mint(_to, _tokenId);

        require(_checkOnERC721Received(msg.sender, _to, _tokenId), "Not an ERC721 receiver");
    }

    // ������� mint
    function _mint(address _to, uint _tokenId) internal virtual {
        require(_to != address(0), "To cannot be zero");
        require(!_exists(_tokenId), "Already exists");

        owners[_tokenId] = _to;
        balances[_to]++;
    }

    // ������� NFT �� �������
    function burn(uint _tokenId) internal virtual{
        require(_isApprovedOrWner(msg.sender, _tokenId), "You are not an owner");
        address owner = ownerOf(_tokenId);

        delete tokenApprovals[_tokenId];
        balances[owner]--;
        delete owners[_tokenId];
    }

    // ��������� �������� �� ������ ���������� ��� ���������� �����(spender) ���������� NFT(uint _tokenId)
    // spender - ��������, �����������, ��������
    function _isApprovedOrWner(address spender, uint _tokenId) internal view returns(bool){
        
        // ��� ������ ������� ��� ������ ������ NFT(_tokenId) � ������� ownerOf
        address owner = ownerOf(_tokenId);
        return(

            // ����� ���� spender ��� � ���� ��������?
            spender == owner ||

            // ��� spender ����� ���������� �� ��� NFT ��� ��������� ���������(owner)
            isApprovedForAll(owner, spender) ||

            // ��� spender'� ����� ���������� �� �������� ��� ����������� NFT(_tokenId)
            spender == getApproved(_tokenId)
        );
    }

    // ������� ��������
    function transferFrom(address _from, address _to, uint _tokenId) external {

        // ��� ������ ���������� ���������: ���� �� � ���� ��� ����� ������ ������� �� ��� �����(������� �� )
        require(_isApprovedOrWner(msg.sender, _tokenId), "Not an owner or approved");

        // �������� ��������� ������� ��� ��������
        _transfer(_from, _to, _tokenId);
    }


    // C�������� ������� NFT(_tokenId) �� ������ _from ������ _to
    function _transfer(address _from, address _to, uint _tokenId) internal {
        
        // ������ �������� �� ��, �������� �� NFT(_tokenId) �������������� ������(_from)
        require(ownerOf(_tokenId) == _from, "Not an owner");

        // �������� ����������
        require(_to != address(0), "Recipient does not exist");

        _beforeTransferToken(_from, _to, _tokenId);

        // ��������� ������ _from �� 1. -1 NFT �� ��� ��������
        balances[_from]--;
        // ����������� ������ _to �� 1. +1 NFT �� ��� ��������
        balances[_to]++;
        // �������� �������� NFT ������ _to
        owners[_tokenId] = _to;

        // ��������� ������� � ��������
        emit Transfer(_from, _to, _tokenId);
         
        _afterTransferToken(_from, _to, _tokenId);

    }

    // ������������ �� ��� ����� �������� �����-���� ���������?
    function supportsInterface(bytes4 interfaceId) public view virtual override returns(bool) {

        // || super.supportsInterface(interfaceId)
        return interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }


    // (��������) ������� ��� ��������������� � ������� - ��������
    function _beforeTransferToken(address _from, address _to, uint _tokenId) internal virtual {}

    function _afterTransferToken(address _from, address _to, uint _tokenId) internal virtual {}

 }

// ��������� ���������������� �� �������� � ��������� URI-������� ��� ������� ������.
abstract contract ERC721URIStorage is ERC721 {

    mapping(uint => string) tokenURIs; // ��������� ���������� � ���, ��� � ����������� NFT(uint) ���� ������(string)

    // ������� ��������� ������ URI ������
    function tokenURI(uint _tokenId) public view override virtual _requireMinted(_tokenId) returns(string memory){


        string memory _tokenURI = tokenURIs[_tokenId];
        
        string memory _base = _baseURI();

        if (bytes(_base).length == 0) {
            return _tokenURI;
        }
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(_base, _tokenURI));
        }

        return super.tokenURI(_tokenId);
    }

    // ��������������� ������������� URI ��� ����������� ������
    function _setTokenURI(uint _tokenId, string memory _tokenURI) internal virtual _requireMinted(_tokenId) {
        tokenURIs[_tokenId] = _tokenURI;
    }

    // ����� ������� ������ �������� ������, ��� ��� ������� URI ������
    function burn(uint _tokenId) internal virtual override {
        super.burn(_tokenId); // �������� �� ���������� ����
        if (bytes(tokenURIs[_tokenId]).length != 0) {
            delete tokenURIs[_tokenId];
        }
    }
 }

 // NFTs
 contract PlantestNFT is ERC721, ERC721URIStorage {

    // ������ ���������� ��� ���������
    address owner;

    // ������ ������� ������������� ������, ������� ����� �������������� ��� ��������� �������� ������
    uint currentTokenId;
    
    // � ������� ������������ ������ �������� ������ � ��� ������
    // ���������� ���������
    constructor() ERC721("Token", "TKN") {
        owner = msg.sender;
    }

    // ���������������, ������� �������(�� ��������������!!!) ��� �������� NFT � ���������� � ������ �������
    // ��� ����� calldata?
    // calldata - ��� �������� ����� � Solidity, ������� ��������� � ���� ������ � ������������ �������������� ��� 
    // ������� ���������� �������. � Ethereum, ����� �� ��������� ������� �����-���������, ��������� ���� ������� 
    // ���������� ��� ����� ����������. ��� ������ ����������� � ����������� ������� ������, ���������� calldata.

    // ��� calldata �������� �� ������ ����� �������� ��������� ����������?
    // 1. ������ ��� ������: �� �� ������ �������� ������ � calldata ������ �������. ��� ������������� "������ ��� ������".
    // 2. ������� �� ����: ������ �� calldata ������ ������� �� ��������� � ������� �� ������ ��� ��������� � ������ ������ �� ���. 
    // 3. ������ ��� ������� �������: calldata ����� ���� ����������� ������ �� ������� �������� (external � public). 
    // ��� ������� ����� ���� ������� ����� ���������, �� �� ����� ���� ������� ������ ��������� (�� ����������� ����� ���������).
    function safeMint(address _to, string calldata _tokenId) public {
        require(owner == msg.sender, "not an owner");

        // ������� NFT ��� _to
        _safeMint(_to, currentTokenId);

        _setTokenURI(currentTokenId, _tokenId);

        currentTokenId++;
    }

    // ������������ �� ���� �����-�������� �����-���� ���������?
    function supportsInterface(bytes4 interfaceId) public view override returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // ������ �������� URI ��� ������
    function _baseURI() internal pure override returns(string memory) {
        return "ipfsMine://";
    }

    // �������������� �������
    function burn(uint tokenId) internal override(ERC721, ERC721URIStorage) {
        super.burn(tokenId);
    }
    // ������������� URI
    function tokenURI(uint tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
 }