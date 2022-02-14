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

  // NFT BaseUri
  const uri = "https://bafybeic3ak32mpdg66javycderizmlkbcmvjbodftynppakatrcvsdgw6a.ipfs.dweb.link/metadata/";
  cimpleNFTContract.setBaseTokenURI(uri);
  console.log("cimpleNFTContract deployed to:", cimpleNFTContract.address);
  
  // NFT Utils 
  const NFTUtils = await hre.ethers.getContractFactory("NFTUtils");
  const NFTUtilsContract = await NFTUtils.deploy(cimpleNFTContract.address);
  await NFTUtilsContract.deployed();
  console.log("NFTUtilsContract deployed to:", NFTUtilsContract.address);


    // Vote Utils 
    const VoteUtils = await hre.ethers.getContractFactory("VoteUtils");
    const VoteUtilsContract = await VoteUtils.deploy();
    await VoteUtilsContract.deployed();
    console.log("VoteUtilsContract deployed to:", VoteUtilsContract.address);

  // We get the contract to deploy
  const CimpleDAO = await hre.ethers.getContractFactory("CimpleDAO");
  const cimpledao = await CimpleDAO.deploy(NFTUtilsContract.address,VoteUtilsContract.address);

  await cimpledao.deployed();

  console.log("CimpleDao deployed to:", cimpledao.address);
  await NFTUtilsContract.changeOwner(cimpledao.address);
  await VoteUtilsContract.changeOwner(cimpledao.address);
  const metaaddress = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266';
  const price = 8000000000000000;
  await cimpleNFTContract.mintTo(metaaddress, {value : price.toString()});
  await cimpleNFTContract.mintTo('0x71be63f3384f5fb98995898a86b02fb2426c5788', {value : price.toString()});
  await cimpleNFTContract.mintTo('0xfabb0ac9d68b0b445fb7357272ff202c5651694a', {value : price.toString()});
  // console.log(response.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
