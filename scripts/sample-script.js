// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const CimpleNFT = await hre.ethers.getContractFactory("NFT");
  const cimpleNFTContract = await CimpleNFT.deploy();
  await cimpleNFTContract.deployed();


  // We get the contract to deploy
  const CimpleDAO = await hre.ethers.getContractFactory("CimpleDAO");
  const nftaddress = cimpleNFTContract.address;
  const cimpledao = await CimpleDAO.deploy(nftaddress);

  await cimpledao.deployed();

  console.log("CimpleDao deployed to:", cimpledao.address);
  const metaaddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
  const response = await cimpledao.testnftmint(metaaddress,8000000000000000);
  console.log(response.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
