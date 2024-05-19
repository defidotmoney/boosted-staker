// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.25;

import { BoostedStaker } from "./BoostedStaker.sol";
import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
    @notice Boosted Staker Factory
    @author Yearn (with edits by defidotmoney)
 */
contract StakerFactory is Ownable2Step {
    uint256 public immutable EPOCH_DAYS;
    uint256 public immutable STAKE_GROWTH_EPOCHS;
    uint256 public immutable START_TIME;

    mapping(address token => address staker) public boostedStakers;

    constructor(uint256 epochDays, uint256 stakeGrowthEpochs) Ownable(msg.sender) {
        require(stakeGrowthEpochs > 0 && stakeGrowthEpochs < 16, "Invalid STAKE_GROWTH_EPOCHS");

        EPOCH_DAYS = epochDays;
        STAKE_GROWTH_EPOCHS = stakeGrowthEpochs;

        // ensure start time is at 12:00 UTC
        uint256 startTime = (block.timestamp / 1 days) * 1 days;
        if (block.timestamp >= startTime + 12 hours) startTime += 12 hours;
        else startTime -= 12 hours;
        START_TIME = startTime;
    }

    /**
        @notice Deploy a new `BoostedStaker` contract
        @dev We use CREATE2 to generate deterministic deployments based on `token`
    */
    function deployBoostedStaker(address token, uint maxWeightMultiplier) external onlyOwner returns (address) {
        require(boostedStakers[token] == address(0), "Already deployed for this token");
        require(maxWeightMultiplier > 1 && maxWeightMultiplier < 256, "Invalid MAX_WEIGHT_MULTIPLIER");

        uint256 salt = uint256(uint160(token));
        bytes memory bytecodeWithArgs = abi.encodePacked(
            type(BoostedStaker).creationCode,
            abi.encode(token, STAKE_GROWTH_EPOCHS, maxWeightMultiplier, START_TIME, EPOCH_DAYS)
        );

        address deployedAddress;
        assembly {
            deployedAddress := create2(0, add(bytecodeWithArgs, 0x20), mload(bytecodeWithArgs), salt)
        }
        require(deployedAddress != address(0), "Failed to deploy contract");

        boostedStakers[token] = deployedAddress;
        return deployedAddress;
    }
}
