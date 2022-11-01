pragma solidity ^0.8.0;
import "../common/interfaces/IERC20.sol";
import "../common/Ownable.sol";
import "./interfaces/IStakingPool.sol";

contract StakingPool is IStakingPool, Ownable {
    
    mapping(address => StakingData[]) public userStakingData;
    mapping(address => bool) public isCurrentStaking;
    
    IERC20 public stakingToken;
    address public Janex;
    
    uint public duration;
    uint public endTime;
    uint public rewardRate;

    event DepositReward(uint amount, uint timestamp);
    event WithdrawReward(uint amount, uint timestamp);
    event StartStaking(uint timestamp, uint duration, uint endTime, uint rewardRate);

    event Staking(address account, uint timestamp, StakingData stakingData);
    event StakingOnBehalf(address account, address accountOnBehalf, uint timestamp, StakingData stakingData);
    event Withdraw(address account, uint timestamp, uint amount);
    
    constructor(IERC20 token, address _Janex) {
        stakingToken = token;
        Janex = _Janex;
    }
    
    modifier onlyJanex() {
        require(Janex == msg.sender, "StakingPool: not from Janex");
        _;
    }
    
    function getUserStakingData(address account) external view override returns(StakingData[] memory) {
        return userStakingData[account];
    }
    
    function getRequireLockTime(address account) external view override returns(uint) {
        uint countStaking = userStakingData[account].length;
        return userStakingData[account][countStaking - 1].locktime;
    } 
    
    function getEndTime() external view override returns(uint) {
        return endTime;
    }
    
    function depositReward(uint _totalReward) external onlyOwner {
        stakingToken.transferFrom(msg.sender, address(this), _totalReward);
        emit DepositReward(_totalReward, block.timestamp);
    }
    
    function withdrawReward(uint amount) external override onlyOwner {
        require(amount <= stakingToken.balanceOf(address(this)), "StakingPool: Don't have enough balance to withdraw");
        stakingToken.transfer(msg.sender, amount);
        emit WithdrawReward(amount, block.timestamp);
    }
    
    function startStaking(uint _duration, uint _endTime, uint _rewardRate) external onlyOwner {
        require(block.timestamp > endTime, "StakingPool: cannot start new staking in this time");
        duration = _duration;
        endTime = _endTime;
        rewardRate = _rewardRate;
        emit StartStaking(block.timestamp, duration, endTime, rewardRate);
    }
    
    function staking(uint amount) external override {
        require(block.timestamp < endTime, "StakingPool: can't stake in this time");
        StakingData[] storage stakingData = userStakingData[msg.sender];
        
        StakingData memory _stakingData;
        
        _stakingData.stakingAmount = amount;
        _stakingData.locktime = block.timestamp + duration;
        _stakingData.reward = amount * rewardRate / 100;
        stakingData.push(_stakingData);
        isCurrentStaking[msg.sender] = true;
        
        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit Staking(msg.sender, block.timestamp, _stakingData);
    }
    
    function stakingOnBehalf(address account, uint amount) external override onlyJanex {
        require(block.timestamp < endTime, "StakingPool: can't stake in this time");
        StakingData[] storage stakingData = userStakingData[account];
        
        StakingData memory _stakingData;
        
        _stakingData.stakingAmount = amount;
        _stakingData.locktime = block.timestamp + duration;
        _stakingData.reward = amount * rewardRate / 100;
        stakingData.push(_stakingData);
        isCurrentStaking[account] = true;
        
        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit StakingOnBehalf(account, msg.sender, block.timestamp, _stakingData);
    }
    
    function withdraw(address account) external override returns(uint) {
        require(block.timestamp >= this.getRequireLockTime(account), "StakingPool: in locktime");
        require(isCurrentStaking[account], "StakingPool: not staking");
        StakingData[] storage stakingData = userStakingData[account];
        
        uint totalReward;
        uint totalStakingAmount;
        uint newTotalBalance;
        
        for (uint i = 0; i < stakingData.length; i++) {
            if (block.timestamp >= stakingData[i].locktime) {
                totalStakingAmount += stakingData[i].stakingAmount;
                totalReward += stakingData[i].reward;
                stakingData[i].stakingAmount = 0;
                stakingData[i].reward = 0;
                stakingData[i].locktime = 0;
            }
            newTotalBalance += stakingData[i].stakingAmount;
        }
        
        isCurrentStaking[account] = newTotalBalance == 0 ? false : true;
        
        uint amountReturn = totalReward + totalStakingAmount;
        stakingToken.transfer(msg.sender, amountReturn);
        return amountReturn;
        emit Withdraw(account, block.timestamp, amountReturn);
    }
}