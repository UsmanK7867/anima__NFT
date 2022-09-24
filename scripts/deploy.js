const { ethers } = require("hardhat");

async function main() {
  const instance = await ethers.getContractFactory("AnimaNFT");
  const contract = await instance.deploy(
    ["USDT"],
    ["0x5FbDB2315678afecb367f032d93F642f64180aa3"]
  );
  await contract.deployed();
  console.log(contract);
  console.log("token contract deployed to:", contract.address);

  // await contract.togglePublicSale();
}

main();
