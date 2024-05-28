// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_Constructor_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////

    function test_RevertWhen_Stake_Because_Amount_IsZero() public {
        vm.expectRevert("DFM:BS Cannot stake 0");
        staker.stake(address(0), 0);
    }

    function test_RevertWhen_Stake_Because_Amount_IsTooHigh() public {
        vm.expectRevert("DFM:BS Amount too large");
        staker.stake(address(0), type(uint112).max);
    }

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    /// @notice Test Stake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - No previous position, first interaction with the contract
    function test_Stake_When_NoPreviousPosition_() public timejump(EPOCH_LENGHT) {
        // Assertions before
        // Not needed as no interaction with the contract

        deal(address(token), address(this), DEFAULT_AMOUNT);

        uint256 epoch = 1;
        uint256 realizeEpoch = epoch + staker.STAKE_GROWTH_EPOCHS();

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(this), address(staker), DEFAULT_AMOUNT);
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Staked(address(this), epoch, DEFAULT_AMOUNT, DEFAULT_AMOUNT, DEFAULT_AMOUNT, false);

        // Main call
        staker.stake(address(this), DEFAULT_AMOUNT);

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), epoch);
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), DEFAULT_AMOUNT);
        assertEq(staker.getAccEpochToRealizePendingBSR(address(this), realizeEpoch), DEFAULT_AMOUNT);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), DEFAULT_AMOUNT);
        assertEq(staker.globalEpochToRealize(realizeEpoch), DEFAULT_AMOUNT);
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccountWeight(address(this)), DEFAULT_AMOUNT);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(accountView.weight, DEFAULT_AMOUNT);
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 1);
        assertEq(futur[0].epochsToMaturity, 7);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch));
        assertEq(futur[0].pendingStake, DEFAULT_AMOUNT);
        assertEq(futur[0].lockedStake, 0);
        assertEq(staker.getGlobalWeight(), DEFAULT_AMOUNT);
    }

    /// @notice Test Stake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User Stake DEFAULT_AMOUNT
    /// - User Stake DEFAULT_AMOUNT again,
    /// -> It aims to check that EpochToRealized(acccount/global) are x2ed
    function test_Stake_When_AlreadyStakeInSameEpoch()
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
        // Not needed as exact same as end of previous test

        deal(address(token), address(this), DEFAULT_AMOUNT);

        uint256 epoch = 1;
        uint256 realizeEpoch = epoch + staker.STAKE_GROWTH_EPOCHS();
        uint256 newWeight = DEFAULT_AMOUNT * 2;

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(this), address(staker), DEFAULT_AMOUNT);
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Staked(address(this), epoch, DEFAULT_AMOUNT, newWeight, DEFAULT_AMOUNT, false);

        // Main call
        staker.stake(address(this), DEFAULT_AMOUNT);

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), epoch);
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), DEFAULT_AMOUNT * 2);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), newWeight);
        assertEq(staker.getAccEpochToRealizePendingBSR(address(this), realizeEpoch), DEFAULT_AMOUNT * 2);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), newWeight);
        assertEq(staker.globalEpochToRealize(realizeEpoch), DEFAULT_AMOUNT * 2);
        assertEq(staker.globalGrowthRate(), newWeight);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT * 2);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT * 2);
        assertEq(staker.getAccountWeight(address(this)), newWeight);
        assertEq(accountView.balance, DEFAULT_AMOUNT * 2);
        assertEq(accountView.weight, newWeight);
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT * 2);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 1);
        assertEq(futur[0].epochsToMaturity, 7);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch));
        assertEq(futur[0].pendingStake, DEFAULT_AMOUNT * 2);
        assertEq(futur[0].lockedStake, 0);
        assertEq(staker.getGlobalWeight(), newWeight);
    }

    /// @notice Test Stake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User Stake DEFAULT_AMOUNT
    /// - User Stake DEFAULT_AMOUNT again after 4 epochs,
    function test_Stake_When_WithPreviousPosition_IsNotRealized()
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
        // Not needed as exact same as end of previous test

        deal(address(token), address(this), DEFAULT_AMOUNT);

        uint256 weightGrowth = DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS;
        assertEq(weightGrowth, 2e18 / uint256(7), "Wrong calculation for weight growth");

        uint256 epochToSkip = 4;
        uint256 epoch = 5;
        uint256 realizeEpoch = epoch + staker.STAKE_GROWTH_EPOCHS();
        uint256 newWeight = DEFAULT_AMOUNT + weightGrowth * epochToSkip + DEFAULT_AMOUNT;

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(this), address(staker), DEFAULT_AMOUNT);
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Staked(address(this), epoch, DEFAULT_AMOUNT, newWeight, DEFAULT_AMOUNT, false);

        // Skip to epoch
        skip(EPOCH_LENGHT * epochToSkip);

        // Main call
        staker.stake(address(this), DEFAULT_AMOUNT);

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), epoch);
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), DEFAULT_AMOUNT * 2);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), epochToSkip));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), newWeight);
        assertEq(staker.getAccEpochToRealizePendingBSR(address(this), realizeEpoch), DEFAULT_AMOUNT);
        assertEq(staker.getAccEpochToRealizePendingBSR(address(this), realizeEpoch - epochToSkip), DEFAULT_AMOUNT); // Check previous too
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), newWeight);
        assertEq(staker.globalEpochToRealize(realizeEpoch), DEFAULT_AMOUNT);
        assertEq(staker.globalEpochToRealize(realizeEpoch - epochToSkip), DEFAULT_AMOUNT); // Check previous too
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT * 2); // As no position realised
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT * 2);
        // Check previous epochs
        for (uint256 i; i < epochToSkip; i++) {
            assertEq(
                staker.getAccEpochWeightBSR(address(this), epoch - epochToSkip + i), DEFAULT_AMOUNT + weightGrowth * i
            );
            assertEq(staker.getGlobalEpochWeightsBSR(epoch - epochToSkip + i), DEFAULT_AMOUNT + weightGrowth * i);
        }
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT * 2);
        assertEq(staker.getAccountWeight(address(this)), newWeight);
        assertEq(accountView.balance, DEFAULT_AMOUNT * 2);
        assertEq(accountView.weight, newWeight);
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT * 2);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 2);
        assertEq(futur[0].epochsToMaturity, 3);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * (realizeEpoch - epochToSkip)));
        assertEq(futur[0].pendingStake, DEFAULT_AMOUNT);
        assertEq(futur[0].lockedStake, 0);
        assertEq(futur[1].epochsToMaturity, 7);
        assertEq(futur[1].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch));
        assertEq(futur[1].pendingStake, DEFAULT_AMOUNT);
        assertEq(futur[1].lockedStake, 0);
        assertEq(staker.getGlobalWeight(), newWeight);
    }

    /// @notice Test Stake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User Stake DEFAULT_AMOUNT
    /// - User Stake DEFAULT_AMOUNT again after 8 epochs
    /// -> It aims to check that the previous position is realised
    function test_Stake_When_WithPreviousPosition_IsRealised()
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
        // Not needed as exact same as end of previous test

        deal(address(token), address(this), DEFAULT_AMOUNT);

        uint256 weightGrowth = DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS;
        assertEq(weightGrowth, 2e18 / uint256(7), "Wrong calculation for weight growth");

        uint256 epochToSkip = STAKE_GROWTH_EPOCHS + 1;
        uint256 epoch = 9;
        uint256 realizeEpoch = epoch + staker.STAKE_GROWTH_EPOCHS();
        uint256 newWeight = DEFAULT_AMOUNT + weightGrowth * STAKE_GROWTH_EPOCHS + DEFAULT_AMOUNT;

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(this), address(staker), DEFAULT_AMOUNT);
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Staked(address(this), epoch, DEFAULT_AMOUNT, newWeight, DEFAULT_AMOUNT, false);

        // Skip to epoch
        skip(EPOCH_LENGHT * epochToSkip);
        staker.stake(address(this), DEFAULT_AMOUNT);

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), epoch);
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccRealizedStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        for (uint256 i = 1; i < STAKE_GROWTH_EPOCHS; i++) {
            assertFalse(staker.getAccUpdateEpochBitmapBSR(address(this), i));
            // Bitmap only for the first bit, as the rest are realised thus kicked out from the bitmap scope
        }
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), newWeight);
        assertEq(staker.getAccEpochToRealizePendingBSR(address(this), realizeEpoch), DEFAULT_AMOUNT);
        // Previous epochs are realised, but should remain in the mapping
        assertEq(staker.getAccEpochToRealizePendingBSR(address(this), realizeEpoch - epochToSkip), DEFAULT_AMOUNT);
        // Global data
        assertEq(staker.globalEpochToRealize(realizeEpoch), DEFAULT_AMOUNT);
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), newWeight);
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT * 2);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT * 2);
        assertEq(staker.getAccountWeight(address(this)), newWeight);
        assertEq(accountView.balance, DEFAULT_AMOUNT * 2);
        assertEq(accountView.weight, newWeight);
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT);
        assertEq(accountView.realizedStake, DEFAULT_AMOUNT);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 1);
        assertEq(futur[0].epochsToMaturity, 7);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch));
        assertEq(futur[0].pendingStake, DEFAULT_AMOUNT);
        assertEq(futur[0].lockedStake, 0);
        assertEq(staker.getGlobalWeight(), newWeight);
    }

    /// @notice Test Stake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User stake DEFAULT_AMOUNT for someone else
    /// -> It aims to check that the stake is done for someone else
    function test_Stake_When_StakeForSomeoneElse() public timejump(EPOCH_LENGHT) {
        deal(address(token), address(this), DEFAULT_AMOUNT);

        uint256 epoch = 1;

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(this), address(staker), DEFAULT_AMOUNT);
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Staked(alice, epoch, DEFAULT_AMOUNT, DEFAULT_AMOUNT, DEFAULT_AMOUNT, false);

        // Main call
        staker.stake(alice, DEFAULT_AMOUNT);

        // Assertions after
        (BoostedStaker.AccountView memory accountView,) = staker.getAccountFullView(alice);
        assertEq(staker.getEpoch(), epoch);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(accountView.weight, DEFAULT_AMOUNT);
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(staker.balanceOf(alice), DEFAULT_AMOUNT);
    }

    /// @notice Test Stake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - User Stake DEFAULT_AMOUNT
    /// - Alice Stake DEFAULT_AMOUNT
    /// -> It aims to check that the global data is updated correctly
    function test_Stake_When_2Users()
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
        deal(address(token), address(this), DEFAULT_AMOUNT);

        uint256 epoch = 1;
        uint256 realizeEpoch = epoch + staker.STAKE_GROWTH_EPOCHS();
        uint256 newWeight = DEFAULT_AMOUNT * 2;

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(this), address(staker), DEFAULT_AMOUNT);
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Staked(alice, epoch, DEFAULT_AMOUNT, DEFAULT_AMOUNT, DEFAULT_AMOUNT, false);

        // Main call
        staker.stake(alice, DEFAULT_AMOUNT);

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(alice);
        assertEq(staker.getEpoch(), epoch);
        // Account data
        assertEq(staker.getAccPendingStakeBSR(alice), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(alice), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(alice, 0));
        assertEq(staker.getAccEpochWeightBSR(alice, epoch), DEFAULT_AMOUNT);
        assertEq(staker.getAccEpochToRealizePendingBSR(alice, realizeEpoch), DEFAULT_AMOUNT);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), newWeight);
        assertEq(staker.globalEpochToRealize(realizeEpoch), DEFAULT_AMOUNT * 2);
        assertEq(staker.globalGrowthRate(), newWeight);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT * 2);
        // Views
        assertEq(staker.balanceOf(alice), DEFAULT_AMOUNT);
        assertEq(staker.getAccountWeight(alice), DEFAULT_AMOUNT);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(accountView.weight, DEFAULT_AMOUNT);
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, 0);
        assertEq(futur.length, 1);
        assertEq(futur[0].epochsToMaturity, 7);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch));
        assertEq(futur[0].pendingStake, DEFAULT_AMOUNT);
        assertEq(futur[0].lockedStake, 0);
        assertEq(staker.getGlobalWeight(), newWeight);
    }
}
