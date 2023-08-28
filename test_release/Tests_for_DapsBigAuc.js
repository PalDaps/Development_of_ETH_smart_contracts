
const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("Tests for DapsBigAuc", function() {

    let globalTokenAndNFTowner
    let globalAucOwner

    let createrOfAuction

    let buyer1
    let buyer2
    let buyer3
    let buyer4
    let buyer5

    let auc
    let dapscollection

    beforeEach(async function() {

        [globalTokenAndNFTowner, globalAucOwner, createrOfAuction ,buyer1, buyer2, buyer3, buyer4, buyer5] = await ethers.getSigners()

        // Развернем для начала Токены и NFT

        const tokensAndNFT = await ethers.getContractFactory("DapsCollection", globalTokenAndNFTowner)
        dapscollection = await tokensAndNFT.deploy()
        await dapscollection.deploymentTransaction()
        
        // console.log(dapscollection)
        // await dapscollection.deployed()
        // Теперь разворачиваем аукцион с токенами

        const Auction = await ethers.getContractFactory("AuctionEngine", globalAucOwner)
        auc = await Auction.deploy(dapscollection)
        await auc.deploymentTransaction()
        // await auc.deployed()
    
        // Создаем токены и NFT
        let idNFT = 12
        let idToken = 3
        await dapscollection.connect(globalTokenAndNFTowner).createToken("TokenName", "TKN", 3, 999999);
        await dapscollection.connect(globalTokenAndNFTowner).createNFT(createrOfAuction.address, "KirkaBoga", 12);

        await dapscollection.connect(globalTokenAndNFTowner).mint(buyer1, 3, 1000, "0x")
        await dapscollection.connect(globalTokenAndNFTowner).mint(buyer2, 3, 1000, "0x")
        await dapscollection.connect(globalTokenAndNFTowner).mint(buyer3, 3, 1000, "0x")
        await dapscollection.connect(globalTokenAndNFTowner).mint(buyer4, 3, 1000, "0x")

        await dapscollection.connect(createrOfAuction).setApprovalForAll(auc, 1)
        await dapscollection.connect(buyer1).setApprovalForAll(auc, 1)
        await dapscollection.connect(buyer2).setApprovalForAll(auc, 1)
        await dapscollection.connect(buyer3).setApprovalForAll(auc, 1)
        await dapscollection.connect(buyer4).setApprovalForAll(auc, 1)
        await dapscollection.connect(buyer5).setApprovalForAll(auc, 1)

        // await dapscollection.connect(buyer3).mint(buyer3, 3, 1000, "0x")
        // console.log(globalTokenAndNFTowner)
    })

    it("Daps: Tests for the correct creation of tokens and NFT", async function() {

        // Достаем totalSupply из контракта
        const totalSupply = await dapscollection.totalSupply(3)
        const amountOfNFTCreater = await dapscollection.connect(createrOfAuction).balanceOf(createrOfAuction, 12)
        const balanceBuyer1 = await dapscollection.connect(createrOfAuction).balanceOf(buyer1, 3)
        const balanceBuyer2 = await dapscollection.connect(createrOfAuction).balanceOf(buyer2, 3)
        const balanceBuyer3 = await dapscollection.connect(createrOfAuction).balanceOf(buyer3, 3)
        expect(totalSupply).to.eq(999999+4000)
        expect(amountOfNFTCreater).to.eq(1)
        console.log(`Daps comment: Balance of buyer1 is ${balanceBuyer1}`)
        console.log(`Daps comment: Balance of buyer2 is ${balanceBuyer1}`)
        console.log(`Daps comment: Balance of buyer3 is ${balanceBuyer1}`)
    })

    describe("Daps: tests for createAuction()", function() {
    
        it("Daps: Test for default creating an auction", async function() {

            // Создаем 1 аукцион
            // И три покупателя соревнуются
            // смотрим их балансы
            const tx1 = await auc.connect(createrOfAuction).createAuction(12, 300, 3, 60)
            await dapscollection.connect(createrOfAuction).setApprovalForAll(auc, 0)
            
            await network.provider.send("evm_increaseTime", [15]);
            
            const offerTx1 = await auc.connect(buyer1).offerPrice(1, 300)
            const offerTx2 = await auc.connect(buyer2).offerPrice(1, 301)
            const offerTx3 = await auc.connect(buyer3).offerPrice(1, 302)

            let balanceBuyer1 = await dapscollection.connect(createrOfAuction).balanceOf(buyer1, 3)
            let balanceBuyer2 = await dapscollection.connect(createrOfAuction).balanceOf(buyer2, 3)
            let balanceBuyer3 = await dapscollection.connect(createrOfAuction).balanceOf(buyer3, 3)
            let balanceNFTofCreater = await dapscollection.connect(createrOfAuction).balanceOf(createrOfAuction, 12)
            let balanceNFTofContract = await dapscollection.connect(createrOfAuction).balanceOf(auc, 12)

            expect(balanceBuyer1).to.eq(1000 - 300)
            expect(balanceBuyer2).to.eq(1000 - 301)
            expect(balanceBuyer3).to.eq(1000 - 302)
            expect(balanceNFTofCreater).to.eq(0)
            expect(balanceNFTofContract).to.eq(1)

            await network.provider.send("evm_increaseTime", [51]);
            


            await auc.connect(buyer1).setWinnerInAuction(1)
            await auc.connect(buyer1).takeMoneyFromAuc(1, 300)
            await auc.connect(buyer2).takeMoneyFromAuc(1, 301)
            await auc.connect(buyer3).getNFTtoWinner(1)
            await auc.connect(createrOfAuction).getTokenToOwnerAuc(1)

            balanceBuyer1 = await dapscollection.connect(createrOfAuction).balanceOf(buyer1, 3)
            balanceBuyer2 = await dapscollection.connect(createrOfAuction).balanceOf(buyer2, 3)
            balanceBuyer3 = await dapscollection.connect(createrOfAuction).balanceOf(buyer3, 12)
            balanceNFTofCreater = await dapscollection.connect(createrOfAuction).balanceOf(createrOfAuction, 12)
            balanceNFTofContract = await dapscollection.connect(createrOfAuction).balanceOf(auc, 12)

            expect(balanceBuyer1).to.eq(1000)
            expect(balanceBuyer2).to.eq(1000)
            expect(balanceBuyer3).to.eq(1)
            expect(balanceNFTofCreater).to.eq(0)
            expect(balanceNFTofContract).to.eq(0)

        })

        it("Daps: test for creating a second auction when there is no NFT", async function() {

            const tx1 = await auc.connect(createrOfAuction).createAuction(12, 300, 3, 60) 

            await expect(auc.connect(createrOfAuction).createAuction(12, 300, 3, 60)).to.be.reverted
        })

        it("Daps: test for multiple insertion from one person", async function() {

            const tx1 = await auc.connect(createrOfAuction).createAuction(12, 100, 3, 60)
            await dapscollection.connect(createrOfAuction).setApprovalForAll(auc, 0)

            await network.provider.send("evm_increaseTime", [15]);

            const offerTx1 = await auc.connect(buyer1).offerPrice(1, 1000)
            const offerTx2 = await auc.connect(buyer2).offerPrice(1, 200)
            await expect(auc.connect(buyer2).offerPrice(1, 100)).to.be.reverted
            await expect(auc.connect(buyer2).takeMoneyFromAuc(1, 250)).to.be.reverted
            await auc.connect(buyer2).takeMoneyFromAuc(1, 200)
            // await expect(auc.connect(buyer2).takeMoneyFromAuc(1, 100)).to.be.reverted
            await network.provider.send("evm_increaseTime", [45]);

            let balanceTokenOnContract = await dapscollection.connect(createrOfAuction).balanceOf(auc, 3)
            let balanceNFTonContract = await dapscollection.connect(createrOfAuction).balanceOf(auc, 12)

            expect(balanceTokenOnContract).to.eq(1000)
            expect(balanceNFTonContract).to.eq(1)

            await auc.connect(buyer3).setWinnerInAuction(1)

            await auc.connect(createrOfAuction).getTokenToOwnerAuc(1)

            let balanceTokenCreaterOfAuction = await dapscollection.connect(createrOfAuction).balanceOf(createrOfAuction, 3)
            let balanceNFTCreaterOfAuction = await dapscollection.connect(createrOfAuction).balanceOf(createrOfAuction, 12)

            expect(balanceTokenCreaterOfAuction).to.eq(1000)
            expect(balanceNFTCreaterOfAuction).to.eq(0)

            await auc.connect(buyer1).getNFTtoWinner(1)

            let balanceNFTbuyer1 = await dapscollection.connect(buyer3).balanceOf(buyer1, 12)

            expect(balanceNFTbuyer1).to.eq(1)

        })


        it("Daps : test two parallel auctions from one person", async function(){

            let bFirstNFTContract = await dapscollection.connect(buyer1).balanceOf(auc, 12)
            let bSecondNFTContract = await dapscollection.connect(buyer1).balanceOf(auc, 13)
            let bTokenContract = await dapscollection.connect(buyer1).balanceOf(auc, 3)

            let bTokenBuyer1 = await dapscollection.connect(buyer1).balanceOf(buyer1, 3)
            let bTokenBuyer2 = await dapscollection.connect(buyer2).balanceOf(buyer2, 3)
            let bTokenBuyer3 = await dapscollection.connect(buyer3).balanceOf(buyer3, 3)
            let bTokenBuyer4 = await dapscollection.connect(buyer4).balanceOf(buyer4, 3)

            let bNFTfirstBuyer1 = await dapscollection.connect(buyer1).balanceOf(buyer1, 12)
            let bNFTfirstBuyer2 = await dapscollection.connect(buyer2).balanceOf(buyer2, 12)
            let bNFTSecondBuyer3 = await dapscollection.connect(buyer3).balanceOf(buyer3, 13)
            let bNFTSecondBuyer4 = await dapscollection.connect(buyer4).balanceOf(buyer4, 13)

            await dapscollection.connect(globalTokenAndNFTowner).mint(createrOfAuction, 13, 1, "0x")

            await auc.connect(createrOfAuction).createAuction(12, 400, 3, 60)
            await auc.connect(createrOfAuction).createAuction(13, 300, 3, 60)
            await expect(auc.connect(buyer5).createAuction(13, 300, 3, 60)).to.be.reverted
            await dapscollection.connect(globalTokenAndNFTowner).mint(buyer5, 13, 1, "0x")
            await expect(auc.connect(buyer5).createAuction(14, 300, 3, 60)).to.be.reverted
            await expect(auc.connect(buyer5).createAuction(13, 300, 2, 60)).to.be.reverted

            await network.provider.send("evm_increaseTime", [15]);

            bFirstNFTContract = await dapscollection.connect(buyer1).balanceOf(auc, 12)
            bSecondNFTContract = await dapscollection.connect(buyer1).balanceOf(auc, 13)
            
            expect(bFirstNFTContract).to.eq(1)
            expect(bSecondNFTContract).to.eq(1)

            await auc.connect(buyer1).offerPrice(1, 440)
            await auc.connect(buyer2).offerPrice(1, 490)

            await auc.connect(buyer1).offerPrice(2, 440)
            await auc.connect(buyer2).offerPrice(2, 490)
            await auc.connect(buyer3).offerPrice(2, 510)
            await auc.connect(buyer4).offerPrice(2, 560)
            await expect(auc.connect(buyer5).offerPrice(2, 560)).to.be.reverted

            bTokenContract = await dapscollection.connect(buyer1).balanceOf(auc, 3)

            expect(bTokenContract).to.eq(2000+490+440)

            await network.provider.send("evm_increaseTime", [50]);

            await auc.connect(buyer3).setWinnerInAuction(1)
            await auc.connect(buyer3).setWinnerInAuction(2)

            await auc.connect(createrOfAuction).getTokenToOwnerAuc(1)
            await auc.connect(createrOfAuction).getTokenToOwnerAuc(2)

            bTokenContract = await dapscollection.connect(buyer1).balanceOf(auc, 3)

            expect(bTokenContract).to.eq(440+440+490+510)

            await expect(auc.connect(buyer4).getNFTtoWinner(1)).to.be.reverted
            await expect(auc.connect(buyer2).getNFTtoWinner(2)).to.be.reverted

            await auc.connect(buyer4).getNFTtoWinner(2)
            await auc.connect(buyer2).getNFTtoWinner(1)

            bFirstNFTContract = await dapscollection.connect(buyer1).balanceOf(auc, 12)
            bSecondNFTContract = await dapscollection.connect(buyer1).balanceOf(auc, 13)
            
            expect(bFirstNFTContract).to.eq(0)
            expect(bSecondNFTContract).to.eq(0)

            bNFTfirstBuyer2 = await dapscollection.connect(buyer2).balanceOf(buyer2, 12)
            bNFTSecondBuyer4 = await dapscollection.connect(buyer4).balanceOf(buyer4, 13)

            expect(bNFTfirstBuyer2).to.eq(1)
            expect(bNFTSecondBuyer4).to.eq(1)
        })


    })

})