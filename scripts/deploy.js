// scripts/deploy.js
require("dotenv").config();
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const Factory = await ethers.getContractFactory("FortuneWheel");
  const wheel = await Factory.deploy(
    ethers.utils.parseEther("0.001"), // spin cost in ETH
    5                                // house fee %
  );
  await wheel.deployed();
  console.log("FortuneWheel deployed to:", wheel.address);
}

main().catch(e => {
  console.error(e);
  process.exit(1);
});
