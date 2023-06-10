import { ethers } from "hardhat";
const hre = require("hardhat");

async function deploy() {

  const Votes = await ethers.getContractFactory("Votes");
  const votes = await Votes.deploy();

  await votes.deployed();

  console.log(
    `Votes deployed to ${votes.address}`
  );

  try {
    await hre.run("verify:verify", {
      address: votes.address
    });
  }
  catch (e) {
    console.error(e);
  }

  return votes.address;
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
