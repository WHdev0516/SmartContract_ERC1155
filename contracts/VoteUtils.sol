// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VoteUtils {
    struct VoteDetail {
        uint256 voteid;
        string description;
        uint256 agreecount;
        uint256 oppositecount;
        address[] voters;
        uint256 createtime;
        uint256 endtime;
    }

    address private owner;

    mapping(uint => VoteDetail) public votelist;
    uint private votecounter = 0;

    constructor() {
        owner = msg.sender;
    }

    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }

    function changeOwner(address _newOwner) public {
        require(msg.sender == owner, 'failed');
        owner = _newOwner;
    }
    function makeproposal(address createaddress, string memory des, uint256 endtime, uint256 starttime) external payable isOwner {
        votelist[votecounter] = VoteDetail(votecounter, des, 0, 0, new address[](0), starttime, endtime);
        votelist[votecounter].voters.push(createaddress);
        votecounter++;
    }

    function voteAction(address voteaddress, uint256 vote_id ,bool proposal) external isOwner returns (bool ) {
        address[] storage  tempvoters = votelist[vote_id].voters; 
        tempvoters.push(voteaddress);
        uint256 tempvoteid = votelist[vote_id].voteid; 
        uint256 tempagree = votelist[vote_id].agreecount; 
        uint256  tempopposite = votelist[vote_id].oppositecount; 
        string memory tempdes = votelist[vote_id].description; 
        uint256 tempcreate = votelist[vote_id].createtime; 
        uint256 tempend = votelist[vote_id].endtime; 
        bool  checkaddress = _checkVoteAddress(voteaddress,tempvoters);
        if (checkaddress) {
            if (proposal) {
                votelist[vote_id] = VoteDetail(tempvoteid, tempdes, tempagree++, tempopposite, tempvoters, tempcreate, tempend);
            }
            else {
                votelist[vote_id] = VoteDetail(tempvoteid, tempdes, tempagree, tempopposite++, tempvoters, tempcreate, tempend);
            }
            return true;
        }
        else {
            return false;
        }
    }

    function getVountCounter() external view returns (uint256) {
        return votecounter;
    }
    function _checkVoteAddress(address p_voteaddress, address[] memory p_voters) private pure returns (bool ) {
        bool checkflag = false;
        for (uint i = 0; i < p_voters.length; i++)
        {
            if (p_voters[i] == p_voteaddress) {
                checkflag = true;
            }
        }
        return checkflag;
    }



    function voteresult() external view returns (uint256[] memory, uint256[] memory, uint256[] memory, string[] memory, uint256[] memory, uint256[] memory ) {
        uint256[] memory tempvoteidlist = new uint256[](votecounter); 
        uint256[] memory tempagree = new uint256[](votecounter); 
        uint256[] memory tempopposite = new uint256[](votecounter);
        uint256[] memory tempcreatetime = new uint256[](votecounter);
        uint256[] memory tempendtime = new uint256[](votecounter);
        string[] memory tempdes = new string[](votecounter);
        for (uint i = 0; i < votecounter; i++) {
            tempvoteidlist[i] = (votelist[i].voteid);
            tempagree[i] = (votelist[i].agreecount);
            tempopposite[i] = (votelist[i].oppositecount);
            tempdes[i] = (votelist[i].description);
            tempcreatetime[i] = (votelist[i].createtime);
            tempendtime[i] = (votelist[i].endtime);
        }
        return (tempvoteidlist,tempagree,tempopposite,tempdes,tempcreatetime,tempendtime);
    }
}