// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakerFactory} from "../../../../../contracts/Factory.sol";
import {DeploymentParams as DP} from "../../../utils/DeploymentParameters.sol";

contract Unit_Concrete_Factory_Constructor_Tests is Unit_Shared_Tests_ {
    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////
    function test_RevertWhen_Constructor_Because_STAKE_GROWTH_EPOCHS_IsNull() public {
        vm.expectRevert("DFM:BSF STAKE_GROWTH_EPOCHS");
        new StakerFactory(0, 0);
    }

    function test_RevertWhen_Constructor_Because_STAKE_GROWTH_EPOCHS_IsAbove16() public {
        vm.expectRevert("DFM:BSF STAKE_GROWTH_EPOCHS");
        new StakerFactory(0, 17);
    }

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    function test_Factory_Constructor_Morning() public {
        uint256 epochDays = 7;
        uint256 stakeGrowthEpochs = 10;

        factory = new StakerFactory(epochDays, stakeGrowthEpochs);

        // Assertions
        assertEq(factory.EPOCH_DAYS(), epochDays);
        assertEq(factory.STAKE_GROWTH_EPOCHS(), stakeGrowthEpochs);
        assertEq(factory.START_TIME(), (block.timestamp / 1 days) * 1 days - 12 hours);
        assertTrue(factory.isLockingEnabled());
    }

    function test_Factory_Constructor_Afternoon() public timejump(12 hours) {
        uint256 epochDays = 7;
        uint256 stakeGrowthEpochs = 10;

        factory = new StakerFactory(epochDays, stakeGrowthEpochs);

        // Assertions
        assertEq(factory.EPOCH_DAYS(), epochDays);
        assertEq(factory.STAKE_GROWTH_EPOCHS(), stakeGrowthEpochs);
        assertEq(factory.START_TIME(), (block.timestamp / 1 days) * 1 days + 12 hours);
        assertTrue(factory.isLockingEnabled());
    }
}
