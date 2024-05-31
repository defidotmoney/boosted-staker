// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BoostedStaker} from "../../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_Unstake_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////

    function test_RevertWhen_Unstake_Because_AmountNull() public {
        vm.expectRevert("DFM:BS Cannot unstake 0");
        staker.unstake(address(this), 0, address(this));
    }

    function test_RevertWhen_UnstakeBecause_UnApprovedUnstaker() public {
        vm.expectRevert("DFM:BS Not approved unstaker");
        staker.unstake(alice, 1, address(this));
    }

    function test_RevertWhen_Unstake_Because_InsufficientBalance() public {
        vm.expectRevert("DFM:BS Insufficient balance");
        staker.unstake(address(this), 1, address(this));
    }

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    /// @notice Test Unstake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User stake
    /// - User unstake full position, no timejump
    function test_Unstake_When_SingleStake_NoRealised_FullPosition_RightAfterFirstStake()
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
        uint256 epoch = 1;
        uint256 realizeEpoch = epoch + STAKE_GROWTH_EPOCHS;
        assertEq(staker.getEpoch(), epoch);
        uint256 weightToRemove = DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) * 0 / STAKE_GROWTH_EPOCHS;
        assertEq(staker.getAccountWeightAt(address(this), epoch), weightToRemove);

        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Unstaked(address(this), epoch, DEFAULT_AMOUNT, 0, weightToRemove);
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(staker), address(this), DEFAULT_AMOUNT);

        // Main call
        staker.unstake(address(this), DEFAULT_AMOUNT, address(this));

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertFalse(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), 0);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), realizeEpoch), 0);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), 0);
        assertEq(staker.globalEpochToRealize(epoch), 0);
        assertEq(staker.globalGrowthRate(), 0);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), 0);
        // Views
        assertEq(staker.balanceOf(address(this)), 0);
        assertEq(staker.getAccountWeight(address(this)), 0);
        assertEq(accountView.balance, 0);
        assertEq(accountView.weight, 0);
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 0);
        assertEq(staker.getGlobalWeight(), 0);
        assertEq(token.balanceOf(address(this)), DEFAULT_AMOUNT);
    }

    /// @notice Test Unstake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User stake
    /// - User unstake half position, no timejump
    /// -> Mostly checking that bitmap is not modified and weight/balance are divided by 2.s
    function test_Unstake_When_SingleStake_NoRealise_HalfPosition_RightAfterFirstStake()
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
        uint256 epoch = 1;
        uint256 epochToSkip = 0;
        uint256 realizeEpoch = epoch + STAKE_GROWTH_EPOCHS;
        assertEq(staker.getEpoch(), epoch);
        uint256 amountNeeded = DEFAULT_AMOUNT / 2;
        uint256 previousWeight =
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) * epochToSkip / STAKE_GROWTH_EPOCHS;
        uint256 weightToRemove =
            amountNeeded + amountNeeded * (MAX_WEIGHT_MULTIPLIER - 1) * epochToSkip / STAKE_GROWTH_EPOCHS;
        assertEq(staker.getAccountWeightAt(address(this), epoch) / 2, weightToRemove);
        assertEq(staker.getAccountWeightAt(address(this), epoch), previousWeight);

        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Unstaked(address(this), epoch, amountNeeded, previousWeight - weightToRemove, weightToRemove);
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(staker), address(this), amountNeeded);

        // Main call
        staker.unstake(address(this), amountNeeded, address(this));

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), DEFAULT_AMOUNT - amountNeeded);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), previousWeight - weightToRemove);
        assertEq(staker.getAccEpochToRealizePendingBSR(address(this), realizeEpoch), DEFAULT_AMOUNT - amountNeeded);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), previousWeight - weightToRemove);
        assertEq(staker.globalEpochToRealize(realizeEpoch), DEFAULT_AMOUNT - amountNeeded);
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT - amountNeeded);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT - amountNeeded);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT - amountNeeded);
        assertEq(staker.getAccountWeight(address(this)), previousWeight - weightToRemove);
        assertEq(accountView.balance, DEFAULT_AMOUNT - amountNeeded);
        assertEq(accountView.weight, previousWeight - weightToRemove);
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT - amountNeeded);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 1);
        assertEq(futur[0].epochsToMaturity, realizeEpoch - epoch);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch));
        assertEq(futur[0].pendingStake, DEFAULT_AMOUNT - amountNeeded);
        assertEq(futur[0].lockedStake, 0);
        assertEq(token.balanceOf(address(this)), amountNeeded);
    }

    /// @notice Test Unstake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User stake
    /// - Timejump 2 epochs
    /// - User unstake third of position
    function test_Unstake_When_SingleStake_NoRealise_ThirdOfPosition_2EpochAfterFirstStake()
        public
        stake(
            Modifier_Stake({
                skipBefore: EPOCH_LENGHT,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: 2 * EPOCH_LENGHT
            })
        )
    {
        uint256 epochToSkip = 2;
        uint256 epoch = 1 + epochToSkip;
        uint256 realizeEpoch = epoch + STAKE_GROWTH_EPOCHS;
        assertEq(staker.getEpoch(), epoch);
        uint256 amountNeeded = DEFAULT_AMOUNT / 3;
        uint256 previousWeight =
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) * epochToSkip / STAKE_GROWTH_EPOCHS;
        uint256 weightToRemove =
            amountNeeded + amountNeeded * (MAX_WEIGHT_MULTIPLIER - 1) * epochToSkip / STAKE_GROWTH_EPOCHS;

        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Unstaked(address(this), epoch, amountNeeded, previousWeight - weightToRemove, weightToRemove);
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(staker), address(this), amountNeeded);

        // Main call
        staker.unstake(address(this), amountNeeded, address(this));

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), DEFAULT_AMOUNT - amountNeeded);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), epochToSkip));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), previousWeight - weightToRemove);
        assertEq(
            staker.getAccEpochToRealizePendingBSR(address(this), realizeEpoch - epochToSkip),
            DEFAULT_AMOUNT - amountNeeded
        );
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), previousWeight - weightToRemove);
        assertEq(staker.globalEpochToRealize(realizeEpoch - epochToSkip), DEFAULT_AMOUNT - amountNeeded);
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT - amountNeeded);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT - amountNeeded);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT - amountNeeded);
        assertEq(staker.getAccountWeight(address(this)), previousWeight - weightToRemove);
        assertEq(accountView.balance, DEFAULT_AMOUNT - amountNeeded);
        assertEq(accountView.weight, previousWeight - weightToRemove);
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT - amountNeeded);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 1);
        assertEq(futur[0].epochsToMaturity, STAKE_GROWTH_EPOCHS - epochToSkip);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * (STAKE_GROWTH_EPOCHS + 1)));
        assertEq(futur[0].pendingStake, DEFAULT_AMOUNT - amountNeeded);
        assertEq(futur[0].lockedStake, 0);
        assertEq(token.balanceOf(address(this)), amountNeeded);
    }

    /// @notice Test Unstake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User stake 2 times
    /// - User unstake full position
    /// -> Mostly checking that bitmap is modified due to line 386
    function test_Unstake_When_MultiplePositions_NoRealise_FullPosition_NoLocked()
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
        uint256 epoch = 2;
        uint256 realizeEpoch = epoch + STAKE_GROWTH_EPOCHS;
        assertEq(staker.getEpoch(), epoch);
        uint256 amountNeeded = DEFAULT_AMOUNT * 2;
        uint256 weightToRemove = DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) * 1 / STAKE_GROWTH_EPOCHS
            + DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) * 0 / STAKE_GROWTH_EPOCHS;
        assertEq(staker.getAccountWeightAt(address(this), epoch), weightToRemove);

        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Unstaked(address(this), epoch, amountNeeded, 0, weightToRemove);
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(staker), address(this), amountNeeded);

        // Main call
        staker.unstake(address(this), amountNeeded, address(this));

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertFalse(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertFalse(staker.getAccUpdateEpochBitmapBSR(address(this), 1));
        assertFalse(staker.getAccUpdateEpochBitmapBSR(address(this), 2));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), 0);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), realizeEpoch - 1), 0);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), realizeEpoch), 0);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), 0);
        assertEq(staker.globalEpochToRealize(epoch), 0);
        assertEq(staker.globalGrowthRate(), 0);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), 0);
        // Views
        assertEq(staker.balanceOf(address(this)), 0);
        assertEq(staker.getAccountWeight(address(this)), 0);
        assertEq(accountView.balance, 0);
        assertEq(accountView.weight, 0);
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 0);
        assertEq(staker.getGlobalWeight(), 0);
        assertEq(token.balanceOf(address(this)), amountNeeded);
    }

    /// @notice Test Unstake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User stake 2 times
    /// - User lock third position
    /// - User unstake full position (lock excluded)
    /// -> Mostly checking that bitmap is not modified due to line 386
    function test_Unstake_When_MultiplePositions_NoRealise_FullPosition_WithLocked()
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
        stake(
            Modifier_Stake({
                skipBefore: EPOCH_LENGHT,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: 0
            })
        )
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: true, skipAfter: 0}))
    {
        uint256 epoch = 2;
        assertEq(staker.getEpoch(), epoch);
        uint256 realizeEpoch = epoch + STAKE_GROWTH_EPOCHS;
        uint256 amountNeeded = DEFAULT_AMOUNT * 2;
        uint256 weightBefore = DEFAULT_AMOUNT
            + (DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS) * STAKE_GROWTH_EPOCHS // Locked
            + DEFAULT_AMOUNT + (DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS) * 1 // Staked At epoch 1
            + DEFAULT_AMOUNT + (DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS) * 0; // Staked At epoch 2
        uint256 weightToRemove = DEFAULT_AMOUNT
            + (DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS) * 1 + DEFAULT_AMOUNT
            + (DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS) * 0;
        assertEq(staker.getAccountWeightAt(address(this), epoch), weightBefore);

        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Unstaked(address(this), epoch, amountNeeded, weightBefore - weightToRemove, weightToRemove);
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(staker), address(this), amountNeeded);

        // Main call
        staker.unstake(address(this), amountNeeded, address(this));

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0)); // True due to locked position
        assertFalse(staker.getAccUpdateEpochBitmapBSR(address(this), 1));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weightBefore - weightToRemove);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), realizeEpoch), DEFAULT_AMOUNT);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), realizeEpoch - 1), 0);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), weightBefore - weightToRemove);
        assertEq(staker.globalEpochToRealize(realizeEpoch), 0); // Lock are not count in global realized
        assertEq(staker.globalGrowthRate(), 0); // Only locked
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccountWeight(address(this)), weightBefore - weightToRemove);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(accountView.weight, weightBefore - weightToRemove);
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, DEFAULT_AMOUNT);
        assertEq(futur.length, 1);
        assertEq(futur[0].epochsToMaturity, STAKE_GROWTH_EPOCHS);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * (STAKE_GROWTH_EPOCHS + epoch)));
        assertEq(futur[0].pendingStake, 0);
        assertEq(futur[0].lockedStake, DEFAULT_AMOUNT);
        assertEq(staker.getGlobalWeight(), weightBefore - weightToRemove);
        assertEq(token.balanceOf(address(this)), amountNeeded);
    }

    /// @notice Test Unstake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User stake once
    /// - Timejump until stake growth period is over
    /// - User unstake full position as realized
    function test_Unstake_When_SinglePosition_FullRealized_FullPosition()
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
        uint256 epoch = 1 + STAKE_GROWTH_EPOCHS;
        assertEq(staker.getEpoch(), epoch);
        uint256 weightToRemove =
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS;
        assertEq(staker.getAccountWeightAt(address(this), epoch), weightToRemove);

        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Unstaked(address(this), epoch, DEFAULT_AMOUNT, 0, weightToRemove);
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(staker), address(this), DEFAULT_AMOUNT);

        // Main call
        staker.unstake(address(this), DEFAULT_AMOUNT, address(this));

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), 0);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertFalse(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 7));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), 0);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), epoch), 0);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), 0);
        assertEq(staker.globalEpochToRealize(epoch), DEFAULT_AMOUNT); // ToRealize doesn't decrease when realized decrease
        assertEq(staker.globalGrowthRate(), 0);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), 0);
        // Views
        assertEq(staker.balanceOf(address(this)), 0);
        assertEq(staker.getAccountWeight(address(this)), 0);
        assertEq(accountView.balance, 0);
        assertEq(accountView.weight, 0);
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 0);
        assertEq(staker.getGlobalWeight(), 0);
        assertEq(token.balanceOf(address(this)), DEFAULT_AMOUNT);
    }

    /// @notice Test Unstake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User stake once
    /// - Timejump until stake growth period is over
    /// - User unstake half position as realized
    function test_Unstake_When_SinglePosition_FullRealized_HalfPosition()
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
        uint256 epoch = 1 + STAKE_GROWTH_EPOCHS;
        assertEq(staker.getEpoch(), epoch);
        uint256 amountNeeded = DEFAULT_AMOUNT / 2;
        uint256 weightBefore =
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS;
        uint256 weightToRemove =
            amountNeeded + amountNeeded * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS;
        assertEq(staker.getAccountWeightAt(address(this), epoch), weightBefore);
        uint256 weightDiff = weightBefore - weightToRemove;

        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Unstaked(address(this), epoch, amountNeeded, weightDiff, weightToRemove);
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(staker), address(this), amountNeeded);

        // Main call
        staker.unstake(address(this), amountNeeded, address(this));

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), DEFAULT_AMOUNT - amountNeeded);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertFalse(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 7));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weightDiff);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), epoch), 0);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), weightDiff);
        assertEq(staker.globalEpochToRealize(epoch), DEFAULT_AMOUNT); // ToRealize doesn't decrease when realized decrease
        assertEq(staker.globalGrowthRate(), 0);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT - amountNeeded);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT - amountNeeded);
        assertEq(staker.getAccountWeight(address(this)), weightDiff);
        assertEq(accountView.balance, DEFAULT_AMOUNT - amountNeeded);
        assertEq(accountView.weight, weightDiff);
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.realizedStake, DEFAULT_AMOUNT - amountNeeded);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 0);
        assertEq(staker.getGlobalWeight(), weightDiff);
        assertEq(token.balanceOf(address(this)), amountNeeded);
    }

    /// @notice Test Unstake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User stake once
    /// - Timejump 4 epoch before stake growth period is over for 1st stake
    /// - User stake once again
    /// - Timejump 4 extra epoch, now stake growth period is over for 1st stake
    /// - User unstake 3/4 of position, 100% from pending, 50% from realized
    function test_Unstake_When_MultiplePosition_FullPending_PartRealized()
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
        stake(
            Modifier_Stake({
                skipBefore: EPOCH_LENGHT * (STAKE_GROWTH_EPOCHS - 4),
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * 4
            })
        )
    {
        uint256 epoch = 1 + STAKE_GROWTH_EPOCHS;
        assertEq(staker.getEpoch(), epoch);
        uint256 amountNeeded = DEFAULT_AMOUNT + DEFAULT_AMOUNT / 2; // 100% from pending, 50% from realized
        uint256 weightBefore = DEFAULT_AMOUNT
            + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS + DEFAULT_AMOUNT
            + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * 4;
        uint256 weightToRemoveA =
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * 4; // 100% from pending
        uint256 weightToRemoveB = (
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS
        ) / 2; // 50% from realized
        uint256 weightToRemove = weightToRemoveA + weightToRemoveB;
        uint256 weightDiff = weightBefore - weightToRemove;
        assertEq(staker.getAccountWeightAt(address(this), epoch), weightBefore);

        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Unstaked(address(this), epoch, amountNeeded, weightDiff, weightToRemove);
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(staker), address(this), amountNeeded);

        // Main call
        staker.unstake(address(this), amountNeeded, address(this));

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), 0);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), DEFAULT_AMOUNT / 2);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertFalse(staker.getAccUpdateEpochBitmapBSR(address(this), 4)); // No more pending
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 7)); // Still some realized
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weightDiff);
        assertEq(staker.getAccEpochToRealizePendingBSR(address(this), epoch + 4), 0);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), weightDiff);
        assertEq(staker.globalEpochToRealize(epoch), DEFAULT_AMOUNT); // ToRealize doesn't decrease when realized decrease
        assertEq(staker.globalGrowthRate(), 0);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT * 2 - amountNeeded);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT * 2 - amountNeeded);
        assertEq(staker.getAccountWeight(address(this)), weightDiff);
        assertEq(accountView.balance, DEFAULT_AMOUNT * 2 - amountNeeded);
        assertEq(accountView.weight, weightDiff);
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.realizedStake, DEFAULT_AMOUNT / 2);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 0);
        assertEq(staker.getGlobalWeight(), weightDiff);
        assertEq(token.balanceOf(address(this)), amountNeeded);
    }

    /// @notice Test Unstake under the following conditions:
    /// - User approve alice as unlocker
    /// - Timejump to next epoch to avoid false 0
    /// - User stake once
    /// - Alice unstake on the behalf of user
    function test_Unstake_When_ForSomeoneElse()
        public
        approveUnstaker(address(this), alice)
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
        vm.prank(alice);
        staker.unstake(address(this), DEFAULT_AMOUNT, address(this));

        // Assertions after
        assertEq(token.balanceOf(address(this)), DEFAULT_AMOUNT);
        // Only testing unstaking for someone else, no need to check other values, as already tested in tests above.
    }

    /// @notice Test Unstake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User stake once
    /// - User unstake full position and set alice as receiver
    function test_Unstake_When_ReceiverIsDifferentThanUser()
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
        staker.unstake(address(this), DEFAULT_AMOUNT, alice);

        // Assertions after
        assertEq((token.balanceOf(alice)), DEFAULT_AMOUNT);
        // Only testing unstaking with different receiver, no need to check other values, as already tested in tests above.
    }
}
