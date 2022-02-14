// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface CiMPLENFT {
    function getmintaddress() external view returns (address[] memory, uint256[] memory, uint256[] memory, uint256[] memory);
}
contract NFTUtils {
    address private CiMPLENFTaddress; 
    address private owner;
    // NFT 
    uint256 private constant oneDayTimeStamp = 864 * 1e2; // timestamp per day
    uint256 private constant oneYearTimeStamp = 3154 * 1e4; // timestamp per year

    struct NFTUserDetail {
        address userAddress;
        uint256 tokenID;
        uint256 actionTimestamp;
    }
    NFTUserDetail[] private nftUsersInfo;

    mapping(uint256 => bool) private nftAwardList;
    uint256 private nftAwardListCount;
    
    constructor(address nftaddress) {
        CiMPLENFTaddress = nftaddress;
        owner = msg.sender;
    }

    function changeOwner(address _newOwner) public {
        require(msg.sender == owner, 'failed');
        owner = _newOwner;
    }

    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }
    function getCiMPLENFTaddress() external view returns(address) {
        return CiMPLENFTaddress;
    }

    function getNftAwardList(uint256 _tokenID) external view returns(bool) {
        return nftAwardList[_tokenID];
    }
    function setNftAwardList(uint256 _tokenID, bool _flag) external payable isOwner {
        nftAwardList[_tokenID] = _flag;
    }
    

    function increaseNftAwardListCount() external payable isOwner {
        nftAwardListCount++;
    }
    // NFT Streaming functions
    function isNftUser(address _address, uint256 _tokenID) public view returns(bool, uint256) {
        for (uint256 s = 0; s < nftUsersInfo.length; s += 1){
           if ((_address == nftUsersInfo[s].userAddress) && (_tokenID == nftUsersInfo[s].tokenID)) return (true, s);
        }
        return (false, 0);
    }

    function getNFTUsersInfo() external view returns (address[] memory, uint256[] memory, uint256[] memory) {
        uint256 usersCount = nftUsersInfo.length;
        address[] memory users = new address[](usersCount);
        uint256[] memory tokenIDs = new uint256[](usersCount);
        uint256[] memory actionTimestamps = new uint256[](usersCount);
        for (uint i = 0; i < usersCount; i++) {
            users[i] = (nftUsersInfo[i].userAddress);
            tokenIDs[i] = (nftUsersInfo[i].tokenID);
            actionTimestamps[i] = (nftUsersInfo[i].actionTimestamp);
        }
        return (users,tokenIDs, actionTimestamps);
    }
    function getNFTUsersInfoByIndex(uint256 _index) external view returns (address, uint256, uint256) {
        return (nftUsersInfo[_index].userAddress, nftUsersInfo[_index].tokenID, nftUsersInfo[_index].actionTimestamp);
    }
    function setNFTUsersInfoByIndex(uint256 _index, uint256 _timestamp) external isOwner {
        nftUsersInfo[_index].actionTimestamp = _timestamp;
    }

    function addNFTUsersInfo(address _userAddress, uint256 _tokenID, uint256 _timestamp) public payable isOwner returns(bool) {
        (bool _isNftUser, ) = isNftUser(_userAddress, _tokenID);
        if(!_isNftUser) nftUsersInfo.push(NFTUserDetail(_userAddress, _tokenID, _timestamp));
        // emit AddNFTUsersInfo(_userAddress, _tokenID, block.timestamp);
        return true;
    }

    function removeNFTUsersInfo(address _userAddress, uint256 _tokenID) private returns(bool) {
        (bool _isNftUser, uint256 s) = isNftUser(_userAddress, _tokenID);
        if(_isNftUser){
            nftUsersInfo[s] = nftUsersInfo[nftUsersInfo.length - 1];
            nftUsersInfo.pop();
        }
        return true;
    }

    function _countOfNFTForAddress(address _address) internal view returns(uint256) {
        uint256 count = 0;
        (address[] memory users, , ,) = CiMPLENFT(CiMPLENFTaddress).getmintaddress();
        for (uint256 s = 0; s < users.length; s += 1){
            if (_address == users[s]) {
                count++;
            } 
        }
        return count;
    }

    function isAvailableFirstRewardForNFT(uint256 _tokenID) public view returns(bool) {
        bool _flag = nftAwardList[_tokenID];
        return !_flag;
    }
    
    function filterNftDetail(address _address) public view returns(uint256[] memory, uint256[] memory, uint256[] memory ) {
        uint256 count = _countOfNFTForAddress(_address);
        uint256[] memory ids = new uint256[](count); 
        uint256[] memory prices = new uint256[](count);
        uint256[] memory timestamps = new uint256[](count);
        (address[] memory users, uint256[] memory _timestamps, uint256[] memory _prices, uint256[] memory nftTokenIDs) = CiMPLENFT(CiMPLENFTaddress).getmintaddress();
        uint256 tempIndex = 0;
        for (uint256 s = 0; s < users.length; s += 1){
            if (_address == users[s]) {
                ids[tempIndex] = nftTokenIDs[s];
                prices[tempIndex] = _prices[s];
                timestamps[tempIndex] = _timestamps[s];
                tempIndex++;
            } 
        }
        return (ids, prices, timestamps);
    }
    // streaming cimple in return buying NFT
    function _isPossibleStreamingForNFT(address _userAddress, uint256 _tokenID, uint256 _timestamp) public view returns(bool, uint256, uint256) {
        (uint256[] memory _tokenIDs, uint256[] memory _prices, uint256[] memory _timestamps) = filterNftDetail(_userAddress);
        bool _flag = false;
        uint256 _nftPrice = 0;
        uint256 _mintTimestamp = 0;
        for (uint256 index = 0; index < _tokenIDs.length; index++) {
            if(_tokenID == _tokenIDs[index]) {
                _mintTimestamp = _timestamps[index];
                if(_timestamp - _mintTimestamp > oneYearTimeStamp) {
                    _nftPrice = _prices[index];
                    _flag = true;
                }
            }
        }
        return (_flag, _nftPrice, _mintTimestamp);
    }

    function calculateStreamingRateForNFT(address _userAddress, uint256 _tokenID, uint256 _timestamp, uint256 _cimpleIR) public view returns (uint256, uint256) {
        (bool _isPossibleForStreaming, uint256 _nftPrice, uint256 _mintedTimestamp) = _isPossibleStreamingForNFT(_userAddress, _tokenID, _timestamp);
        uint256 _rate = 0;
        if(_isPossibleForStreaming) {
            _rate = _nftPrice/_cimpleIR / 365;
        }
        return (_rate, _mintedTimestamp);
    }

    function isAvailableClaimRewardStreamingForNFT(address _address, uint256 _tokenID, uint256 _timestamp) public view returns(bool) {
        (bool _flag, , uint256 _mintTimestamp) = _isPossibleStreamingForNFT(_address, _tokenID, _timestamp);
        if(_flag) {
            (bool _isNftUser, uint256 s) = isNftUser(_address, _tokenID);
            if(!_isNftUser) return true;
            uint256 _currentTimeStamp = _timestamp;
            uint256 _periodTimeStamp =0;
            if(_isNftUser) _periodTimeStamp = _currentTimeStamp - nftUsersInfo[s].actionTimestamp;
            else _periodTimeStamp = _currentTimeStamp - _mintTimestamp;
            
            uint256 _usedDayCount = (_periodTimeStamp / oneDayTimeStamp) % 365;
            if(_usedDayCount >= 1) {
                return true;
            }else {
                return false;
            }
        }else {
            return false;
        }
    }
  
}