// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
contract CimpleDAO is ERC1155, Ownable {
    using SafeMath for uint256;
    //token id 
    uint256 public constant Cimple = 0;
    uint256 public constant stCimple = 1;
    uint256 public constant CMPG = 2;
    // total amount both mint and burn
    mapping(uint256 => uint256) public tokenSupply;
    mapping(uint256 => uint256) public tokenBurn;
    mapping(uint256 => uint256) public tokenSupplyLimit;
    mapping(uint256 => address) nftOwners;
    uint256 public nftIdIndex;
    
    // Decimal config
    uint256 public constant CMPGDecimal = 18; //CMPG decimal
    uint256 public constant CMPGDistributionPercentDecimal = 10; //distribution cmpg percent decimal
    uint256 public constant DailyCMPGSupplyDecreasePercentDecimal = 10; // daily cmpg supply percent decimal

    // Timestamp config
    uint256 private deployedStartTimeStamp; // contract deployed timestamp * this is in need to calculate cimpleIR, etc
    uint256 private constant oneSecondTimeStamp = 1; 
    uint256 private constant oneDayTimeStamp = 864 * 1e2; // timestamp per day
    uint256 private constant oneYearTimeStamp = 3154 * 1e4; // timestamp per year
    //whitelist    
    mapping(address => bool) public mintRoleList;
    mapping(address => bool) public registeredUsers;
    uint256 public totalMintRoleList;

    // user info structure
    struct UserDetail {
        uint256 cimpleValue;
        uint256 stCimpleValue;
        uint256 CMPGValue;
        uint256 referralID;
        uint256 referredBy;
    }
    uint256 private currentReferralIDIndex;
    mapping (address=>UserDetail) private usersInfo;

    //staking part config
    struct StakeHolder {
        address holderAddress;
        uint256 holdTimeStamp;
    }
    StakeHolder[] internal stakeholders; 
    // End staking part config

    // mintable modifier
    modifier mintable() {
        require(mintRoleList[msg.sender] || msg.sender == owner(), 'Sorry, this address is not on the whitelist.');
        _;
    }

    // event calculatedCimpleIR (uint256 indexed ciIR, uint256 curTimeStamp);
    constructor() ERC1155("") {
        deployedStartTimeStamp = block.timestamp;
    }
    // get CMPG decimal
    // function getCMPGDecimal() public view returns (uint256){
    //     return CMPGDecimal;
    // }
    /** Add multiple addresses to mintableRoleList */
    function multipleAddressesToMintableRoleList(address[] memory addresses) public onlyOwner {
        for(uint256 i =0; i < addresses.length; i++) {
            singleAddressToMintableRoleList(addresses[i]);
        }
    }

    /** Add single address to mintableRoleList */
    function singleAddressToMintableRoleList(address userAddress) public onlyOwner {
        require(userAddress != address(0), "Address can not be zero");
        if(!mintRoleList[userAddress]) {
            mintRoleList[userAddress] = true;
            totalMintRoleList++;
            _addOrUpdateUserInfo(userAddress);
        }
    }

    /** Remove multiple addresses from mintableRoleList */
    function removeAddressesFromMintableRoleList(address[] memory addresses) public onlyOwner {
        for(uint i =0; i<addresses.length; i++) {
            removeAddressFromMintableRoleList(addresses[i]);
        }
    }

    /** Remove single address from mintableRoleList */
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
    // Mint FT and NFT including batch minting functions
    function mint(address account, uint256 id, uint256 amount) public mintable {
        _mint(account, id, amount, "0x000");
        tokenSupply[id] = tokenSupply[id].add(amount);
        _addOrUpdateUserInfo(account);
    }

    function mintNFT(address account, uint256 id) public mintable {
        _mint(account, id, 1, "0x000");
        nftOwners[id] = account;
        tokenSupply[id] = tokenSupply[id].add(1);
        _addOrUpdateUserInfo(account);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
        for(uint256 i = 0; i < ids.length; i++){
            tokenSupply[ids[i]] = tokenSupply[ids[i]].add(amounts[i]);
        }
        _addOrUpdateUserInfo(to);
    }
    function mintBatchNFT(address to, uint256[] memory ids) public onlyOwner {
        for(uint256 i = 0; i < ids.length; i++){
            mintNFT(to, ids[i]);
        }
    }
    // Burn FT and NFT function
    function burn(address account, uint256 id, uint256 amount) public mintable {
        _burn(account, id, amount);
        tokenSupply[id] = tokenSupply[id].sub(amount);
        tokenBurn[id] = tokenBurn[id].add(amount);
        _addOrUpdateUserInfo(account);
    }
    function burnNFT(address account, uint256 id) public mintable {
        _burn(account, id, 1);
        tokenSupply[id] = tokenSupply[id].sub(1);
        tokenBurn[id] = tokenBurn[id].add(1);
        delete nftOwners[id];
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
    function burnBatchNFT(address from, uint256[] memory ids) public onlyOwner {
        for(uint256 i = 0; i < ids.length; i++){
            burnNFT(from, ids[i]);
        }
    }
    // implementation issuance/redemption rate
    function calculateCimpleIR(uint256 _currentTimeStamp) external view returns( uint256, uint256, uint256 ) {
        require(deployedStartTimeStamp < _currentTimeStamp, 'Error, selected date is lower than token publish date'); //dBank
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
    // ADD, EDIT, DELETE   
    function _addOrUpdateUserInfo(address userAddress) internal {
        if(registeredUsers[userAddress]){
            UserDetail storage tempUser = usersInfo[userAddress];
            tempUser.cimpleValue = balanceOf(userAddress, Cimple);
            tempUser.stCimpleValue = balanceOf(userAddress, stCimple);
            tempUser.CMPGValue = balanceOf(userAddress, CMPG);
        }else{
            registeredUsers[userAddress] = true;
            currentReferralIDIndex++;
            UserDetail memory tempUser = UserDetail(balanceOf(userAddress, Cimple), balanceOf(userAddress, stCimple), balanceOf(userAddress, CMPG), currentReferralIDIndex, 0);
            usersInfo[userAddress] = tempUser;
        }
        
    }

    function getUserInfo(address userAddress) external view returns( UserDetail memory tempUserInfo ) {
        require(registeredUsers[userAddress], "error: User does not exist on chain data.");
        tempUserInfo = usersInfo[userAddress];
        return tempUserInfo;
    }

    // staking part is here ===================
    /**
    * @notice A method to check if an address is a stakeholder.
    * @param _address The address to verify.
    * @return bool, uint256 Whether the address is a stakeholder,
    * and if so its position in the stakeholders array.
    */
    function isStakeholder(address _address) internal view returns(bool, uint256) {
       for (uint256 s = 0; s < stakeholders.length; s += 1){
           if (_address == stakeholders[s].holderAddress) return (true, s);
       }
       return (false, 0);
    }
    /**
    * @notice A method to add a stakeholder.
    * @param _stakeholder The stakeholder to add.
    */
    function addStakeholder(address _stakeholder, uint256 _timeStamp) public {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(StakeHolder(_stakeholder, _timeStamp));
    }

    /**
        * @notice A method to remove a stakeholder.
        * @param _stakeholder The stakeholder to remove.
        */
    function removeStakeholder(address _stakeholder) public {
        (bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
        if(_isStakeholder){
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        }
    }
    /**
        * @notice A method to the aggregated stakes from all stakeholders.
        * @return uint256 The aggregated stakes from all stakeholders.
        */
    function totalStakes() public view returns(uint256) {
       uint256 _totalStakes = 0;
       for (uint256 s = 0; s < stakeholders.length; s += 1){
           _totalStakes = _totalStakes.add(balanceOf(stakeholders[s].holderAddress, stCimple));
       }
       return _totalStakes;
    }
    /**
    * @notice A method for a stakeholder to create a stake.
    * @param _stake The size of the stake to be created.
    */
    function createStake(address staker, uint256 _stake) public onlyOwner{
        burn(staker, Cimple, _stake);
        mint(staker, stCimple, _stake);
        tokenSupply[stCimple] = tokenSupply[stCimple].add(_stake);
        tokenSupply[Cimple] = tokenSupply[Cimple].sub(_stake);
        (bool _isStakeholder, uint256 s) = isStakeholder(staker);
        if(!_isStakeholder) addStakeholder(staker, block.timestamp);
        else stakeholders[s].holdTimeStamp = block.timestamp;
    }

    /**
        * @notice A method for a stakeholder to remove a stake.
        * @param _stake The size of the stake to be removed.
        */
    function removeStake(address unstaker, uint256 _stake) public onlyOwner{
        (bool _isStakeholder, uint256 s) = isStakeholder(unstaker);
        if(_isStakeholder){
            burn(unstaker, stCimple, _stake);
            mint(unstaker, Cimple, _stake);
            tokenSupply[stCimple] = tokenSupply[stCimple].sub(_stake);
            tokenSupply[Cimple] = tokenSupply[Cimple].add(_stake);
            if(balanceOf(unstaker, stCimple) == 0) removeStakeholder(unstaker);
            else stakeholders[s].holdTimeStamp = block.timestamp;
        }
    }
   
    function totalRewards() public view  returns(uint256) {
        uint256 _totalRewards = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1){
           _totalRewards = _totalRewards.add(balanceOf(stakeholders[s].holderAddress, CMPG));
        }
        return _totalRewards;
    }
    function calculateReward(address _stakeholder, uint256 _holdTimeStamp, uint256 _nowTimeStamp) public view returns(uint256) {
        if(_nowTimeStamp > _holdTimeStamp && _holdTimeStamp != 0){
            uint256 _distributionPercentOfCMPG = _calculateDistributionPercentOfCMPG(_stakeholder);
            uint256 _dayCountAtNow = _nowTimeStamp.sub(deployedStartTimeStamp).div(oneDayTimeStamp);
            uint256 _extraTimeCountAtNow = _nowTimeStamp.sub(deployedStartTimeStamp).mod(oneDayTimeStamp);

            uint256 _dayCountAtHold = _holdTimeStamp.sub(deployedStartTimeStamp).div(oneDayTimeStamp);
            uint256 _extraTimeCountAtHold = _holdTimeStamp.sub(deployedStartTimeStamp).mod(oneDayTimeStamp);
            uint256 _holdPeriodDayCount = _dayCountAtNow - _dayCountAtHold;
            uint256 _minusCMPGAmountAtHold;
            ( , uint256 _tempPerTime) = _calculateDailySupplyOfCMPG(_dayCountAtHold);
            _minusCMPGAmountAtHold = _tempPerTime * _extraTimeCountAtHold * _distributionPercentOfCMPG / 1e10;
            uint256 _availableRewardAmount;
            for (uint256 index = 0; index < _holdPeriodDayCount; index++) {
                (uint256 _dailySupplyOfCMPG, ) = _calculateDailySupplyOfCMPG(_dayCountAtHold + index);
                _availableRewardAmount += _dailySupplyOfCMPG * _distributionPercentOfCMPG / 1e10;
            }
            uint256 _plusCMPGAmountAtHold;
            ( , uint256 _tempPerTime1) = _calculateDailySupplyOfCMPG(_dayCountAtNow);
            _plusCMPGAmountAtHold = _tempPerTime1 * _extraTimeCountAtNow * _distributionPercentOfCMPG / 1e10;
            _availableRewardAmount = _availableRewardAmount + _plusCMPGAmountAtHold - _minusCMPGAmountAtHold;
            return _availableRewardAmount;
        }else {
            return 0;
        }
        
    }
    // daily supply of CMPG token 
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
    /**
    * @notice A method to distribute rewards to all stakeholders.
    */
    function distributeRewards(uint256 _timeStamp) public onlyOwner {
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            StakeHolder memory stakeholder = stakeholders[s];
            uint256 reward = calculateReward(stakeholder.holderAddress, stakeholder.holdTimeStamp, _timeStamp);
            if(reward > 0) {
                mint(stakeholder.holderAddress, CMPG, reward);
                tokenSupply[CMPG] = tokenSupply[CMPG].add(reward);
            }
        }
    }
    // End staking part 
}