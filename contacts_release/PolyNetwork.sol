// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

// 1. Poly Network - это кросс-чейн протокол, который позволяет взаимодействовать между различными блокчейнами, такими как Ethereum, 
// Binance Smart Chain, Bitcoin, Neo

// 2. Poly Chain - это блокчейн, который поддерживается сетью

// 3. Кросс-чейн менеджеры - это программное обеспечение, которое позволяет осуществлять транзакции между различными блокчейнами

// 4. Сеть контрактов межсетевого управления - это сеть смарт-контрактов, которые используются для управления передачей токенов между 
// различными блокчейнами.
// verifyHeaderAndExecuteTx() -  является частью этой сети контрактов.

contract NetworkOfInternetworkManagementContracts {

    modifier whenNotPaused {
        _;
    }
    // Используется для проверки транзакции, которая была выполнена в исходной цепочке, прежде чем ее результаты будут применены в текущую цепочке.
    function verifyHeaderAndExecuteTx(bytes memory proof, bytes memory rawHeader, bytes memory headerProof, bytes memory curRawHeader,bytes memory headerSig) whenNotPaused public returns(bool) {
    
    // proof = является доказательством Меркле для транзакции в цепочке Poly. Доказательство Меркле - это криптографическая 
    // структура данных, которая используется для подтверждения включения транзакции в блокчейн. Другими словами, оно используется для 
    // подтверждения того, что транзакция была выполнена в исходной цепочке.
    
    // rawHeader = это заголовок, содержащий crossStateRoot, который используется для проверки доказательства Меркле транзакции, указанной выше. 
    // crossStateRoot - это корневой хеш состояния.
    
    // headerProof и curRawHeader = другие аргументы, которые используются для проверки доказательства Меркле транзакции. Они могут содержать 
    // дополнительные данные, которые необходимы для проверки доказательства.
    
    // headerSig = это подпись заголовка, который содержит информацию о транзакции, выполненной в исходной цепочке. Она происходит от хранителей 
    // цепочки Poly и используется для подтверждения подлинности заголовка.
    }



    // Функция нужна для проверки подписи заголовка, который содержит информацию о транзакции, выполненной в исходной цепочке.
    // Функция verifyHeaderAndExecuteTx() использует результаты проверки функции verifySig() для выполнения соответствующей 
    // транзакции в текущей цепочке.
    function verifySig(bytes memory _rawHeader, bytes memory _sigList, address[] memory _keepers, uint _m) internal pure returns (bool){

        //_rawHeader = 0x0000000000000000000000001e8bb7336ce3a75ea668e10854c6b6c9530dab7...
        // это заголовок, который содержит информацию о транзакции, выполненной в исходной цепочке. Он используется для вычисления хеша заголовка, 
        // который затем используется для проверки подписи.

        //_sigList = // List of 3 signatures from 0x3dFcCB7b8A6972CDE3B695d3C0c032514B0f3825,0x4c46e1f946362547546677Bfa719598385ce56f2,0x51b7529137D34002c4ebd81A2244F0ee7e95B2C0
        // это список подписей, которые были созданы узлами консенсуса Poly. Они используются для подтверждения подлинности заголовка.

        //_keepers = ["0x3dFcCB7b8A6972CDE3B695d3C0c032514B0f3825","0x4c46e1f946362547546677Bfa719598385ce56f2","0xF81F676832F6dFEC4A5d0671BD27156425fCEF98","0x51b7529137D34002c4ebd81A2244F0ee7e95B2C0"]
        // это массив адресов узлов консенсуса Poly. Они используются для проверки того, что подписи в _sigList были созданы 
        // действительными узлами консенсуса.

        //_m = 3
        // это количество подписей, которые должны быть проверены. Оно указывает, сколько подписей из _sigList должны быть действительными, 
        // чтобы функция вернула true.
        
        bytes32 hash = getHeaderHash(_rawHeader);

        uint sigCount = _sigList.length.div(POLYCHAIN_SIGNATURE_LEN);
        address[] memory signers = new address[](sigCount);

        // (Dedaub comment)
        //   signers = [
        //     0x4c46e1f946362547546677Bfa719598385ce56f2,
        //     0x3dFcCB7b8A6972CDE3B695d3C0c032514B0f3825,
        //     0x51b7529137D34002c4ebd81A2244F0ee7e95B2C0
        // ]

        bytes32 r;
        bytes32 s;
        uint8 v;
        for(uint j = 0; j  < sigCount; j++){
            r = Utils.bytesToBytes32(Utils.slice(_sigList, j*POLYCHAIN_SIGNATURE_LEN, 32));
            s =  Utils.bytesToBytes32(Utils.slice(_sigList, j*POLYCHAIN_SIGNATURE_LEN + 32, 32));
            v =  uint8(_sigList[j*POLYCHAIN_SIGNATURE_LEN + 64]) + 27;
            signers[j] =  ecrecover(sha256(abi.encodePacked(hash)), v, r, s);
            if (signers[j] == address(0)) return false;
        }
        return Utils.containMAddresses(_keepers, signers, _m);


    }



    // Функция используется для проверки того, существует ли транзакция в блокчейне Poly или нет
    // Суть: Функция вычисляет хеш-значение для транзакции, используя доказательство Меркле, 
    // и сравнивает его с корнем дерева Меркле, чтобы убедиться, что транзакция действительно была включена в блокчейн Poly.
    function merkleProve(bytes memory _auditPath, bytes32 _root) internal pure returns (bytes memory) {
        // _auditPath = является доказательством Меркле для транзакции в блокчейне Poly.
        // _roo = является корнем дерева Меркле для блока, содержащего эту транзакцию.
        
        uint256 off = 0;    
        bytes memory value;
        //_auditPath = 0xef20a106246297a2d44f97e78f3f402804011ce360c224ac33b87fe8b6d7b7e618c306000000000000002000000000000000000000000000000000000000000000000000000000000382fc20114c912bcc8ae04b5f5bd386a4bddd8770ae2c3111b7537327c3a369d07179d6142f7ac9436ba4b548f9582af91ca1ef02cd2f1f03020000000000000014250e76987d838a75310c34bf422ea9f1ac4cc90606756e6c6f636b4a14cd1faff6e578fa5cac469d2418c95671ba1a62fe14e0afadad1d93704761c8550f21a53de3468ba5990008f882cc883fe55c3d18000000000000000000000000000000000000000000
        (value, off)  = ZeroCopySource.NextVarBytes(_auditPath, off);

        bytes32 hash = Utils.hashLeaf(value);
        uint size = _auditPath.length.sub(off).div(33);
        bytes32 nodeHash;
        bytes pos;
        for (uint i = 0; i < size; i++) {
            (pos, off) = ZeroCopySource.NextByte(_auditPath, off);
            (nodeHash, off) = ZeroCopySource.NextHash(_auditPath, off);
            if (pos == 0x00) {
                hash = Utils.hashChildren(nodeHash, hash);
            } else if (pos == 0x01) {
                hash = Utils.hashChildren(hash, nodeHash);
            } else {
                revert("merkleProve, NextByte for position info failed");
            }
        }
        require(hash == _root, "merkleProve, expect root is not equal actual root");
        return value;
    }
}

// Операция передачи токенов из исходной цепочки называется «блокировкой», а функция получения токенов называется «разблокировкой». 
// Poly использует систему так называемых «узлов консенсуса», которые подписывают событие «разблокировки» в целевой цепочке, включая 
// соответствующую энтропию из исходной цепочки, подтверждающую событие блокировки. Эта энтропия состоит из корня состояния, 
// отражающего заблокированные токены в исходной цепочке.


// Total Value Locked - это общая стоимость активов, заблокированных в смарт-контрактах, и является показателем популярности и 
// надежности кросс-чейн моста