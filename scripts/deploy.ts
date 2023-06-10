const deployVotes = require("./deployVotes");
const deployAuction = require("./deployAuction");
const deployQuestions = require("./deployQuestions");

async function main() {
    const votesAddress = await deployVotes();
    await deployAuction(votesAddress);
    await deployQuestions(votesAddress);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});