import { ethers } from "hardhat";

async function main() {
  const ralphTickets = await ethers.deployContract("RalphTickets", ["0xB2eadDC5A2EeBBb71e89B70d97ce4f441a4DEf12"]);

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
