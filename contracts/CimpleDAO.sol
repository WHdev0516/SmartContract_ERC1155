// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./NFTUtils.sol";
import "./VoteUtils.sol";

contract CimpleDAO is ERC1155, Ownable {
    using SafeMath for uint256;
    NFTUtils private nftUtils;
    VoteUtils private voteUtils;
    uint256 public constant Cimple = 0;
    uint256 public constant stCimple = 1;
    uint256 public constant CMPG = 2;
    mapping(uint256 => uint256) public tokenSupply;
    mapping(uint256 => uint256) public tokenBurn;
    mapping(uint256 => uint256) public tokenSupplyLimit;
    
    uint256 public constant CMPGDecimal = 18;
    uint256 public constant CMPGDistributionPercentDecimal = 10;
    uint256 public constant DailyCMPGSupplyDecreasePercentDecimal = 10;

    uint256 private deployedStartTimeStamp;
    uint256 private constant oneSecondTimeStamp = 1; 
    uint256 private constant oneDayTimeStamp = 864 * 1e2;
    uint256 private constant oneYearTimeStamp = 3154 * 1e4;
    mapping(address => bool) private mintRoleList;
    uint256 public totalMintRoleList;

    struct UserDetail {
        address userAddress;
        uint256 cimpleValue;
        uint256 stCimpleValue;
        uint256 CMPGValue;
        string referralID;
        string referredBy;
    }
    UserDetail[] private usersInfo;

    struct StakeHolder {
        address holderAddress;
        uint256 holdTimeStamp;
    }
    StakeHolder[] internal stakeholders; 

    mapping(address => bool) public votablelist;
    uint256 public votablelistcounter = 0;
    mapping(address => bool) public votecreatablelist;
    uint256 public votecreatablelistcounter = 0;
    
    modifier mintable() {
        require(mintRoleList[msg.sender] || msg.sender == owner(), 'Sorry, this address is not on the whitelist.');
        _;
    }

    modifier votable() {
        require(votablelist[msg.sender], 'Sorry, this address is not on the votable list.');
        _;
    }

    modifier votecreatable() {
        require(votecreatablelist[msg.sender], 'Sorry, this address is not on the vote creatable list.');
        _;
    }
    event PayFee(address, uint256, uint256);
    event StakingCimpleToken(address, uint256, uint256);
    event UnstakingCimpleToken (address indexed, uint256, uint256);
    event CreatedNewUser(address indexed, string);
    event UpdatedUserInfo(address, uint256, uint256, uint256, string, string);

    event ClaimRewardFirstCimpleForNFT(address, uint256, uint256);
    event ClaimRewardStreamingForNFT(address, uint256, uint256);
    constructor(address _nftUtils, address _voteUtils) ERC1155("") {
        deployedStartTimeStamp = block.timestamp;
        nftUtils = NFTUtils(_nftUtils);
        voteUtils = VoteUtils(_voteUtils);
    }

    function requestVoteProposal (address createaddress, string memory des, uint256 endtime, uint256 starttime) public payable votecreatable {
        voteUtils.makeproposal(createaddress, des, endtime, starttime);
    }

    function requestVoteAction (address voteaddress, uint256 vote_id ,bool proposal) external votable returns (bool ) {
        bool votedone =  voteUtils.voteAction(voteaddress, vote_id, proposal);
        return votedone;
    }

    function requestVoteResult () external view returns (uint256[] memory, uint256[] memory, uint256[] memory, string[] memory, uint256[] memory, uint256[] memory ) {
        uint256 tempcounter = voteUtils.getVountCounter();
        uint256[] memory tempvoteidlist = new uint256[](tempcounter); 
        uint256[] memory tempagree = new uint256[](tempcounter); 
        uint256[] memory tempopposite = new uint256[](tempcounter);
        uint256[] memory tempcreatetime = new uint256[](tempcounter);
        uint256[] memory tempendtime = new uint256[](tempcounter);
        string[] memory tempdes = new string[](tempcounter);
        (tempvoteidlist,tempagree,tempopposite,tempdes,tempcreatetime,tempendtime) = voteUtils.voteresult();
        return (tempvoteidlist,tempagree,tempopposite,tempdes,tempcreatetime,tempendtime);
    }

    function getNFTUserListAtFirst() public view returns (address[] memory users, uint256[] memory times, uint256[] memory prices, uint256[] memory tokenIDs) {
        (users, times, prices, tokenIDs) = CiMPLENFT(nftUtils.getCiMPLENFTaddress()).getmintaddress();
        return (users, times, prices, tokenIDs);
    }

    function multipleAddressesToMintableRoleList(address[] memory addresses) public onlyOwner {
        for(uint256 i =0; i < addresses.length; i++) {
            singleAddressToMintableRoleList(addresses[i]);
        }
    }

    function singleAddressToMintableRoleList(address userAddress) public onlyOwner {
        require(userAddress != address(0), "Address can not be zero");
        if(!mintRoleList[userAddress]) {
            mintRoleList[userAddress] = true;
            totalMintRoleList++;
            _addOrUpdateUserInfo(userAddress);
        }
    }

    function removeAddressesFromMintableRoleList(address[] memory addresses) public onlyOwner {
        for(uint i =0; i<addresses.length; i++) {
            removeAddressFromMintableRoleList(addresses[i]);
        }
    }

    function removeAddressFromMintableRoleList(address userAddress) public onlyOwner {
        require(userAddress != address(0), "Address can not be zero");
        if(mintRoleList[userAddress]){
            mintRoleList[userAddress] = false;
            totalMintRoleList--;
        }
    }
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
    function mint(address account, uint256 id, uint256 amount) public mintable {
        _mint(account, id, amount, "0x000");
        tokenSupply[id] = tokenSupply[id].add(amount);
        _addOrUpdateUserInfo(account);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
        for(uint256 i = 0; i < ids.length; i++){
            tokenSupply[ids[i]] = tokenSupply[ids[i]].add(amounts[i]);
        }
        _addOrUpdateUserInfo(to);
    }
    function burn(address account, uint256 id, uint256 amount) public mintable {
        _burn(account, id, amount);
        tokenSupply[id] = tokenSupply[id].sub(amount);
        tokenBurn[id] = tokenBurn[id].add(amount);
        _addOrUpdateUserInfo(account);
    }

    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) public onlyOwner {
        _burnBatch(from, ids, amounts);
        for(uint256 i = 0; i < ids.length; i++){
            tokenSupply[ids[i]] = tokenSupply[ids[i]].sub(amounts[i]);
            tokenBurn[ids[i]] = tokenBurn[ids[i]].add(amounts[i]);
        }
        _addOrUpdateUserInfo(from);
    }
    function calculateCimpleIR(uint256 _currentTimeStamp) public view returns( uint256, uint256, uint256 ) {
        require(deployedStartTimeStamp < _currentTimeStamp, 'Error, selected date is lower than token publish date');
        uint256 currentTimeStamp = _currentTimeStamp;
        uint256 periodTimeStamp = currentTimeStamp.sub(deployedStartTimeStamp);
        uint256 usedDayCount = periodTimeStamp.div(oneDayTimeStamp).mod(365);
        uint256 usedYearCount = periodTimeStamp.div(oneYearTimeStamp);
        uint256 stepPrice = 1e11;
        uint256 cimpleIR = 1e12;
        uint256[31] memory additionalDailyRatePerYear;
        uint256[31] memory baseCimpleIRForNewYear;
        additionalDailyRatePerYear[0] = 1e11;
        baseCimpleIRForNewYear[0] = 1e12;
        if(usedYearCount > 30) {
            usedYearCount = 30;
        }
        if(usedYearCount < uint256(1)){
            stepPrice = additionalDailyRatePerYear[usedYearCount];
        }else{
            for (uint256 i = 1; i <= usedYearCount; i++) {
                uint256 temp = additionalDailyRatePerYear[i - 1] * 175 / 100;
                for (uint256 index = 1; index <= i; index++) {
                    temp = temp * 9810837779 / 1e10;
                }
                additionalDailyRatePerYear[i] = temp;
            }
            stepPrice = additionalDailyRatePerYear[usedYearCount];
            baseCimpleIRForNewYear[usedYearCount] = baseCimpleIRForNewYear[usedYearCount - 1] +  additionalDailyRatePerYear[usedYearCount - 1] * 365;
        }
        uint256 deltaIR = stepPrice * usedDayCount;
        cimpleIR = baseCimpleIRForNewYear[usedYearCount];
        cimpleIR = cimpleIR + deltaIR;
        if(cimpleIR >= 1e18) {
            cimpleIR = 1e18;
        }
        return (cimpleIR, stepPrice, usedDayCount);
    }

    function isUser(address _address) public view returns(bool, uint256) {
       for (uint256 s = 0; s < usersInfo.length; s += 1){
           if (_address == usersInfo[s].userAddress) return (true, s);
       }
       return (false, 0);
    }
    function _addOrUpdateUserInfo(address userAddress) internal {
        (bool _isUser, uint256 s) = isUser(userAddress);
        if(_isUser){
            UserDetail storage tempUser = usersInfo[s];
            tempUser.cimpleValue = balanceOf(userAddress, Cimple);
            tempUser.stCimpleValue = balanceOf(userAddress, stCimple);
            tempUser.CMPGValue = balanceOf(userAddress, CMPG);
            if ((tempUser.CMPGValue*100)/tokenSupply[CMPG] > 10) {
                votablelist[userAddress] = true;
            }
            else {
                votablelist[userAddress] = false;
            }
            if ((tempUser.CMPGValue*100)/tokenSupply[CMPG] > 1) {
                votecreatablelist[userAddress] = true;
            }
            else {
                votecreatablelist[userAddress] = false;
            }
        }else{
            usersInfo.push(UserDetail(userAddress, 0, 0, 0 , "", ""));
        }
    }

    function createAccount (address userAddress, string memory referralID) public payable returns(bool) {
        (bool _isUser, ) = isUser(userAddress);
        if(!_isUser) {
            usersInfo.push(UserDetail(userAddress,balanceOf(userAddress, Cimple), balanceOf(userAddress, stCimple), balanceOf(userAddress, CMPG), referralID, ""));
            emit CreatedNewUser(userAddress, referralID);
        }
        return true;
    }

    function updateUserInfo (address userAddress, string memory referredByID) public payable returns (bool) {
        (bool _isUser, uint256 s) = isUser(userAddress);
        if(_isUser) {
            UserDetail storage tempUser = usersInfo[s];
            tempUser.cimpleValue = balanceOf(userAddress, Cimple);
            tempUser.stCimpleValue = balanceOf(userAddress, stCimple);
            tempUser.CMPGValue = balanceOf(userAddress, CMPG);
            tempUser.referredBy = referredByID;
            emit UpdatedUserInfo(userAddress, tempUser.cimpleValue, tempUser.stCimpleValue, tempUser.CMPGValue, tempUser.referralID, referredByID);
        }
        return true;
    }
    function getUserInfo(address userAddress) external view returns( UserDetail memory tempUserInfo ) {
        (bool _isUser, uint256 s) = isUser(userAddress);
        if(_isUser) {
            tempUserInfo = usersInfo[s];
        }else {
            tempUserInfo = UserDetail(userAddress, 0, 0, 0, "", "");
        }
        
        return tempUserInfo;
    }

    function getUsersInfo() external view returns (address[] memory, string[] memory) {
        uint256 usersCount = usersInfo.length;
        address[] memory users = new address[](usersCount);
        string[] memory referralIDs = new string[](usersCount);
        for (uint i = 0; i < usersCount; i++) {
            users[i] = (usersInfo[i].userAddress);
            referralIDs[i] = (usersInfo[i].referralID);
        }
        return (users,referralIDs);
    }

    function isStakeholder(address _address) internal view returns(bool, uint256) {
       for (uint256 s = 0; s < stakeholders.length; s += 1){
           if (_address == stakeholders[s].holderAddress) return (true, s);
       }
       return (false, 0);
    }

    function addStakeholder(address _stakeholder, uint256 _timeStamp) private {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(StakeHolder(_stakeholder, _timeStamp));
    }


    function removeStakeholder(address _stakeholder) private {
        (bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
        if(_isStakeholder){
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        }
    }
    function totalStakes() public view returns(uint256) {
       uint256 _totalStakes = 0;
       for (uint256 s = 0; s < stakeholders.length; s += 1){
           _totalStakes = _totalStakes.add(balanceOf(stakeholders[s].holderAddress, stCimple));
       }
       return _totalStakes;
    }
    function createStake(address staker, uint256 _stake) public payable returns (bool) {
        require(_stake <= balanceOf(staker, Cimple), 'Error stake amount must be >= holding amount of Cimple Token');
        
        (bool _isStakeholder, uint256 s) = isStakeholder(staker);
        if(!_isStakeholder) addStakeholder(staker, block.timestamp);
        else {
            StakeHolder memory stakeholder = stakeholders[s];
            uint256 rewardOfCMPG = 0;
            (rewardOfCMPG, , ) = calculateReward(staker, stakeholder.holdTimeStamp, block.timestamp);
            _mint(staker, CMPG, rewardOfCMPG, "0x000");
            tokenSupply[CMPG] = tokenSupply[CMPG].add(rewardOfCMPG);

            stakeholders[s].holdTimeStamp = block.timestamp;
        } 
        _burn(staker, Cimple, _stake);
        _mint(staker, stCimple, _stake, "0x000");
        tokenSupply[stCimple] = tokenSupply[stCimple].add(_stake);
        tokenSupply[Cimple] = tokenSupply[Cimple].sub(_stake);
        tokenBurn[Cimple] = tokenBurn[Cimple].add(_stake);
        _addOrUpdateUserInfo(staker);
        emit StakingCimpleToken(staker, stCimple, _stake);
        return true;
    }

    function removeStake(address unstaker, uint256 _stake) public payable returns ( bool ) {
        require(_stake <= balanceOf(unstaker, stCimple), 'Error, unstake amount must be >= holding amount of stCimple Token.');
        (bool _isStakeholder, uint256 s) = isStakeholder(unstaker);
        StakeHolder memory stakeholder = stakeholders[s];
        uint256 rewardOfCMPG = 0;
        (rewardOfCMPG, , ) = calculateReward(unstaker, stakeholder.holdTimeStamp, block.timestamp);
        if(_isStakeholder){
            _burn(unstaker, stCimple, _stake);
            _mint(unstaker, Cimple, _stake, "0x000");
            tokenSupply[stCimple] = tokenSupply[stCimple].sub(_stake);
            tokenSupply[Cimple] = tokenSupply[Cimple].add(_stake);
            tokenBurn[stCimple] = tokenBurn[stCimple].add(_stake);
            _mint(unstaker, CMPG, rewardOfCMPG, "0x000");
            tokenSupply[CMPG] = tokenSupply[CMPG].add(rewardOfCMPG);
            if(balanceOf(unstaker, stCimple) == 0) { 
                removeStakeholder(unstaker);
            } else{
                stakeholders[s].holdTimeStamp = block.timestamp;
            } 
            _addOrUpdateUserInfo(unstaker);
            emit UnstakingCimpleToken(unstaker, Cimple, _stake);
            return true;
        }else {
            emit UnstakingCimpleToken(unstaker, Cimple, _stake);
            return false;
        }
    }
   
    function totalRewards() public view  returns(uint256) {
        uint256 _totalRewards = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1){
           _totalRewards = _totalRewards.add(balanceOf(stakeholders[s].holderAddress, CMPG));
        }
        return _totalRewards;
    }
    function calculateReward(address _stakeholder, uint256 _holdTimeStamp, uint256 _nowTimeStamp) public view returns(uint256, uint256, uint256) {
        if(_nowTimeStamp > _holdTimeStamp && _holdTimeStamp >= deployedStartTimeStamp){
            uint256 _distributionPercentOfCMPG = _calculateDistributionPercentOfCMPG(_stakeholder);
            uint256 _dayCountAtNow = (_nowTimeStamp.sub(deployedStartTimeStamp)).div(oneDayTimeStamp);
            uint256 _extraTimeCountAtNow = (_nowTimeStamp.sub(deployedStartTimeStamp)).mod(oneDayTimeStamp);

            uint256 _dayCountAtHold = (_holdTimeStamp.sub(deployedStartTimeStamp)).div(oneDayTimeStamp);
            uint256 _extraTimeCountAtHold = (_holdTimeStamp.sub(deployedStartTimeStamp)).mod(oneDayTimeStamp);
            uint256 _holdPeriodDayCount = _dayCountAtNow - _dayCountAtHold;
            uint256 _minusCMPGAmountAtHold;
            ( , uint256 _tempPerTime) = _calculateDailySupplyOfCMPG(_dayCountAtHold);
            _minusCMPGAmountAtHold = _tempPerTime * (oneDayTimeStamp - _extraTimeCountAtHold) * _distributionPercentOfCMPG;
            uint256 _availableRewardAmount = 0;
            if(_holdPeriodDayCount > 0) {
                for (uint256 index = 0; index < _holdPeriodDayCount; index++) {
                    (uint256 _dailySupplyOfCMPG, ) = _calculateDailySupplyOfCMPG(_dayCountAtHold + index);
                    _availableRewardAmount += _dailySupplyOfCMPG * _distributionPercentOfCMPG;
                }
            }
            uint256 _plusCMPGAmountAtHold = 0;
            ( , uint256 _tempPerTime1) = _calculateDailySupplyOfCMPG(_dayCountAtNow);
            _plusCMPGAmountAtHold = _tempPerTime1 * _extraTimeCountAtNow * _distributionPercentOfCMPG;

            _availableRewardAmount = _availableRewardAmount + _plusCMPGAmountAtHold + _minusCMPGAmountAtHold;
            return (_availableRewardAmount, _dayCountAtNow, _extraTimeCountAtNow);
        }else {
            return (0, 0 ,0);
        }
        
    }

    function testCalculateReward(address _stakeholder, uint256 _timeStamp) public view returns(uint256, uint256, uint256) {
        (bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
        if(_isStakeholder) {
            StakeHolder memory stakeholder = stakeholders[s];
            uint256 s1;
            uint256 s2;
            uint256 s3;
            (s1, s2, s3)= calculateReward(stakeholder.holderAddress, stakeholder.holdTimeStamp, _timeStamp);
            return (s1, s2, s3);
        }else {
            return (0, 0, 0);
        }
    }
    function _calculateDailySupplyOfCMPG(uint256 _days) public pure returns (uint256, uint256) {
        uint256 _initSupplyOfCMPG = 32913 * (10 ** CMPGDecimal);
        uint256 _dailyDecreasePercent = 358059438; // 1e10 decimal
        uint256 _dailyDecreasePercentDecimal = 1e10;
        uint256 _dailySupplyAmount = _initSupplyOfCMPG;
        if(_days >= 1){
            for (uint256 index = 0; index < _days; index++) {
                _dailySupplyAmount = _dailySupplyAmount - _dailySupplyAmount * _dailyDecreasePercent / _dailyDecreasePercentDecimal;
            }
        }
        uint256 _perTimeSupplyAmount = _dailySupplyAmount / oneDayTimeStamp;
        return (_dailySupplyAmount, _perTimeSupplyAmount);
    }
    function _calculateDistributionPercentOfCMPG(address _address) public view returns( uint256 ) {
        (bool _isStakeHolder, ) = isStakeholder(_address);
        if(stakeholders.length > 0 && _isStakeHolder){
            uint256 _totalRewardOfCMPG = totalStakes();
            uint256 _amountCMPGOfHolder = balanceOf(_address, stCimple);
            uint256 _distributionPercent = (10 ** CMPGDistributionPercentDecimal) * _amountCMPGOfHolder / _totalRewardOfCMPG;
            return _distributionPercent;
        }
        return 0;
    }
    function getStakeHolders() public view returns(address[] memory, uint256[] memory) {
        uint256 length = stakeholders.length;
        address[] memory owners = new address[](length);
        uint256[] memory prices =  new uint256[](length);
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            StakeHolder memory stakeholder = stakeholders[s];
            owners[s] = (stakeholder.holderAddress);
            prices[s] = (stakeholder.holdTimeStamp);
        }
        return (owners,prices);
    }
    function payFee() public payable returns ( bool ) {
        require(msg.value > 0, 'Error, Paying fee must be >= 0');
        uint256 value1 = msg.value;
        uint256 cimpleIR;
        uint256 s1;
        uint256 s2;
        (cimpleIR, s1, s2) = calculateCimpleIR(block.timestamp);
        // uint256 cimpleIR = token.getCimpleIR();
        uint256 cimpleCountForValue = value1.div(cimpleIR);
        _mint(msg.sender, Cimple, cimpleCountForValue,"0x000"); //sending token to user
        tokenSupply[Cimple] = tokenSupply[Cimple].add(cimpleCountForValue);
        _addOrUpdateUserInfo(msg.sender);
        emit PayFee(msg.sender, Cimple, cimpleCountForValue);
        return true;
    }

    function payFeeByToken(address spender, uint256 cimpleAmount) public returns(bool) {
        require(cimpleAmount > 0, "Error, amount of pay must be > 0");
        _burn(spender, Cimple, cimpleAmount);
        tokenSupply[Cimple] = tokenSupply[Cimple].sub(cimpleAmount);
        tokenBurn[Cimple] = tokenBurn[Cimple].add(cimpleAmount);
        _addOrUpdateUserInfo(spender);
        emit PayFee(spender, Cimple, cimpleAmount);
        return true;
    }

    function claimFirstCimpleForNFT(address _userAddress, uint256 _tokenID) public payable returns(bool){
        (uint256[] memory _tokenIDs, uint256[] memory _prices, ) = nftUtils.filterNftDetail(_userAddress);
        bool _flag = false;
        uint256 _selectedTokenPrice;
        for (uint256 i = 0; i < _tokenIDs.length; i += 1){
            if(_tokenID == _tokenIDs[i]){
                _flag = true;
                _selectedTokenPrice = _prices[i];
            } 
        }
        require(nftUtils.getNftAwardList(_tokenID) == false && _flag, "This user is not available for this rewards.");

        (uint256 _cimpleIR, ,) = calculateCimpleIR(block.timestamp);
        uint256 _rewardCimpleAmount = _selectedTokenPrice.div(_cimpleIR);
        _mint(_userAddress, Cimple, _rewardCimpleAmount,"0x000");
        tokenSupply[Cimple] = tokenSupply[Cimple].add(_rewardCimpleAmount);
        _addOrUpdateUserInfo(_userAddress);

        nftUtils.setNftAwardList(_tokenID, true);
        nftUtils.increaseNftAwardListCount();
        emit ClaimRewardFirstCimpleForNFT(_userAddress, _tokenID, _rewardCimpleAmount);
        return true;
    }
    function claimRewardStreamingForNFT(address _address, uint256 _tokenID) public payable returns( bool) {
        (uint256 _cimpleIR, ,) = calculateCimpleIR(block.timestamp);
        (uint256 _rate, uint256 _mintTimestamp) = nftUtils.calculateStreamingRateForNFT(_address, _tokenID, block.timestamp, _cimpleIR);
        if(_rate > 0) {

            uint256 _currentTimeStamp = block.timestamp;
            uint256 _periodTimeStamp =0;
            (bool _isNftUser, uint256 s) = nftUtils.isNftUser(_address, _tokenID);
            if(_isNftUser == false) {
                nftUtils.addNFTUsersInfo(_address, _tokenID, block.timestamp);
                _periodTimeStamp = _currentTimeStamp.sub(_mintTimestamp);
            } 
            else {
                (, , uint256 _actionTimestamp) = nftUtils.getNFTUsersInfoByIndex(s);
                 _periodTimeStamp = _currentTimeStamp.sub(_actionTimestamp);
                 nftUtils.setNFTUsersInfoByIndex(s, block.timestamp);
            } 
            uint256 _usedDayCount = _periodTimeStamp.div(oneDayTimeStamp).mod(365);
            uint256 _amountOfReward = _rate.mul(_usedDayCount);

            _mint(_address, Cimple, _amountOfReward,"0x000");
            tokenSupply[Cimple] = tokenSupply[Cimple].add(_amountOfReward);
            
            _addOrUpdateUserInfo(_address);
            emit ClaimRewardStreamingForNFT(_address, _tokenID, _amountOfReward);
            return true;
        }
        return false;
    }
}
