// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AuctionEngine {

    // Владец площадки, которая предоставляет аукцион
    address public owner;

    // Дефолтное значение, которое говорит о том, сколько будет длится аукцион
    uint constant DURATION = 2 days;

    // Сколько берет себя в процент владелец площадки
    uint constant FEE = 10;

    struct Auction {
        
        // Человек, который продает что-то
        address payable seller;

        // Изначальная цена
        uint startingPrice;

        // Финальная цена За сколько конкретный товар ушел
        uint finalPrice;

        // Когда начинаем аукцион
        uint startAt;

        // Когда заканчиваем аукцион
        uint endsAt;

        // Сколько будем сбрасывать за секунду от цены
        uint discountRate;

        // То, что мы продаем 
        string item;

        // Информация о том закончился ли аукцион или нет
        bool stopped;
    }

    // Динамический массив аукционов для хранения данных
    Auction[] public auctions;

    event AuctionCreated(uint index, string itemName, uint startingPrice, uint duration);

    event AuctionEnded(uint index, uint finalPrice, address winner);

    constructor() {
        owner = msg.sender;
    }

    // Функция для создания аукционов
    function createAuction(uint _startingPrice, uint _discountRate, string calldata _item, uint _duration) external {

        // Проверяем значения _duration
        uint duration = _duration == 0 ? DURATION : _duration;

        // Проверям, что _startingPrice имеет корректное значение. То есть не уходит ли она в минус при определенном
        // _discountRate и _duration
        require(_startingPrice >= _discountRate * duration, "Daps: Incorrect starting price");

        Auction memory newAuction = Auction({
            seller: payable(msg.sender),
            startingPrice: _startingPrice,
            finalPrice: _startingPrice,
            discountRate: _discountRate,
            
            // Значение когда мы начинаем аукцион
            startAt: block.timestamp,
            endsAt: block.timestamp + duration,
            item: _item,
            stopped: false
        });

        auctions.push(newAuction);

        emit AuctionCreated(auctions.length - 1, _item, _startingPrice, duration);
    }

    // Функция, которая позволяет брать цену на текущий момент времени
    function getPriceFor(uint index) public view returns(uint) {
        
        // Используем мемори, потому что нужно только считать данные, а менять там ничего не нужно
        Auction memory cAuction = auctions[index];

        // Аукцион не должен быть остановлен
        require(!cAuction.stopped, "Daps: This Auc was stopped!");

        // Сколько прошло времени с начала аукциона
        uint elapsed = block.timestamp - cAuction.startAt;

        // Сколько нам нужно скинуть относительно пройденного времени
        // Чем больше прошло времени, тем больше будет скидка
        uint discount = cAuction.discountRate * elapsed;

        return cAuction.startingPrice - discount;
    }

    // Функция, которая позволит нам что-либо купить
    function buy(uint index) external payable {
        
        Auction memory cAuction = auctions[index];

        require(!cAuction.stopped, "Daps: This Auc was stopped!");

        // Что время конца еще не подошло
        require(block.timestamp < cAuction.endsAt, "Daps: This Auc was ended!!!");

        // Какая сейчас цена на товар, который хочет купить этот человек
        uint cPrice = getPriceFor(index);

        // Проверяем прислали ли нам достаточно денег или нет
        require(msg.value >= cPrice, "Daps: not enough money");

        // Если все в порядке значит мы нашли покупателя и останавливаем акуцион
        cAuction.stopped = true;

        // Следовательно фиксируем финальную цену этого аукциона
        cAuction.finalPrice = cPrice;

        // И когда идет эта транзакция, то цена упадет за несколько секунда еще какое-то значение
        // которое мы вернем нашем покупателю
        uint refund = msg.value - cPrice;

        // Если рефанд больше нуля, то возвращаем эту сумму msg.sender
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        // Сейчас непосредственно продавцу нужно перевести цену, котоую хочет отправить msg.sender
        // Но за исключением, что FEE процентов пойдет на адресс владельца аукциона
        cAuction.seller.transfer(cPrice - ((cPrice * FEE)/100));

        emit AuctionEnded(index, cPrice, msg.sender);
    }
}