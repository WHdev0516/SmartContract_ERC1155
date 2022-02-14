// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721, PullPayment, Ownable {
    using Counters for Counters.Counter;

    // Constants. Define total supply.
    uint256 public constant TOTAL_SUPPLY =10_000;


    // The mint user info structure
    struct MintUserDetail {
        address mintuser;
        uint256 currentminttimestamp;
        uint256 price_value;
        uint256 tokenID;
    }

    MintUserDetail[]  public  mintuserlist;

    // Constants. Define MINT price.
    uint256 public constant MINT_PRICE = 0.008 ether;

    Counters.Counter private currentTokenId;

    // @dev bse token URI used as a prefix by tokenURI()
    string public baseTokenURI;
    
    constructor() ERC721("CiMPLE", "NFT") {
        baseTokenURI = "";
    }
    
    function mintTo(address recipient) public payable returns (uint256)
    {
        uint256 tokenId =  currentTokenId.current();
        require(tokenId < TOTAL_SUPPLY, "Max supply reached");
        require(msg.value == MINT_PRICE, "Transaction value did not equal the mint price");

        currentTokenId.increment();
        uint256 newItemId = currentTokenId.current();
        _safeMint(recipient, newItemId);
        mintuserlist.push(MintUserDetail(recipient, block.timestamp, msg.value, newItemId));
        return newItemId;
    }

    // @dev Returns an URI for a given token ID
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    // @dev Return mint address list
    function getmintaddress() external view returns (address[] memory, uint256[] memory, uint256[] memory, uint256[] memory) {
        address[] memory tempuserlist =  new address[](currentTokenId.current());
        uint256[] memory temptime =  new uint256[](currentTokenId.current());
        uint256[] memory tempprice =  new uint256[](currentTokenId.current());
        uint256[] memory tokenIDs =  new uint256[](currentTokenId.current());
        for (uint i = 0; i < currentTokenId.current(); i++) {
            tempuserlist[i] = (mintuserlist[i].mintuser);
            temptime[i] = (mintuserlist[i].currentminttimestamp);
            tempprice[i] = (mintuserlist[i].price_value);
            tokenIDs[i] = (mintuserlist[i].tokenID);
        }
        return (tempuserlist,temptime,tempprice, tokenIDs);
    }

    // @dev Sets the base token URI prefix
    function setBaseTokenURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    // @dev Overridden in order to make it an onlyOwner function
    function withdrawPayments(address payable payee) public override onlyOwner virtual {
        super.withdrawPayments(payee);
    }

}