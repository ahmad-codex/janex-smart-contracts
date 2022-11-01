pragma solidity ^0.8.0;

interface IStakingPool {
    struct StakingData {
        uint stakingAmount;
        uint reward;
        uint locktime;
    }
    
    function staking(uint amount) external;
    
    function stakingOnBehalf(address account, uint amount) external;
    
    function withdraw(address account) external returns(uint);
    
    function withdrawReward(uint amount) external;
    
    function getUserStakingData(address account) external view returns(StakingData[] memory);
    
    function getEndTime() external view returns(uint);
    
    function getRequireLockTime(address account) external view returns(uint);
}
