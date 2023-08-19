// для тестирования npx hardhat test без таблицы
// запустить тест с coverage npx hardhat coverage
// E - мы не преверям момент когда транзакция откачивается

// Вытаскиваем специальную функцию expect с помощью который мы будем ставить ожидания
const { expect } = require("chai")

// ethers нужен, чтобы работать с блокчейном из вне
const { ethers } = require("hardhat")

// Далее описываем наш движок
// Descibe нужен для того, чтобы группировать тесты по какому-то признаку
describe("Auction", function() {
    
    // Задаем три аккаунта
    // Владелец
    let owner
    // Продавец
    let seller
    // Покупатель
    let buyer

    let auct;

    // Вытаскиваем эти три аккунта из тестовой среды
    beforeEach(async function() {
        
        // То есть первым трем переменным присваиваем состояния трем первым аккаунтам из тестовой среды
        [owner, seller, buyer] = await ethers.getSigners()

        // Разворачиваем наш смарт-контракт аукциона с помощью ethers в тестовой среде
        const Auction = await ethers.getContractFactory("AuctionEngine", owner)

        // Ждем пока этот контракт будет развернут
        auct = await Auction.deploy()
        await auct.deploymentTransaction()
    })

    // Тут уже можно начинать тестировать sc

    // Смотрим, что после развертывания sc был установлен конкретный владелец
    // it описывает конкретный тест или пример. Грубо говоря, тестируем какой-то конкретный кусочек sc
    it("Daps: sets owner", async function(){

        // Записываем в переменную owner sc
        const currentOwner = await auct.owner()

        // Выводим это все в консоль
        console.log(currentOwner)

        // А так по факту мы ожидаем, что currentOwner будет равен owner
        expect(currentOwner).to.eq(owner.address)
    })

    // Тут мы проверям правильное ли значет будет у поля endsAt
    
    async function getTimestamp(blockNumber) {
        return (

            // с помощью провайдера подключаемся к конкретному блокчейну
            // и с помощью getBlock() получаем информацию по блоку
            await ethers.provider.getBlock(blockNumber)
        ).timestamp

        // Используем timestamp, что получить время блока, который был связан с createAuction()
    }

    // Делаем еще один describe для проверки функции createAuction
    describe("createAuction", function() {
        it("Daps: createAuction true", async function(){

            const amountInEther = 1000000000000000;
            // const amountInWei = ethers.utils.parseEther(amountInEther);

            // Создаем транзакцию и в этой транзакции мы будем делать создание Auction
            const tx = await auct.createAuction(

                // Утилита, которая принимает эфир и правильно его конвертирует в wei
                // ethers.utils.parseUnits("0.0001", 4), 
                // ethers.utils.parseEther("0.0001")
                
                amountInEther,

                // cбрасываем 3 вей в секунду

                3,

                "Daps NFT",

                60
            )

            // Окей, когда этот аукцион был создан, теперь нам надо вытащить информацию о текущим аукционе из блокчейна 
            const cAuction = await auct.auctions(0)
            console.log(cAuction)
            expect(cAuction.item).to.eq("Daps NFT")
            
            // Можно вывести в лог вообще всю транзакцию и посмотреть, что доступно
            console.log(tx)

            // Тут нужно передать правильный номер блока для транзакции, которая осуществляется createAuction()
            const ts = await getTimestamp(tx.blockNumber)

            // Теперь необходимо проверить, что аукцион имеет правильную дату конца
            expect(cAuction.endsAt).to.eq(ts + 60)
        })

    })

    // Опищим функцию, которая позволит нам ждать в тесте определенное время
    function delay(ms) {

        // Ахуеть это танцы с бубнами
        return new Promise(resolve => setTimeout(resolve, ms))
    }

    describe("Daps: buy", function(){
        it("Daps: function buy(uint index) external payable | testing", async function(){

            const amountInEther = 1000000000000000;
            // Непосредственно разворачиваем саму транзакцию createAuction()
            await auct.connect(seller).createAuction(amountInEther, 3, "Daps NFT", 60)

            // с помощью фреймворка Mocha можно увеличть время выполнения тетса
            this.timeout(5000) // увеличваем до 5 секунд
            // Если будет больше 5 секунд, То будет ошибка и тест вылетит

            await delay(1000) // ждем одну секунду
            const amount = 1000000000000000;
            // Создаем переменную, которая будет представлять транзакцию покупки
            // И так как мы хотим выполнить транзакцию от имени другого аккаунта, то используем поле connect
            // В buy() передаем индекс нужного аукциона
            // Для того, чтобы пристыковать к транзакции какие-то деньги, то используем тако синтаксик
            // { value: amount }
            const buyTx = await auct.connect(buyer).buy(0, { value: amount })

            // Так. В анонимную функцию мы передаем нашу транзакцию
            // А потом используем проверку to.changeEtherBalance
            // С помощью Waffle
            // Запуск конкретной транзакции меняет какое-то количество эфира на определенном счету
            // А именно нужно проверить как изменился баланс seller
            // Сколько денег на счету у продавца должно оказаться после того как купили вот этот товар buyTx
            // Для этого нужно понять за сколько этот товар вообще ушел
            // А так как мы купили товар за amount от аккаунта buyer, то выставляется финальная цена, которую мы можем взять
            const cAuction = await auct.auctions(0)
            const finalPrice = cAuction.finalPrice
            // Math.floor используем для того, чтобы значени было такое как в solidity коде
            // const tenB = BigInt(10)
            // const hundredB = BigInt(100)
            // const secondB = (finalPrice*tenB)/hundredB
            // const secondN = Number(secondB)
            // const second = Math.floor(secondN)
            // const cast = BigINt(second)
            // Задрало уже
            // await expect(() => buyTx).to.changeEtherBalance(seller, finalPrice - secondB)

            // Ловим события с помощью javaSCRIPT
            // По идее ethers делает обращение к журналу событий их как-то выводит??
            const animeGachist = await expect(buyTx)
                .to.emit(auct, 'AuctionEnded')
                .withArgs(0, finalPrice, buyer.address);
            console.log(animeGachist)

            // Еще одна проверка и waffle.js
            // После того как покупка совершилась и аукцион остановился, то запрещается покупать еще один товар
            await expect(

                // Делаем еще раз тразакцию с покупкой, то есть вызываем функцию buy от аккаунта баера
                auct.connect(buyer).buy(0, { value: amount })

            ).to.be.revertedWith('Daps: This Auc was stopped!');

            // А вот здесь to.be.revertedWith мы говорим, что транзакция buy будет откачана с сообщением 'Daps: This Auc was stopped!'
            
        })
    })

})

