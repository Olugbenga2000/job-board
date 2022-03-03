//SPDX-License-Identifier: Unlicense

pragma solidity 0.8.7;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Escrow is Ownable{

struct Job{
    uint id;
    uint amount;
    bool funded;
    address payable owner;
    address payable dev;
    jobState state;
}
uint public totalJobs;
address payable public web3bridge;
address public web3bridgeToken;
uint public web3bridgePercent;
enum jobState {PENDING, APPROVED, COMPLETED, CANCELLED}
mapping(uint => Job) public allJobs;

event Created(uint indexed id, uint indexed amount, address indexed jobOwner);
event Approved(uint indexed id, uint indexed amount, address indexed jobOwner);
event Funded(uint indexed id, uint indexed amount, address indexed jobOwner);
event Started(uint indexed id, address indexed dev, address indexed jobOwner);
event Completed(uint indexed id, address indexed dev, address indexed jobOwner);



modifier onlyJobOwner (uint id){
    require(allJobs[id].owner == msg.sender, 'only the job owner can call');
    _;
}

constructor(address payable _web3bridge, uint _web3bridgePercent){
    web3bridge = _web3bridge;
    web3bridgePercent = _web3bridgePercent;
}

function createJob(uint _amount) external {
    require(_amount > 0, 'price can not be 0');
    totalJobs ++ ;
    allJobs[totalJobs] = Job(totalJobs, _amount, false, payable(msg.sender), payable(address(0)), jobState.PENDING);

    emit Created(totalJobs, _amount, msg.sender);
}

function approveJob(uint _id) external onlyOwner{
    require(allJobs[_id].state == jobState.PENDING, 'only pending jobs can be approved');
    allJobs[_id].state = jobState.APPROVED;

    emit Approved(_id, allJobs[_id].amount, allJobs[_id].owner);
}

function fundJob(uint _id) external payable onlyJobOwner(_id){
    require((allJobs[_id].state == jobState.APPROVED && allJobs[_id].funded == false), 
                'job not approved for funding yet');
    require(msg.value == allJobs[_id].amount, 'not the correct amount');
    allJobs[_id].funded = true;
    uint amount = allJobs[_id].amount;
    emit Funded(_id, amount, msg.sender);
}

function startWork(uint _id) external {
    require(IERC20(web3bridgeToken).balanceOf(msg.sender) > 0, 'not a web3bridge dev');
    require((allJobs[_id].funded == true) && (allJobs[_id].dev == address(0)), 'job not funded yet');
    allJobs[_id].dev = payable(msg.sender);

    emit Started (_id, msg.sender, allJobs[_id].owner);
}

function JobCompleted(uint _id) external onlyJobOwner(_id){
    require(allJobs[_id].dev != address(0), 'The job can not be marked as completed');
    allJobs[_id].state = jobState.COMPLETED;
    address payable dev = allJobs[_id].dev;
    uint amount = allJobs[_id].amount;
    allJobs[_id].amount = 0;
    transferFunds(dev, amount);
    // mint kudos nft for dev
    emit Completed(_id, dev, msg.sender);
}

function transferFunds(address _dev, uint _amount) private {
    uint web3Fee = (web3bridgePercent * _amount)/100;
     (bool success, ) = web3bridge.call{value: web3Fee}("");
        require(success, "Failed to send to web3bridge.");

    uint devFee = _amount - web3Fee;
    (success, ) = _dev.call{value:devFee}("");
        require(success, "Failed to send to developer.");
}

function setWeb3bridgeAddress(address payable _addr) external onlyOwner{
    web3bridge = _addr;
}

function setWeb3bridgePercent(uint _fee) external onlyOwner{
    web3bridgePercent = _fee;
}


function getAllJobs() external view returns(Job[] memory) {
    uint jobCount = totalJobs;
    Job[]memory allCreatedJobs = new Job[](jobCount);

    for(uint i = 0; i < jobCount; i++ ){
        allCreatedJobs[i] = allJobs[i+1];
    }
    return allCreatedJobs;
}

function getPendingJobs() external view returns(Job[] memory) {
    uint jobCount = totalJobs;
    uint length;
    for(uint i = 1; i <= jobCount; i++ ){
        if(allJobs[i].state == jobState.PENDING){
            length++;
        }
    }

    Job[]memory allPendingJobs = new Job[](length);
    uint count;
    for(uint i = 1; i <= jobCount; i++ ){
        if(allJobs[i].state == jobState.PENDING){
        allPendingJobs[count] = allJobs[i];
        count++ ;
        }
    }

    return allPendingJobs;

}

function getApprovedJobs() external view returns(Job[] memory) {
    uint jobCount = totalJobs;
    uint length;
    for(uint i = 1; i <= jobCount; i++ ){
        if((allJobs[i].state == jobState.APPROVED) && (allJobs[i].funded == false)){
            length++;
        }
    }

    Job[]memory allApprovedJobs = new Job[](length);
    uint count;
    for(uint i = 1; i <= jobCount; i++ ){
        if((allJobs[i].state == jobState.APPROVED) && (allJobs[i].funded == false)){
        allApprovedJobs[count] = allJobs[i];
        count++ ;
        }
    }

    return allApprovedJobs;

}

function getFundedJobs() external view returns(Job[] memory) {
    uint jobCount = totalJobs;
    uint length;
    for(uint i = 1; i <= jobCount; i++ ){
        if( (allJobs[i].funded == true) 
        && (allJobs[i].dev == address(0)) ){
            length++;
        }
    }

    Job[]memory allFundedJobs = new Job[](length);
    uint count;
    for(uint i = 1; i <= jobCount; i++ ){
        if( (allJobs[i].funded == true) 
        && (allJobs[i].dev == address(0)) ){
        allFundedJobs[count] = allJobs[i];
        count++ ;
        }
    }

    return allFundedJobs;

}

function getStartedJobs() external view returns(Job[] memory) {
    uint jobCount = totalJobs;
    uint length;
    for(uint i = 1; i <= jobCount; i++ ){
        if((allJobs[i].state == jobState.APPROVED) 
        && (allJobs[i].dev != address(0)) ){
            length++;
        }
    }

    Job[]memory allStartedJobs = new Job[](length);
    uint count;
    for(uint i = 1; i <= jobCount; i++ ){
        if((allJobs[i].state == jobState.APPROVED) 
        && (allJobs[i].dev != address(0)) ){
        allStartedJobs[count] = allJobs[i];
        count++ ;
        }
    }

    return allStartedJobs;

}

function getCompletedJobs() external view returns(Job[] memory) {
    uint jobCount = totalJobs;
    uint length;
    for(uint i = 1; i <= jobCount; i++ ){
        if((allJobs[i].state == jobState.COMPLETED)){
            length++;
        }
    }

    Job[]memory allCompletedJobs = new Job[](length);
    uint count;
    for(uint i = 1; i <= jobCount; i++ ){
        if((allJobs[i].state == jobState.COMPLETED)){
        allCompletedJobs[count] = allJobs[i];
        count++ ;
        }
    }

    return allCompletedJobs;

}
}