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

// Этот интерфейс говорит нам о том, поддерживает ли указанный смарт контракт какой-либо интерфейс или нет
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

    // Эта функция принимает данные и должа вернуть bytes4.
    // Контракт получателя NFT должен реализовывать вот такую функцию и эта функция должна возвращать правильную
    // последовательность байт.
    function OnERC721Received(address _operator, address _to, uint _tokenId, bytes calldata data) external returns(bytes4);
}

// Пример контракта который получает NFT и реализовывает функцию OnERC721Received()
// contract ContractRecipientNFT is IERC721Receiver {

//     // Реализует функцию
//     function OnERC721Received(address _operator, address _to, uint _tokenId, bytes calldata data) external returns(bytes4) {

//         return IERC721Receiver.OnERC721Received.selector;
//     }
// }
// ***********************************************************************************************************************************************

contract ERC721 is ERC165, IERC721Metadata {

    // Подрубаем функцию toString
    using Strings for uint;

    string public name;
    string public symbol;

    // Мэппинг, который содержит информацию о том сколько у address NFT(uint)
    mapping(address => uint) balances; 

    // Мэппинг, который содержит информацию о том, кто(address) владеет конкретным NFT(uint)
    mapping(uint => address) owners; 

    // Мэппинг, который содержит информацию о том, кто(address) может управлять конкретным NFT(uint)
    mapping(uint => address) tokenApprovals; 

    // Мэппинг, который содержить информацию о том, может ли конкретный адресс(правый address(operator)) управлять(bool) 
    // всеми NFT другого конкретного адреса(левый address(Владелец NFT))
    mapping(address => mapping(address => bool)) operatorApprovals; 
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    // Модификатор, который проверяет введен ли конкретный NFT(_tokenId) в оборот
    modifier _requireMinted(uint _tokenId) {
        require(_exists(_tokenId), "Not minted");
        _;
    }

    // Проверяет есть ли у NFT(_tokenId) владелец c помощью мэппинга owners
    function _exists(uint _tokenId) internal view returns(bool){
        return owners[_tokenId] != address(0);
    }

    // Геттер имени
    function getName() public view returns(string memory) {
        return name;
    }

    // Геттер символа
     function getSymbol() public view returns(string memory) {
        return symbol;
     }
    

    // Безопасный трансфер
    function safeTransferFrom(address _from, address _to, uint _tokenId) public {
        // Смотрим является ли msg.sender доверенным лицом или владельцем NFT(_tokenId)
        require (_isApprovedOrWner(msg.sender, _tokenId), "Not an owner or Approved person");

        // Делегируем в функцию _safeTransfer()
        _safeTransfer(_from, _to, _tokenId);
    }

    // Служебный безопасный трансфер
    function _safeTransfer(address _from, address _to, uint _tokenId) internal {
        
        // Делеигруем в функцию _transfer()
        _transfer(_from, _to, _tokenId);

        // Собственно вот в чем выражена безопасная функция _safeTransfer()
        // Кратко: может ли адрес _to владеть NFT(_tokenId) или нет.
        // Непосредтсвенно здесь мы смотрим может ли получатель владеть NFT или нет.
        // Допустим когда мы переводим на адрес smart-contract'a, а не на адрес кошелька
        // Поэтому, если мы переводим на смарт контракт, то этот смарт контракт должен уметь на функцию _checkOnERC721Received
        // Если смарт контракт не отвечает на эту функцию или эта функция выдает какую-нибудь ошибку, то перевод NFR мы останавливаем

        require(_checkOnERC721Received(_from, _to, _tokenId), "Not an ERC721 receiver");
    }

    // Может ли адрес _to владеть NFT(_tokenId) или нет
    function _checkOnERC721Received(address _from, address _to, uint _tokenId) private returns(bool) {

        // Проверяем, является ли адресс _to смарт контрактом или нет.
        // Забавная штука
        if (_to.code.length > 0) {
            
            // Будем обрабатывает функцию с помощью блока try и catch

            // Преобразуем _to в обьект типа IERC721Receiver, чтобы попытаться вызвать функцию OnERC721Received()
            // Почему мы передаем в фнукцию msg.sender, _from, _tokenId, bytes("") я без понятия пока что зачем мы их передаем
            // 
            try IERC721Receiver(_to).OnERC721Received(msg.sender, _from, _tokenId, bytes("")) returns(bytes4 ret) {
                return ret == IERC721Receiver.OnERC721Received.selector;
            } catch(bytes memory reason) {
                
                // Если вызов функции OnERC721Received() завершается с ошибкой, то ее обрабатываем
                // В переменную reason упадет сообщение об ошибке

                // когда получатель не реализует интерфейс IERC721Receiver
                // и не имеет функции OnERC721Received()

                // Что такое revert?
                // Команда revert в Solidity используется для того, чтобы вызвать исключение и отменить все изменения состояния, 
                // которые произошли в транзакции до этого момента. Она позволяет обеспечить, что состояние смарт-контракта 
                // останется неизменным в случае ошибок или когда какие-либо условия контракта не выполняются.
                if (reason.length == 0) {

                    // Если сообщение об ошибке отсутствует, это может указывать на то, что смарт-контракт _to не реализует интерфейс IERC721Receiver и не имеет функции OnERC721Received.

                    // Здесь revert("Not ERC721 receiver"); вызывается с сообщением "Not ERC721 receiver", информируя 
                    // отправителя транзакции о том, что контракт-получатель не соответствует ожиданиям.
                    revert("Not ERC721 receiver");
                } else {

                    // Если в reason что-то упало, то мы должны это показать
                    assembly {
                        
                        // Язык ЮЛ
                        // Если есть какое-то сообщение об ошибке (то есть длина reason больше 0), то это сообщение об ошибке выводится с помощью инлайн-ассемблера.

                        // В этом блоке используется инлайн-ассемблер Solidity (язык Yul) для возврата конкретной ошибки, 
                        // которую вернул контракт _to. Это позволяет детально указать причину ошибки.
                        revert(add(32, reason), mload(reason))
                    }
                }
            }

        }
        else return true;
    } 

    // Показывает кто владеет данным NFT(_tokenId)
    function ownerOf(uint _tokenId) public view _requireMinted(_tokenId) returns(address){
        return owners[_tokenId];
    }

    // Показывает какой баланс на счету у _owner
    function balanceOf(address _owner) public view returns(uint) {
        require(_owner != address(0), "zero address");
        return balances[_owner]; 
    }

    // Функция заглушка для basedURI
    function _baseURI() internal pure virtual returns(string memory) {
        return "";
    }

    // Узнаем, где будет храниться NFT
    function tokenURI(uint _tokenId) public view _requireMinted(_tokenId) virtual returns(string memory) {

        // baseURI 
        // это путь до хранилища, где лежит NFT
        // ipfs://123 ->  ipfs://
        // example.com/nfts/123 -> example.com/nfts/

        string memory baseURI = _baseURI();

        return bytes(baseURI).length > 0 ?

            // Мы берем tokeId и приделываем к нему эту часть example.com/nfts/
            string(abi.encodePacked(baseURI, _tokenId.toString())) :

            // Если baseURI отсутствует, то возвращаем пустую строку или NFT
            "";

    } 

    //Выдаем разрешение на управление NFT кому-то
    function approve(address _to, uint _tokenId) public _requireMinted(_tokenId) {
        address owner = ownerOf(_tokenId);
        require(_to != address(0), "_to is address(0)");
        require(msg.sender == owner || isApprovedForAll(owner, msg.sender), "You are not an owner");
        require(_to != owner, "Cannot be approve to self");
        tokenApprovals[_tokenId] = _to;

        emit Approval(owner, _to, _tokenId);
    }

    // Функция, которая говорит о том, что может ли _operator управлять всеми NFT другого адреса(_owner)
    function isApprovedForAll(address _owner, address _operator) public view returns(bool) {
        return operatorApprovals[_owner][_operator];
    }

    // Функция, которая говорит о том, кто может управлять конкретным NFT(_tokenId)
    function getApproved(uint _tokenId) public view _requireMinted(_tokenId) returns(address) {
        return tokenApprovals[_tokenId];
    }

    // Разрешает адресу(_operator) управлять всеми активами msg.sender
    function setApprovalForAll(address _operator, bool _approved) public {
        require(msg.sender != _operator, "Can not approve to self");
        operatorApprovals[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    // Безопасный минтинг
    // Вводим новый NFT в оборот и владеть им будет адрес(_to)
    function _safeMint(address _to, uint _tokenId) internal virtual {
        _mint(_to, _tokenId);

        require(_checkOnERC721Received(msg.sender, _to, _tokenId), "Not an ERC721 receiver");
    }

    // Функция mint
    function _mint(address _to, uint _tokenId) internal virtual {
        require(_to != address(0), "To cannot be zero");
        require(!_exists(_tokenId), "Already exists");

        owners[_tokenId] = _to;
        balances[_to]++;
    }

    // Выводим NFT из оборота
    function burn(uint _tokenId) internal virtual{
        require(_isApprovedOrWner(msg.sender, _tokenId), "You are not an owner");
        address owner = ownerOf(_tokenId);

        delete tokenApprovals[_tokenId];
        balances[owner]--;
        delete owners[_tokenId];
    }

    // Проверяет является ли адресс владельцем или доверенным лицом(spender) конкретной NFT(uint _tokenId)
    // spender - транжира, расточитель, тратящий
    function _isApprovedOrWner(address spender, uint _tokenId) internal view returns(bool){
        
        // Для начала смотрим кто владее данным NFT(_tokenId) с помощью ownerOf
        address owner = ownerOf(_tokenId);
        return(

            // Может быть spender это и есть владелец?
            spender == owner ||

            // или spender имеет разрешение на все NFT его законного владельца(owner)
            isApprovedForAll(owner, spender) ||

            // или spender'у имеет разрешение на владение это конкретного NFT(_tokenId)
            spender == getApproved(_tokenId)
        );
    }

    // Обычный трансфер
    function transferFrom(address _from, address _to, uint _tokenId) external {

        // Для начала необходимо проверить: есть ли у того кто будет делать перевод на это права(Владеет ли )
        require(_isApprovedOrWner(msg.sender, _tokenId), "Not an owner or approved");

        // Вызываем служебную функцию для перевода
        _transfer(_from, _to, _tokenId);
    }


    // Cлужебный перевод NFT(_tokenId) от адреса _from адресу _to
    function _transfer(address _from, address _to, uint _tokenId) internal {
        
        // Первая проверка на то, является ли NFT(_tokenId) собственностью адреса(_from)
        require(ownerOf(_tokenId) == _from, "Not an owner");

        // Получель существует
        require(_to != address(0), "Recipient does not exist");

        _beforeTransferToken(_from, _to, _tokenId);

        // Уменьшаем баланс _from на 1. -1 NFT на его аккаунте
        balances[_from]--;
        // Увеличиваем баланс _to на 1. +1 NFT на его аккаунте
        balances[_to]++;
        // Передаем владение NFT адресу _to
        owners[_tokenId] = _to;

        // Порождаем событие о переводе
        emit Transfer(_from, _to, _tokenId);
         
        _afterTransferToken(_from, _to, _tokenId);

    }

    // Поддерживает ли наш смарт контракт какой-либо интерфейс?
    function supportsInterface(bytes4 interfaceId) public view virtual override returns(bool) {

        // || super.supportsInterface(interfaceId)
        return interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }


    // (Коллбеки) Функции для переопределения в классах - потомках
    function _beforeTransferToken(address _from, address _to, uint _tokenId) internal virtual {}

    function _afterTransferToken(address _from, address _to, uint _tokenId) internal virtual {}

 }

// Добавляет функциональность по хранению и обработке URI-адресов для каждого токена.
abstract contract ERC721URIStorage is ERC721 {

    mapping(uint => string) tokenURIs; // Сохраняет информацию о том, что у конкретного NFT(uint) есть ссылка(string)

    // Функция позволяет узнать URI токена
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

    // Непосредственно утсанавливает URI для конкретного токена
    function _setTokenURI(uint _tokenId, string memory _tokenURI) internal virtual _requireMinted(_tokenId) {
        tokenURIs[_tokenId] = _tokenURI;
    }

    // Кроме базовой логики сжигания токена, она еще удаляет URI Токена
    function burn(uint _tokenId) internal virtual override {
        super.burn(_tokenId); // передает на управление выше
        if (bytes(tokenURIs[_tokenId]).length != 0) {
            delete tokenURIs[_tokenId];
        }
    }
 }

 // NFTs
 contract PlantestNFT is ERC721, ERC721URIStorage {

    // Вводом переменную для владельца
    address owner;

    // Вводим текущий идентификатор токена, который будет использоваться при следующем минтинге токена
    uint currentTokenId;
    
    // С помощью конструктора задаем название Токену и его символ
    // определяем владельца
    constructor() ERC721("Token", "TKN") {
        owner = msg.sender;
    }

    // Непосредтсвенно, создаем функцию(НЕ ПЕРЕОПРЕДЕЛЯЕМ!!!) для создания NFT и делигируем в другие функции
    // Что такое calldata?
    // calldata - это ключевое слово в Solidity, которое относится к типу данных и модификатору местоположения для 
    // входных параметров функции. В Ethereum, когда вы вызываете функцию смарт-контракта, аргументы этой функции 
    // передаются как часть транзакции. Эти данные сохраняются в специальной области памяти, называемой calldata.

    // Чем calldata Отличает от других типов хранения ссылочных переменных?
    // 1. Только для чтения: Вы не можете изменить данные в calldata внутри функции. Это действительно "только для чтения".
    // 2. Дешевле по газу: Чтение из calldata обычно дешевле по сравнению с чтением из памяти или хранилища в смысле затрат на газ. 
    // 3. Только для внешних функций: calldata может быть использован только во внешних функциях (external и public). 
    // Эти функции могут быть вызваны извне контракта, но не могут быть вызваны внутри контракта (за исключением этого контракта).
    function safeMint(address _to, string calldata _tokenId) public {
        require(owner == msg.sender, "not an owner");

        // Создаем NFT для _to
        _safeMint(_to, currentTokenId);

        _setTokenURI(currentTokenId, _tokenId);

        currentTokenId++;
    }

    // Поддерживает ли этот смарт-контракт какой-либо интерфейс?
    function supportsInterface(bytes4 interfaceId) public view override returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // Задаем базаовый URI Для токена
    function _baseURI() internal pure override returns(string memory) {
        return "ipfsMine://";
    }

    // ПЕРЕОПРЕДЕЛЯЕМ функции
    function burn(uint tokenId) internal override(ERC721, ERC721URIStorage) {
        super.burn(tokenId);
    }
    // Устанавливаем URI
    function tokenURI(uint tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
 }