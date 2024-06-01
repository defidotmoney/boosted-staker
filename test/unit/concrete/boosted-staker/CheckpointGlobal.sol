// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_CheckpointGlobal_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    /// @notice Test checkpointGlobal under the following conditions:
    /// When no weight is added, epoch 0
    function test_CheckpointGlobal_When_WeightIsNull_Epoch0() public {
        // Assertions before
        assertEq(staker.globalLastUpdateEpoch(), 0);

        // Main call
        assertEq(staker.checkpointGlobal(), 0);

        // Assertions after
        assertEq(staker.globalLastUpdateEpoch(), 0);
    }

    /// @notice Test checkpointGlobal under the following conditions:
    /// - Timejump 1 epoch
    /// - No weight addedd
    function test_CheckpointGlobal_When_WeightIsNull_Epoch1() public timejump(EPOCH_LENGHT) {
        // Assertions before
        assertEq(staker.globalLastUpdateEpoch(), 0);

        // Main call
        assertEq(staker.checkpointGlobal(), 0);

        // Assertions after
        assertEq(staker.globalLastUpdateEpoch(), 1);
    }

    /// @notice Test checkpointGlobal under the following conditions:
    /// - Timejump 1 epoch
    /// - User stake
    /// - Timejump 1 epoch
    /// - Checkpoint global
    function test_CheckpointGlobal_When_NewWeightIsAdded_SingleEpochMissing()
        public
        stake(
            Modifier_Stake({
                skipBefore: EPOCH_LENGHT,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT
            })
        )
    {
        // Assertions before
        assertEq(staker.globalLastUpdateEpoch(), 1);
        assertEq(staker.getGlobalEpochWeightsBSR(0), 0);
        assertEq(staker.getGlobalEpochWeightsBSR(1), DEFAULT_AMOUNT);
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT);
        uint256 weightIncrease = (DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1)) / STAKE_GROWTH_EPOCHS;

        // Main call
        assertEq(staker.checkpointGlobal(), DEFAULT_AMOUNT + weightIncrease);

        // Assertions after
        assertEq(staker.globalLastUpdateEpoch(), 2);
        assertEq(staker.getGlobalEpochWeightsBSR(0), 0);
        assertEq(staker.getGlobalEpochWeightsBSR(1), DEFAULT_AMOUNT);
        assertEq(staker.getGlobalEpochWeightsBSR(2), DEFAULT_AMOUNT + weightIncrease);
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT);
    }

    /// @notice Test checkpointGlobal under the following conditions:
    /// - Timejump 1 epoch
    /// - User stake
    /// - Timejump 4 epoch
    /// - Checkpoint global
    function test_CheckpointGlobal_When_NewWeightIsAdded_MultiEpochMissing()
        public
        stake(
            Modifier_Stake({
                skipBefore: EPOCH_LENGHT,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: 0
            })
        )
    {
        // Assertions before
        assertEq(staker.globalLastUpdateEpoch(), 1);
        assertEq(staker.getGlobalEpochWeightsBSR(0), 0);
        assertEq(staker.getGlobalEpochWeightsBSR(1), DEFAULT_AMOUNT);
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT);

        uint256 epochMissing = 4;
        uint256 weight =
            DEFAULT_AMOUNT + (((DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1)) / STAKE_GROWTH_EPOCHS) * epochMissing);

        skip(EPOCH_LENGHT * epochMissing);
        // Main call
        assertEq(staker.checkpointGlobal(), weight);

        // Assertions after
        assertEq(staker.globalLastUpdateEpoch(), 1 + epochMissing);
        assertEq(staker.getGlobalEpochWeightsBSR(0), 0);
        assertEq(staker.getGlobalEpochWeightsBSR(1), DEFAULT_AMOUNT);
        assertEq(
            staker.getGlobalEpochWeightsBSR(1 + 1),
            DEFAULT_AMOUNT + ((DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1)) / STAKE_GROWTH_EPOCHS) * 1
        );
        assertEq(
            staker.getGlobalEpochWeightsBSR(1 + 2),
            DEFAULT_AMOUNT + ((DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1)) / STAKE_GROWTH_EPOCHS) * 2
        );
        assertEq(
            staker.getGlobalEpochWeightsBSR(1 + 3),
            DEFAULT_AMOUNT + ((DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1)) / STAKE_GROWTH_EPOCHS) * 3
        );
        assertEq(
            staker.getGlobalEpochWeightsBSR(1 + epochMissing),
            DEFAULT_AMOUNT + ((DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1)) / STAKE_GROWTH_EPOCHS) * 4
        );
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT);
    }

    /// @notice Test checkpointGlobal under the following conditions:
    /// - Timejump 1 epoch
    /// - User stake
    /// - Timejump STAKE_GROWTH_EPOCHS epoch
    /// - Checkpoint global
    /// -> rate decrease because 1st stake is realised
    function test_CheckpointGlobal_When_RateDecrease()
        public
        stake(
            Modifier_Stake({
                skipBefore: EPOCH_LENGHT,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * (STAKE_GROWTH_EPOCHS)
            })
        )
    {
        // Assertions before
        assertEq(staker.globalLastUpdateEpoch(), 1);
        assertEq(staker.getGlobalEpochWeightsBSR(0), 0);
        assertEq(staker.getGlobalEpochWeightsBSR(1), DEFAULT_AMOUNT);
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT);

        uint256 weight =
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS;

        // Main call
        assertEq(staker.checkpointGlobal(), weight);

        // Assertions after
        assertEq(staker.globalLastUpdateEpoch(), staker.getEpoch());
        assertEq(staker.getGlobalEpochWeightsBSR(staker.getEpoch()), weight);
        assertEq(staker.globalGrowthRate(), 0);
    }
}
