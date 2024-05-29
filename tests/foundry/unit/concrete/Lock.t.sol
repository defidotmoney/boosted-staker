// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_Lock_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////

    function test_RevertWhen_Lock_Because_LocksAreDisabled() public {
        // Disable locks
        vm.prank(multisig);
        staker.disableLocks();

        // Main call
        vm.expectRevert("DFM:BS Locks are disabled");
        staker.lock(address(this), DEFAULT_AMOUNT);
    }

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    /// @notice Test Stake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - No previous position, first interaction with the contract
    function test_Lock_When_NoPreviousPosition_() public timejump(EPOCH_LENGHT) {
        // Assertions before
        // Not needed as no interaction with the contract

        deal(address(token), address(this), DEFAULT_AMOUNT);

        uint256 epoch = 1;
        uint256 realizeEpoch = epoch + staker.STAKE_GROWTH_EPOCHS();
        uint256 weight = DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1);

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(this), address(staker), DEFAULT_AMOUNT);
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Staked(address(this), epoch, DEFAULT_AMOUNT, weight, weight, true);

        // Main call
        staker.lock(address(this), DEFAULT_AMOUNT);

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), epoch);
        // Account data
        assertEq(staker.getAccLockedStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weight);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), realizeEpoch), DEFAULT_AMOUNT);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), weight);
        //assertEq(staker.globalEpochToRealize(realizeEpoch), DEFAULT_AMOUNT);
        //assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccountWeight(address(this)), weight);
        assertEq(accountView.balance, DEFAULT_AMOUNT);
        assertEq(accountView.weight, weight);
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, DEFAULT_AMOUNT);
        assertEq(futur.length, 1);
        assertEq(futur[0].epochsToMaturity, 7);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch));
        assertEq(futur[0].pendingStake, 0);
        assertEq(futur[0].lockedStake, DEFAULT_AMOUNT);
        assertEq(staker.getGlobalWeight(), weight);
    }

    /// @notice Test Stake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - With previous position, not locked
    /// - No timejump
    function test_Lock_When_WithPreviousPosition_Locked_WithoutDelay()
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
    {
        deal(address(token), address(this), DEFAULT_AMOUNT);

        uint256 epoch = 1;
        uint256 realizeEpoch = epoch + staker.STAKE_GROWTH_EPOCHS();
        uint256 weight = DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1);

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(this), address(staker), DEFAULT_AMOUNT);
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Staked(address(this), epoch, DEFAULT_AMOUNT, weight * 2, weight, true);

        // Main call
        staker.lock(address(this), DEFAULT_AMOUNT);

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), epoch);
        // Account data
        assertEq(staker.getAccLockedStakeBSR(address(this)), DEFAULT_AMOUNT * 2);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weight * 2);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), realizeEpoch), DEFAULT_AMOUNT * 2);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), weight * 2);
        assertEq(staker.globalGrowthRate(), 0);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT * 2);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT * 2);
        assertEq(staker.getAccountWeight(address(this)), weight * 2);
        assertEq(accountView.balance, DEFAULT_AMOUNT * 2);
        assertEq(accountView.weight, weight * 2);
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, DEFAULT_AMOUNT * 2);
        assertEq(futur.length, 1);
        assertEq(futur[0].epochsToMaturity, 7);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch));
        assertEq(futur[0].pendingStake, 0);
        assertEq(futur[0].lockedStake, DEFAULT_AMOUNT * 2);
        assertEq(staker.getGlobalWeight(), weight * 2);
    }

    /// @notice Test Stake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - With previous position, locked
    /// - 1 Epoch timejump
    function test_Lock_When_WithPreviousPosition_Locked_AfterDelay()
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
    {
        deal(address(token), address(this), DEFAULT_AMOUNT);

        uint256 epochToSkip = 1;
        uint256 epoch = 2;
        uint256 realizeEpoch = epoch + staker.STAKE_GROWTH_EPOCHS();
        uint256 weight = DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1);

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(this), address(staker), DEFAULT_AMOUNT);
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Staked(address(this), epoch, DEFAULT_AMOUNT, weight * 2, weight, true);

        skip(epochToSkip * EPOCH_LENGHT);
        // Main call
        staker.lock(address(this), DEFAULT_AMOUNT);

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), epoch);
        // Account data
        assertEq(staker.getAccLockedStakeBSR(address(this)), DEFAULT_AMOUNT * 2);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 1));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weight * 2);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), realizeEpoch - 1), DEFAULT_AMOUNT);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), realizeEpoch), DEFAULT_AMOUNT);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), weight * 2);
        assertEq(staker.globalGrowthRate(), 0);
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT * 2);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT * 2);
        assertEq(staker.getAccountWeight(address(this)), weight * 2);
        assertEq(accountView.balance, DEFAULT_AMOUNT * 2);
        assertEq(accountView.weight, weight * 2);
        assertEq(accountView.pendingStake, 0);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, DEFAULT_AMOUNT * 2);
        assertEq(futur.length, 2);
        assertEq(futur[0].epochsToMaturity, 6);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch - EPOCH_LENGHT));
        assertEq(futur[0].pendingStake, 0);
        assertEq(futur[0].lockedStake, DEFAULT_AMOUNT);
        assertEq(futur[1].epochsToMaturity, 7);
        assertEq(futur[1].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch));
        assertEq(futur[1].pendingStake, 0);
        assertEq(futur[1].lockedStake, DEFAULT_AMOUNT);
        assertEq(staker.getGlobalWeight(), weight * 2);
    }

    /// @notice Test Stake under the following conditions:
    /// - Timejump to next epoch to avoid false 0
    /// - With previous position, not locked
    /// - 1 Epoch timejump
    function test_Lock_When_WithPreviousPosition_NotLocked()
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

        uint256 epochToSkip = 1;
        uint256 epoch = 2;
        uint256 realizeEpoch = epoch + staker.STAKE_GROWTH_EPOCHS();

        uint256 weightGrowth = DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS;
        uint256 weightExtra = DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1);
        uint256 weight = DEFAULT_AMOUNT + weightGrowth + weightExtra;

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(this), address(staker), DEFAULT_AMOUNT);
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.Staked(address(this), epoch, DEFAULT_AMOUNT, weight, weightExtra, true);

        skip(epochToSkip * EPOCH_LENGHT);
        // Main call
        staker.lock(address(this), DEFAULT_AMOUNT);

        // Assertions after
        (BoostedStaker.AccountView memory accountView, BoostedStaker.FutureRealizedStake[] memory futur) =
            staker.getAccountFullView(address(this));
        assertEq(staker.getEpoch(), epoch);
        // Account data
        assertEq(staker.getAccPendingStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLockedStakeBSR(address(this)), DEFAULT_AMOUNT);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), epoch);
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 0));
        assertTrue(staker.getAccUpdateEpochBitmapBSR(address(this), 1));
        assertEq(staker.getAccEpochWeightBSR(address(this), epoch), weight);
        assertEq(staker.getAccEpochToRealizePendingBSR(address(this), realizeEpoch - 1), DEFAULT_AMOUNT);
        assertEq(staker.getAccEpochToRealizeLockedBSR(address(this), realizeEpoch), DEFAULT_AMOUNT);
        // Global data
        assertEq(staker.getGlobalEpochWeightsBSR(epoch), weight);
        assertEq(staker.globalGrowthRate(), DEFAULT_AMOUNT); // Locked amount isn't counted in growth rate
        assertEq(staker.globalLastUpdateEpoch(), epoch);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT * 2);
        // Views
        assertEq(staker.balanceOf(address(this)), DEFAULT_AMOUNT * 2);
        assertEq(staker.getAccountWeight(address(this)), weight);
        assertEq(accountView.balance, DEFAULT_AMOUNT * 2);
        assertEq(accountView.weight, weight);
        assertEq(accountView.pendingStake, DEFAULT_AMOUNT);
        assertEq(accountView.realizedStake, 0);
        assertEq(accountView.lockedStake, DEFAULT_AMOUNT);
        assertEq(futur.length, 2);
        assertEq(futur[0].epochsToMaturity, 6);
        assertEq(futur[0].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch - EPOCH_LENGHT));
        assertEq(futur[0].pendingStake, DEFAULT_AMOUNT);
        assertEq(futur[0].lockedStake, 0);
        assertEq(futur[1].epochsToMaturity, 7);
        assertEq(futur[1].timestampAtMaturity, staker.START_TIME() + (EPOCH_LENGHT * realizeEpoch));
        assertEq(futur[1].pendingStake, 0);
        assertEq(futur[1].lockedStake, DEFAULT_AMOUNT);
        assertEq(staker.getGlobalWeight(), weight);
    }
}
