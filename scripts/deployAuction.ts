import { ethers } from "hardhat";
const hre = require("hardhat");

async function main() {

  const auctionArgs = [
    '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', // address _weth,
    '0xCFB2F0Bd9B3d87C0F2D43CdccbB43b5323d70F70', // address _votes,
    '0xa98f5FE3645aE950AB92f12E3b4322bA96DC5a22', // address _treasury,
    300, // uint256 _duration,
    10000000000000, // uint256 _reservePrice,
    'ipfs://QmPMc4tcBsMqLRuCQtPmPe84bpSjrC3Ky7t3JWuHXYB4aS/0',// string memory _votesURI,
    'ipfs://QmPMc4tcBsMqLRuCQtPmPe84bpSjrC3Ky7t3JWuHXYB4aS/1' // string memory _flashVotesURI
  ] as const;

  const Auction = await ethers.getContractFactory("Auction");
  const auction = await Auction.deploy(...auctionArgs);
  await auction.deployed();

  console.log(
      `Auction deployed to ${auction.address}`
  );

  await hre.run("verify:verify", {
    address: auction.address,
    constructorArguments: auctionArgs
  });

}

if (require.main === module) {
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = main;
