// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DolphinReserveVesting is ReentrancyGuard {
    IERC20 public immutable token;
    address public immutable beneficiary;

    uint256 public immutable startTime;
    uint256 public immutable cliffDuration;
    uint256 public immutable vestingDuration;
    uint256 public immutable totalAmount;

    uint256 public released;

    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor(
        address _token,
        address _beneficiary,
        uint256 _startTime,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        uint256 _totalAmount
    ) {
        require(_token != address(0), "Invalid token");
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_startTime >= block.timestamp, "Start time in past");
        require(_cliffDuration > 0, "Invalid cliff");
        require(_vestingDuration > 0, "Invalid vesting");
        require(_totalAmount > 0, "Invalid amount");

        token = IERC20(_token);
        beneficiary = _beneficiary;
        startTime = _startTime;
        cliffDuration = _cliffDuration;
        vestingDuration = _vestingDuration;
        totalAmount = _totalAmount;
    }

    function cliffEndTime() public view returns (uint256) {
        return startTime + cliffDuration;
    }

    function vestingEndTime() public view returns (uint256) {
        return startTime + cliffDuration + vestingDuration;
    }

    function vestedAmount() public view returns (uint256) {
        if (block.timestamp < cliffEndTime()) {
            return 0;
        }

        if (block.timestamp >= vestingEndTime()) {
            return totalAmount;
        }

        uint256 elapsed = block.timestamp - cliffEndTime();
        return (totalAmount * elapsed) / vestingDuration;
    }

    function releasableAmount() public view returns (uint256) {
        return vestedAmount() - released;
    }

    function release() external nonReentrant {
        uint256 amount = releasableAmount();
        require(amount > 0, "No tokens to release");

        released += amount;

        bool success = token.transfer(beneficiary, amount);
        require(success, "Transfer failed");

        emit TokensReleased(beneficiary, amount);
    }
}