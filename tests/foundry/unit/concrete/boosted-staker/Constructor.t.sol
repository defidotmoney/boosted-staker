// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BoostedStaker} from "../../../../../contracts/BoostedStaker.sol";
import {DeploymentParams as DP} from "../../../utils/DeploymentParameters.sol";

contract Unit_Concrete_BoostedStaker_Constructor_Tests is Unit_Shared_Tests_ {
    //////////////////////////////////////////////////////
    /// --- TESTS
    //////////////////////////////////////////////////////

    function test_BoostedStaker_Constructor_() public {
        address token_ = makeAddr("Token to test");
        uint256 stakeGrowthEpochs = 10;
        uint256 maxWeightMultiplier = 8;
        uint256 startTime = block.timestamp;
        uint256 epochDays = 7;

        vm.prank(address(factory));
        staker = new BoostedStaker({
            token: IERC20(token_),
            stakeGrowthEpochs: stakeGrowthEpochs,
            maxWeightMultiplier: maxWeightMultiplier,
            startTime: startTime,
            epochDays: epochDays
        });

        // Assertions
        assertEq(address(staker.FACTORY()), address(factory));
        assertEq(address(staker.STAKE_TOKEN()), token_);
        assertEq(staker.STAKE_GROWTH_EPOCHS(), stakeGrowthEpochs);
        assertEq(staker.MAX_WEIGHT_MULTIPLIER(), maxWeightMultiplier);
        assertEq(staker.EPOCH_LENGTH(), epochDays * 1 days);
        assertEq(staker.START_TIME(), startTime);
    }
}
