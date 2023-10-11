import { ethers } from "hardhat";

async function main() {
  const ralphTickets = await ethers.deployContract("RalphTickets", ["0x487c738529bcda310af158264de0ebda332e7532"]);

  await ralphTickets.waitForDeployment();

  console.log(
    `Contract deployed to ${ralphTickets.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
