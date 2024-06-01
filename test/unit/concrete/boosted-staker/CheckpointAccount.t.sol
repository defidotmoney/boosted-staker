// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_CheckpointAccount_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    /// @notice Test checkpointAccount under the following conditions:
    /// - Account has no stake
    function test_CheckpointAccount_When_UpToDate_NoPosition_Epoch0() public {
        assertEq(staker.checkpointAccount(address(this)), 0);
    }

    /// @notice Test checkpointAccount under the following conditions:
    /// - Account has no stake
    /// - Timejump 1 epoch
    function test_CheckPointAccount_When_UpToDate_NoPosition_Epoch1() public timejump(EPOCH_LENGHT) {
        assertEq(staker.getEpoch(), 1);
        assertEq(staker.checkpointAccount(address(this)), 0);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 1);
    }

    /// @notice Test checkpointAccount under the following conditions:
    /// - User stake
    /// - Timejump STAKE_GROWTH_EPOCHS epochs
    /// - Stake reach realization
    function test_CheckpointAccount_When_OnlyRealizedStake()
        public
        stake(
            Modifier_Stake({
                skipBefore: EPOCH_LENGHT,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * STAKE_GROWTH_EPOCHS
            })
        )
    {
        uint256 epoch = 8;
        assertEq(staker.getEpoch(), epoch);

        uint256 maxWeight =
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS;

        // Main call
        assertEq(staker.checkpointAccount(address(this)), maxWeight);

        // Assertions after
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), epoch - 1));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), maxWeight);
        assertEq(staker.getAccEpochToRealizePendingBSR(address(this), epoch), DEFAULT_AMOUNT); // Account Epoch To Realize is not decreased.
    }

    /// @notice Test checkpointAccount under the following conditions:
    /// - Timejump 1 epoch to avoid false 0
    /// - User stake
    /// - Timejump STAKE_GROWTH_EPOCHS - 4 epochs
    /// - User stake again
    /// - Timejump 4 epochs
    /// - 1st Stake reach realization, 2nd stake is pending
    function test_CheckpointAccount_When_RealizedAndPendingStake()
        public
        stake(
            Modifier_Stake({
                skipBefore: EPOCH_LENGHT,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * (STAKE_GROWTH_EPOCHS - 4)
            })
        )
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * 4
            })
        )
    {
        uint256 epoch = 8;
        assertEq(staker.getEpoch(), epoch);

        uint256 weight = DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * 4
            + DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS;

        // Main call
        assertEq(staker.checkpointAccount(address(this)), weight);

        // Assertions after
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), epoch - 1));
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), epoch - 4));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weight);
    }

    /// @notice Test checkpointAccount under the following conditions:
    /// - Timejump 1 epoch to avoid false 0
    /// - User lock
    /// - User stake
    /// - Timejump STAKE_GROWTH_EPOCHS - 4 epochs
    /// - User stake again
    /// - Timejump 4 epochs
    /// - 1st lock reach realization, 2nd stake too, 3rd stake is pending
    function test_CheckpointAccount_When_RealizedAndPendingAndLockedStake()
        public
        stake(
            Modifier_Stake({
                skipBefore: EPOCH_LENGHT,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: true,
                skipAfter: 0
            })
        )
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * (STAKE_GROWTH_EPOCHS - 4)
            })
        )
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * 4
            })
        )
    {
        uint256 epoch = 8;
        assertEq(staker.getEpoch(), epoch);

        uint256 weight = DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * 4 // Pending
            + 2
                * (DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS); // Realized + Locked

        // Main call
        assertEq(staker.checkpointAccount(address(this)), weight);

        // Assertions after
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), DEFAULT_AMOUNT); // 2st stake is pending
        assertEq(staker.getAccRealizedStakeBSR(address(this)), DEFAULT_AMOUNT * 2); // 1st Locked become realized, 1st stake too.
        assertEq(staker.getAccLockedStakeBSR(address(this)), 0);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), epoch - 1));
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), epoch - 4));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weight);
    }

    /// @notice Test checkpointAccount under the following conditions:
    /// - User stake
    /// - Timejump STAKE_GROWTH_EPOCHS + 2 epochs
    /// Testing the propogation of weight over epochs after StakeGrowthEpochs
    /// But weight is not increased anymore.
    function test_CheckpointAccount_When_EpochMissing_IsOver_StakeGrowthEpoch()
        public
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * (STAKE_GROWTH_EPOCHS + 2)
            })
        )
    {
        uint256 epoch = 9;
        assertEq(staker.getEpoch(), epoch);

        uint256 weight =
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS;

        // Main call
        assertEq(staker.checkpointAccount(address(this)), weight);

        // Assertions after
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), STAKE_GROWTH_EPOCHS)); // Bitmap is not pushed anymore after STAKE_GROWTH_EPOCHS.
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weight);
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch - 1), weight);
    }

    /// @notice Test checkpointAccount under the following conditions:
    /// - User stake
    /// - Timejump STAKE_GROWTH_EPOCHS epochs
    /// - Checkpoint account
    /// - Timejump 5 epochs
    /// - Checkpoint account
    /// Testing the propogation of weight over epochs due to realized stake
    function test_CheckpointAccount_When_PendingAndLocked_AreNull()
        public
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * STAKE_GROWTH_EPOCHS
            })
        )
        checkpointAccount(address(this))
    {
        uint256 epoch = 7;
        assertEq(staker.getEpoch(), epoch);

        // Assertions before
        assertEq(staker.getAccLockedStakeBSR(address(this)), 0);
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), epoch));

        uint256 weight =
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS;

        skip(5 * EPOCH_LENGHT);
        // Main call
        assertEq(staker.checkpointAccount(address(this)), weight);

        // Assertions after
        // Account data, nothing should have change except the weight and last update.
        assertEq(staker.getAccLockedStakeBSR(address(this)), 0);
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch + 5);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), epoch));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch + 5), weight);
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch + 4), weight);
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch + 3), weight);
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch + 2), weight);
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch + 1), weight);
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch + 0), weight);
    }

    /// @notice Test checkpointAccount under the following conditions:
    /// - User stake
    /// - Timejump STAKE_GROWTH_EPOCHS epochs
    /// - Checkpoint account
    /// - Timejump 5 epochs
    /// - Checkpoint account
    /// Testing the update of last update only.
    function test_CheckpointAccount_When_PendingLockedAndRealized_AreNull() public timejump(EPOCH_LENGHT) {
        assertEq(staker.checkpointAccount(address(this)), 0);

        // Account data
        assertEq(staker.getAccLockedStakeBSR(address(this)), 0);
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), 0);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 1);
        assertFalse(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
    }

    /// @notice Test checkpointAccount under the following conditions:
    /// - User lock
    /// - Disable locks
    /// - Checkpoint account
    /// Testing the lock being instantly realized.
    function test_CheckpointAccount_When_LockAreDisabled()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: true, skipAfter: 0}))
        disableLocks
    {
        // Assertions before
        assertEq(staker.getAccLockedStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), 0);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 0);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0));

        uint256 epoch = 0;
        assertEq(staker.getEpoch(), epoch);

        uint256 weight =
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS;

        // Main call
        assertEq(staker.checkpointAccount(address(this)), weight);

        // Assertions after
        // Account data
        assertEq(staker.getAccLockedStakeBSR(address(this)), 0);
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), epoch));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weight);
    }
}
