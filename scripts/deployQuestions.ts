import { ethers } from "hardhat";
import { votes } from "./locations";

const hre = require("hardhat");

async function deploy(votesAddress?: string) {

  const questionsArgs = [
    votesAddress || votes // address _votesAddress
  ] as const;

  const Questions = await ethers.getContractFactory("Questions");
  const questions = await Questions.deploy(...questionsArgs);
  await questions.deployed();

  console.log(
    `Questions deployed to ${questions.address}`
  );

  try {
    await hre.run("verify:verify", {
      address: questions.address,
      constructorArguments: questionsArgs
    });
  } catch (e) {
    console.error(e);
  }

  return questions.address;
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
