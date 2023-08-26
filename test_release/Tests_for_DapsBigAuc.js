
const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("DapsBigAuc", function() {

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

        const DapsCollection = await ethers.getContractFactory("DapsCollection", globalTokenAndNFTowner)
        dapscollection = await DapsCollection.deploy()
        await dapscollection.deploymentTransaction()

        // Теперь разворачиваем аукцион с токенами

        const Auc = await ethers.getContractFactory("AuctionEngine", globalAucOwner)
        auc = await Auc.deploy(dapscollection.address)
        await auc.deploymentTransaction()

        // Создаем токены и NFT
        let idNFT = 12
        let idToken = 3
        await dapsCollection.connect(owner).createToken("TokenName", "TKN", 3, 999999);
        await dapsCollection.connect(owner).createNFT(createrOfAuction.address, "KirkaBoga", 12);
        // test
    })

})