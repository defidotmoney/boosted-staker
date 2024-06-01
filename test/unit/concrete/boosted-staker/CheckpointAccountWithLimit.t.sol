// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_CheckpointAccountWithLimit_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    /// @notice Test checkpointAccountWithLimit under the following conditions:
    /// - Skip 1 epoch
    /// - Checkpoint account with limit 2, rounded to 1
    function test_CheckpointAccountWithLimit_WhenEpochIsHigherThanCurrentEpoch() public {
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 0);

        skip(EPOCH_LENGTH);
        assertEq(staker.checkpointAccountWithLimit(address(this), 2), 0);

        assertEq(staker.getEpoch(), 1);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 1);
    }

    /// @notice Test checkpointAccountWithLimit under the following conditions:
    /// - Skip 1 epoch
    /// - Checkpoint account with limit 1, rounded to 1
    function test_CheckpointAccountWithLimit_WhenEpochIsEqualToCurrentEpoch() public {
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 0);

        skip(EPOCH_LENGTH);
        assertEq(staker.checkpointAccountWithLimit(address(this), 1), 0);

        assertEq(staker.getEpoch(), 1);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 1);
    }

    /// @notice Test checkpointAccountWithLimit under the following conditions:
    /// - Skip 2 epochs
    /// - Checkpoint account with limit 1
    function test_CheckpointAccountWithLimit_WhenEpochIsLowerThanCurrentEpoch() public {
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 0);

        skip(EPOCH_LENGTH * 2);
        assertEq(staker.checkpointAccountWithLimit(address(this), 1), 0);

        assertEq(staker.getEpoch(), 2);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 1);
    }
}
