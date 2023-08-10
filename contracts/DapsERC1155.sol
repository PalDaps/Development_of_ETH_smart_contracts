// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IERC1155 {

    // Был переведен 1 тип токена
    // _operator - тот, кто инициировал трансфер
    // _id - идентификатор токена
    // _value - количество токенов
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint  _id, uint _value);

    // Было переведено множество токенов
    // _ids - массив идентификаторов токенов
    // _values - массив подсчета сколько тех или иных идентификаторов было переведено
    event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint[]  _ids, uint[] _values);

    // Были выданы права для _operator на управление всеми активами _account 
    event ApprovalForAll(address indexed _account, address indexed _operator, bool _approved);

    // Была задана ссылка _value для конкретного идентификатора _id, чтобы его можно было найти
    event URI(string _value, uint indexed _id);

    function balanceOf(address _account, uint _id) external view returns(uint);

    // С помощью этой функции можно посмотреть балансы для многих аккаунтов
    function balanceOfBatch(address[] calldata _accounts, uint[] calldata _ids) external view returns(uint[] memory);

    function setApprovalForAll(address _operator, bool _approved) external;

    function isApprovedForAll(address _account, address _operator) external view returns(bool);

    function safeTransferFrom(address _from, address _to, uint _id, uint _amount, bytes calldata _data) external;

    function safeBatchTransferFrom(address _from, address _to, uint[] calldata _ids, uint[] calldata _amounts, bytes calldata _data) external;
}

interface IERC1155Receiver {

    // Функция, которую мы будем пытаться вызвать у получателя, для того чтобы узнать принимает ли токены или нет
    // _operator - тот, кто инициирует
    function onERC1155Received(address _operator, address _from, uint _id, uint _amount, bytes calldata _data) external returns(bytes4);

    // Для множественного перевода
    function onERC1155BatchReceived(address _operator, address _from, uint[] calldata _ids, uint[] calldata _amounts, bytes calldata data) external returns(bytes4);
}

interface IERC1155MetadataURI is IERC1155 {
    function getURI(uint _id) external view returns(string memory);
}

contract ERC1155 is IERC1155, IERC1155MetadataURI {

    // Мэппинг, который хранит информаию о том какое количество(правый uint) конкретного идентификатора токена или NFT( левый uint) 
    // лежит на конкретном адресе(adress)
    mapping(uint => mapping(address => uint)) private balances;

    // Мэппинг, который хранит информацию о том может ли оператор(правый address) управлять(bool) всеми токенами или NFT 
    // определенного пользователя(левый address)
    mapping(address => mapping(address => bool)) private operatorApprovals;

    // Базовы ссылка, где можно найти токены и NFT
    // Примечание: ссылка должна генерировать от идентификатора токена или NFT
    string private uri;

    constructor(string memory _uri) {

        // Сохраняем ссылку(uri) с помощью функции, которую мы можем позже переопределить
        _setURI(_uri);
    }

    function getURI(uint _id) external view virtual returns(string memory) {
        return uri;
    }

    function balanceOf(address _account, uint _id) public view returns(uint) {
        require(_account != address(0), "There is no such address");
        return balances[_id][_account];
    }

    function balanceOfBatch(address[] calldata _accounts, uint[] calldata _ids) public view returns(uint[] memory batchBalances) {
        require(_accounts.length == _ids.length, "The number of IDs is not equal to the number of accounts");

        // Создаем массив batchBalances такой же длина как и массив _accounts
        batchBalances = new uint[](_accounts.length);

        for(uint i = 0; i < _accounts.length; i++) {
            batchBalances[i] = balanceOf(_accounts[i], _ids[i]);
        }

        // Если мы дали имя возвращаемому значению в определении функции, то писать return не нужно
    }

    function setApprovalForAll(address _operator, bool _approved) external {
        _setApprovalForAll(msg.sender, _operator, _approved);
    }

    function isApprovedForAll(address _account, address _operator) public view returns(bool) {
        return operatorApprovals[_account][_operator];
    }

    function safeTransferFrom(address _from, address _to, uint _id, uint _amount, bytes calldata _data) external {
        require(_from == msg.sender || isApprovedForAll(_from, msg.sender), "You are not the owner and not the approved");

        _safeTransferFrom(_from, _to, _id, _amount, _data);
    }

    function safeBatchTransferFrom(address _from, address _to, uint[] calldata _ids, uint[] calldata _amounts, bytes calldata _data) external {
        require(_from == msg.sender || isApprovedForAll(_from, msg.sender), "You are not the owner and not the approved");

        _safeBatchTransferFrom(_from, _to, _ids, _amounts, _data);
    }

    function _safeTransferFrom(address _from, address _to, uint _id, uint _amount, bytes calldata _data) internal {
        require(_to != address(0), "There is no such address");

        address _requester = msg.sender;
        // Чтобы можно было вызывать Хуки для _safeTransferFrom() и _safeBatchTransferFrom(), то можно преобразовать uint в массив размером 1
        // Само преобразование будет идти с помощью служебной функции _asSingletonArray.
        uint[] memory _ids = _asSingletonArray(_id);
        uint[] memory _amounts = _asSingletonArray(_amount);

        _beforeTokenTransfer(_requester, _from, _to, _ids, _amounts, _data);

        // Для начала смотрим баланс аккаунта с которого мы будем переводим токены или NFT
        uint _fromBalances = balances[_id][_from];

        // Смотрим меньше ли та сумма, которую мы хотим перевести, чем баланс отправителя
        require(_fromBalances >= _amount, "There are not enough funds on the account from which you want to transfer assets");
        // Уменьшаем количество токенов или NFT на аккаунте отправителя(_from)
        balances[_id][_from] = _fromBalances - _amount;
        // Увеличиваем количество токенов или NFT на аккаунте получателя(_to)
        balances[_id][_to] += _amount;

        // Так как переводим один тип токенов, то генерируем событие TransferSingle()
        emit TransferSingle(_requester, _from, _to, _id, _amount);

        _afterTokenTransfer(_requester, _from, _to, _ids, _amounts, _data);

        // Делаем проверку на то, готов ли получатель получать токены или нет
        _doSafeTransferAcceptanceCheck(_requester, _from, _to, _id, _amount, _data);
    }

    function _safeBatchTransferFrom(address _from, address _to, uint[] calldata _ids, uint[] calldata _amounts, bytes calldata _data) internal {
        require(_ids.length == _amounts.length, "The number of IDs is not equal to the number of accounts");

        address _requester = msg.sender;

        _beforeTokenTransfer(_requester, _from, _to, _ids, _amounts, _data);

        for (uint i = 0; i < _ids.length; i++) {
            uint _id = _ids[i];
            uint _amount = _amounts[i];
            uint _fromBalance = balances[_id][_from];

            require(_fromBalance >= _amount, "There are not enough funds on the account from which you want to transfer assets");

            balances[_id][_from] = _fromBalance - _amount;
            // Увеличиваем количество токенов или NFT на аккаунте получателя(_to)
            balances[_id][_to] += _amount;

        }

        emit TransferBatch(_requester, _from, _to, _ids, _amounts);

        _afterTokenTransfer(_requester, _from, _to, _ids, _amounts, _data);

        // Делаем проверку на то, готов ли получатель получать токены или нет
        _doSafeBatchTransferAcceptanceCheck(_requester, _from, _to, _ids, _amounts, _data);
    }

    function _setURI(string memory _newURI) internal virtual {
        uri = _newURI;
    }

    function _setApprovalForAll(address _owner, address _operator, bool _approved) internal {
        require(_owner != _operator, "You are already the owner");
        operatorApprovals[_owner][_operator] = _approved;

        emit ApprovalForAll(_owner, _operator, _approved);
    }

    // Проверка на принятие получателем NFT и токенов
    function _doSafeTransferAcceptanceCheck(address _requester, address _from, address _to, uint _id, uint _amount, bytes calldata _data) private {

        // Проверяем является ли получатель смарт контрактом или нет:
        if (_to.code.length > 0) {

            // Этот получается должен реализовать интерфейс IERC1155Receiver
            // И потом пытаемся вызывать функцию onERC1155Received()
            // И в эту функцию нам нужно закинуть все основные данные
            // Ожидаем, что эта функция вернет 4 байта селектора

            try IERC1155Receiver(_to).onERC1155Received(_requester, _from, _id, _amount, _data) returns(bytes4 resp) {
                
                // Если смарт контракт получателя возвращает ответ(resp), который не равен тому селектору, который я ожидаю, то
                // смарт контракт получатель не принимает токены или NFT 
                if (resp != IERC1155Receiver.onERC1155Received.selector) {
                    revert("This address does not accept tokens or NFT");
                }
            } 
            
            // Здесь мы отлавливаем причину отказа транкзации
            catch Error(string memory reason){
                revert(reason);
            }

            // Если не удалось получить причину отказа
            catch {
                revert("Non-ERC1155 receiver");
            }
        }
    }
    function _doSafeBatchTransferAcceptanceCheck(address _requester, address _from, address _to, uint[] memory _ids, uint[] memory _amounts, bytes memory _data) private {
        if (_to.code.length > 0) {
            try IERC1155Receiver(_to).onERC1155BatchReceived(_requester, _from, _ids, _amounts, _data) returns(bytes4 resp) {
                if (resp != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("This address does not accept tokens or NFT");
                }
            } 
            catch Error(string memory reason){
                revert(reason);
            }
            catch {
                revert("Non-ERC1155 receiver");
            }
        }
    }

    // Cлужебная функция для перевода uint в массив размером 1
    function _asSingletonArray(uint _element) private pure returns(uint[] memory res) {
        res = new uint[](1);
        res[0] = _element;
    }

    // Хуки
    function _beforeTokenTransfer(address _requester, address _from, address _to, uint[] memory _ids, uint[] memory _amounts, bytes memory _data) internal virtual{}

    function _afterTokenTransfer(address _requester, address _from, address _to, uint[] memory _ids, uint[] memory _amounts, bytes memory _data) internal virtual{}

 }