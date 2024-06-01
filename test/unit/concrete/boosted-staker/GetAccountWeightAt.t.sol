// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_GetAccountWeightAt_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    /// @notice Test getAccountWeightAt under the following conditions:
    /// - Epoch asked is higher than current epoch
    function test_GetAccountWeightAt_When_EpochIsHigherThanCurrentEpoch() public view {
        assertEq(staker.getEpoch(), 0);
        assertEq(staker.getAccountWeightAt(address(this), 1), 0);
    }

    /// @notice Test getAccountWeightAt under the following conditions:
    /// - User stake
    /// - Epoch asked is equal to last update epoch, 1 in this case
    function test_GetAccountWeightAt_When_EpochIsEqualToLastUpdateEpoch()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: false, skipAfter: 0}))
    {
        // Assertions before
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 0);
        assertEq(staker.getEpoch(), 0);

        assertEq(staker.getAccountWeightAt(address(this), 0), DEFAULT_AMOUNT);
    }

    /// @notice Test getAccountWeightAt under the following conditions:
    /// - User stake
    /// - Epoch asked is lower than last update epoch, current epoch is 1, asked epoch is 0
    function test_GetAccountWeightAt_When_EpochIsLowerToLastUpdateEpoch()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: false, skipAfter: 0}))
    {
        // Assertions before
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 0);
        assertEq(staker.getEpoch(), 0);

        skip(EPOCH_LENGHT);
        assertEq(staker.getEpoch(), 1);
        assertEq(staker.getAccountWeightAt(address(this), 0), DEFAULT_AMOUNT);
    }

    /// @notice Test getAccountWeightAt under the following conditions:
    /// - User lock
    /// - Timejump 1 epoch
    /// - Epoch asked is greater than last update epoch
    function test_GetAccountWeightAt_When_PendingIsNull()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: true, skipAfter: 0}))
    {
        // Assertions before
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 0);
        assertEq(staker.getEpoch(), 0);

        skip(EPOCH_LENGHT);
        assertEq(
            staker.getAccountWeightAt(address(this), 1),
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS
        );
    }

    /// @notice Test getAccountWeightAt under the following conditions:
    /// - User stake
    /// - Timejump 1 epoch
    /// - Epoch asked is greater than last update epoch, so it increase weight
    function test_GetAccountWeightAt_When_EpochIsLowerThanLastUpdate_BeforeRealized()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: false, skipAfter: 0}))
    {
        // Assertions before
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 0);
        assertEq(staker.getAccountWeight(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getEpoch(), 0);

        skip(EPOCH_LENGHT);
        assertEq(
            staker.getAccountWeightAt(address(this), 1),
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS
        );
    }

    /// @notice Test getAccountWeightAt under the following conditions:
    /// - User stake
    /// - Timejump 1 epoch
    /// - Epoch asked is greater than last update epoch, so it increase weight until pending is realized
    function test_GetAccountWeightAt_When_EpochIsLowerThanLastUpdate_AfterRealized_SingleLock()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: false, skipAfter: 0}))
    {
        // Assertions before
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 0);
        assertEq(staker.getAccountWeight(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getEpoch(), 0);

        skip(EPOCH_LENGHT * (STAKE_GROWTH_EPOCHS + 1));
        assertEq(staker.getAccountWeightAt(address(this), 0), DEFAULT_AMOUNT);
        assertEq(
            staker.getAccountWeightAt(address(this), 1),
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS
        );
        assertEq(
            staker.getAccountWeightAt(address(this), STAKE_GROWTH_EPOCHS + 1),
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS
        );
    }

    /// @notice Test getAccountWeightAt under the following conditions:
    /// - User stake
    /// - Timejump 1 epoch
    /// - User stake again
    /// - Timejump STAKE_GROWTH_EPOCHS epochs
    /// - Epoch asked is greater than last update epoch, so it increase weight until pending is realized
    /// for the first stake, and 2nd stake is still pending. The goal is to not trigger the break statement
    /// at the end of the while loop.
    function test_GetAccountWeightAt_When_EpochIsLowerThanLastUpdate_AfterRealized_MultipleLock()
        public
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT
            })
        )
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: false, skipAfter: 0}))
    {
        // Assertions before
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 1);
        assertEq(
            staker.getAccountWeight(address(this)),
            DEFAULT_AMOUNT + DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS
        );
        assertEq(staker.getEpoch(), 1);

        skip(EPOCH_LENGHT * STAKE_GROWTH_EPOCHS);
        assertEq(
            staker.getAccountWeightAt(address(this), 1),
            DEFAULT_AMOUNT + DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS
        );
        assertEq(
            staker.getAccountWeightAt(address(this), STAKE_GROWTH_EPOCHS),
            DEFAULT_AMOUNT
                + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * (STAKE_GROWTH_EPOCHS - 1) // 2nd stake
                + DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS // 1st stake fully realized
        );
    }
}
