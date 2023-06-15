import { ethers } from "hardhat";
import { weth, votes } from "./locations";
const hre = require("hardhat");

async function deploy(votesAddress?: string) {

  votesAddress = votesAddress || votes;

  const auctionArgs = [
    weth, // address _weth,
    votesAddress, // address _votes,
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

  // Give the Auction contract the MINTER_ROLE on the Votes token contract

  const Votes = await ethers.getContractFactory("Votes");

  const votes2 = await Votes.attach(votesAddress);

  await votes2.grantRole(ethers.utils.keccak256(ethers.utils.toUtf8Bytes('MINTER_ROLE')), auction.address);

  try {
    await hre.run("verify:verify", {
      address: auction.address,
      constructorArguments: auctionArgs
    });
  } catch (e) {
    console.error(e);
  }
  return auction.address;
}

if (require.main === module) {
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
  deploy().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = deploy;
