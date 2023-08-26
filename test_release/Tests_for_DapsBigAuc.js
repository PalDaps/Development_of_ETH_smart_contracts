
const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("Tests for DapsBigAuc", function() {

    let globalTokenAndNFTowner
    let globalAucOwner

    let createrOfAuction

    let buyer1
    let buyer2
    let buyer3

    let auc
    let dapscollection

    beforeEach(async function() {

        [globalTokenAndNFTowner, globalAucOwner, createrOfAuction ,buyer1, buyer2, buyer3] = await ethers.getSigners()

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

        await dapscollection.connect(createrOfAuction).setApprovalForAll(auc, 1)
        await dapscollection.connect(buyer1).setApprovalForAll(auc, 1)
        await dapscollection.connect(buyer2).setApprovalForAll(auc, 1)
        await dapscollection.connect(buyer3).setApprovalForAll(auc, 1)
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
        expect(totalSupply).to.eq(999999+3000)
        expect(amountOfNFTCreater).to.eq(1)
        console.log(`Daps comment: Balance of buyer1 is ${balanceBuyer1}`)
        console.log(`Daps comment: Balance of buyer2 is ${balanceBuyer1}`)
        console.log(`Daps comment: Balance of buyer3 is ${balanceBuyer1}`)
    })

    describe("Daps: tests for createAuction()", function() {

    
        it("Daps: Tests for creating an auction", async function() {

            // Создаем 2 аукциона
            const tx1 = await auc.connect(createrOfAuction).createAuction(12, 300, 3, 60)
            await dapscollection.connect(createrOfAuction).setApprovalForAll(auc, 0)
            
            await network.provider.send("evm_increaseTime", [15]);
            
            const offerTx1 = await auc.connect(buyer1).offerPrice(1, 300)
            const offerTx2 = await auc.connect(buyer2).offerPrice(1, 301)
            const offerTx3 = await auc.connect(buyer3).offerPrice(1, 302)

            await network.provider.send("evm_increaseTime", [51]);
            
            const balanceNFTofCreater = await dapscollection.connect(createrOfAuction).balanceOf(createrOfAuction, 12)
            const balanceNFTofContract = await dapscollection.connect(createrOfAuction).balanceOf(auc, 12)
            expect(balanceNFTofCreater).to.eq(0)
            expect(balanceNFTofContract).to.eq(1)

        })


    })

})