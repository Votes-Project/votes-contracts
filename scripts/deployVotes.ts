import { ethers } from "hardhat";
const hre = require("hardhat");

async function main() {

  const Votes = await ethers.getContractFactory("Votes");
  const votes = await Votes.deploy();

  await votes.deployed();

  console.log(
    `Votes deployed to ${votes.address}`
  );

  await hre.run("verify:verify", {
    address: votes.address
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
