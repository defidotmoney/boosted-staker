// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_GetAccountFullView_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    /// @notice Test getAccountFullView under the following conditions:
    /// - Pending and locked are null
    function test_GetAccountFullView_When_PendingAndLocked_AreNull_WeightNull() public view {
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futureRealizedStake) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), 0);
        assertEq(accountView.balance, 0);
        assertEq(accountView.weight, 0);
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(accountView.realizedStake, 0);
        assertEq(futureRealizedStake.length, 0);
    }

    /// @notice Test getAccountFullView under the following conditions:
    /// - Pending and locked are null, only realized stake
    function test_GetAccountFullView_When_PendingAndLocked_AreNull_WeightNotNull()
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
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futureRealizedStake) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), STAKE_GROWTH_EPOCHS);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(
            accountView.weight,
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS
        );
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(accountView.realizedStake, DEFAULT_AMOUNT);
        assertEq(futureRealizedStake.length, 0);
    }

    /// @notice Test getAccountFullView under the following conditions:
    /// - Pending and locked are null, lock just disabled
    /// - Previous lock should be considered as realized stake
    function test_GetAccountFullView_When_PendingAndLocked_AreNull_LockDisabled()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: true, skipAfter: 0}))
        disableLocks
    {
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futureRealizedStake) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), 0);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(
            accountView.weight,
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS
        );
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(accountView.realizedStake, DEFAULT_AMOUNT);
        assertEq(futureRealizedStake.length, 0);
    }

    /// @notice Test getAccountFullView under the following conditions:
    /// - User stake
    /// - No Timejump
    /// - Account up to date
    /// - Account has only stake
    function test_GetAccountFullView_When_AccountUpToDate_WithStakeOnly()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: false, skipAfter: 0}))
    {
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futureRealizedStake) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), 0);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(accountView.weight, DEFAULT_AMOUNT);
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT);
        assertEq(accountView.lockedStake, 0);
        assertEq(accountView.realizedStake, 0);
        assertEq(futureRealizedStake.length, 1);
        assertEq(futureRealizedStake[0].epochsToMaturity, STAKE_GROWTH_EPOCHS);
        assertEq(futureRealizedStake[0].timestampAtMaturity, staker.START_TIME() + EPOCH_LENGHT * STAKE_GROWTH_EPOCHS);
        assertEq(futureRealizedStake[0].pendingStake, DEFAULT_AMOUNT);
        assertEq(futureRealizedStake[0].lockedStake, 0);
    }

    /// @notice Test getAccountFullView under the following conditions:
    /// - User lock
    /// - No Timejump
    /// - Account up to date
    /// - Account has only lock
    function test_GetAccountFullView_When_AccountUpToDate_WithLocksOnly()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: true, skipAfter: 0}))
    {
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futureRealizedStake) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), 0);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(
            accountView.weight,
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS
        );
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.lockedStake, DEFAULT_AMOUNT);
        assertEq(accountView.realizedStake, 0);
        assertEq(futureRealizedStake.length, 1);
        assertEq(futureRealizedStake[0].epochsToMaturity, STAKE_GROWTH_EPOCHS);
        assertEq(futureRealizedStake[0].timestampAtMaturity, staker.START_TIME() + EPOCH_LENGHT * STAKE_GROWTH_EPOCHS);
        assertEq(futureRealizedStake[0].pendingStake, 0);
        assertEq(futureRealizedStake[0].lockedStake, DEFAULT_AMOUNT);
    }

    /// @notice Test getAccountFullView under the following conditions:
    /// - User stake and lock
    /// - No Timejump
    /// - Account up to date
    /// - Account has stake and lock
    function test_GetAccountFullView_When_AccountUpToDate_WithLocksAndStake()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: true, skipAfter: 0}))
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: false, skipAfter: 0}))
    {
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futureRealizedStake) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), 0);
        assertEq(accountView.balance, DEFAULT_AMOUNT * 2);
        assertEq(
            accountView.weight,
            DEFAULT_AMOUNT + (DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS) * STAKE_GROWTH_EPOCHS // locked
                + DEFAULT_AMOUNT // pending
        );
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT);
        assertEq(accountView.lockedStake, DEFAULT_AMOUNT);
        assertEq(accountView.realizedStake, 0);
        assertEq(futureRealizedStake.length, 1);
        assertEq(futureRealizedStake[0].epochsToMaturity, STAKE_GROWTH_EPOCHS);
        assertEq(futureRealizedStake[0].timestampAtMaturity, staker.START_TIME() + EPOCH_LENGHT * STAKE_GROWTH_EPOCHS);
        assertEq(futureRealizedStake[0].pendingStake, DEFAULT_AMOUNT);
        assertEq(futureRealizedStake[0].lockedStake, DEFAULT_AMOUNT);
    }

    /// @notice Test getAccountFullView under the following conditions:
    /// - User stake
    /// - Timejump 1 epoch
    /// - Account not up to date, but no realization happened
    function test_GetAccountFullView_When_AccountNotUpToDate_WithoutRealization()
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
    {
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futureRealizedStake) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), 1);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(
            accountView.weight, DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS
        );
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT);
        assertEq(accountView.lockedStake, 0);
        assertEq(accountView.realizedStake, 0);
        assertEq(futureRealizedStake.length, 1);
        assertEq(futureRealizedStake[0].epochsToMaturity, STAKE_GROWTH_EPOCHS - 1);
        assertEq(futureRealizedStake[0].timestampAtMaturity, staker.START_TIME() + EPOCH_LENGHT * STAKE_GROWTH_EPOCHS);
        assertEq(futureRealizedStake[0].pendingStake, DEFAULT_AMOUNT);
        assertEq(futureRealizedStake[0].lockedStake, 0);
    }

    /// @notice Test getAccountFullView under the following conditions:
    /// - User stake
    /// - Timejump STAKE_GROWTH_EPOCHS epoch
    /// - Account not up to date and stake getting realized
    function test_GetAccountFullView_When_AccountNotUpToDate_WithRealizationForPending()
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
    {
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futureRealizedStake) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), STAKE_GROWTH_EPOCHS);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(
            accountView.weight,
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS
        );
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(accountView.realizedStake, DEFAULT_AMOUNT);
        assertEq(futureRealizedStake.length, 0); // No future realized stake as already realized
    }

    /// @notice Test getAccountFullView under the following conditions:
    /// - User lock
    /// - Timejump STAKE_GROWTH_EPOCHS epoch
    /// - Account not up to date and lock getting realized
    function test_GetAccountFullView_When_AccountNotUpToDate_WithRealizationForLocked()
        public
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: true,
                skipAfter: EPOCH_LENGHT * STAKE_GROWTH_EPOCHS
            })
        )
    {
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futureRealizedStake) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), STAKE_GROWTH_EPOCHS);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(
            accountView.weight,
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS
        );
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(accountView.realizedStake, DEFAULT_AMOUNT);
        assertEq(futureRealizedStake.length, 0); // No future realized stake as already realized
    }

    /// @notice Test getAccountFullView under the following conditions:
    /// - User stake
    /// - Timejump 4 epochs
    /// - User stake again
    /// - Timejump 6 epochs
    /// - Account not up to date, 1st stake getting realized, 2nd stake still pending.
    /// -> This test target to not trigger the "break" statement at the end of the first while loop
    function test_GetAccountFullView_When_AccountNotUpToDate_WithRealization_MutliplePositions()
        public
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * 4
            })
        )
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * 6
            })
        )
    {
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futureRealizedStake) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), 10);
        assertEq(accountView.balance, DEFAULT_AMOUNT * 2);
        assertEq(
            accountView.weight,
            DEFAULT_AMOUNT + (DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS) * STAKE_GROWTH_EPOCHS // 1st stake realized
                + DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * 6 // 2nd stake realized
        );
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT);
        assertEq(accountView.lockedStake, 0);
        assertEq(accountView.realizedStake, DEFAULT_AMOUNT);
        assertEq(futureRealizedStake.length, 1);
        assertEq(futureRealizedStake[0].epochsToMaturity, STAKE_GROWTH_EPOCHS - 6);
        assertEq(futureRealizedStake[0].timestampAtMaturity, staker.START_TIME() + EPOCH_LENGHT * 11);
        assertEq(futureRealizedStake[0].pendingStake, DEFAULT_AMOUNT);
        assertEq(futureRealizedStake[0].lockedStake, 0);
    }
}
