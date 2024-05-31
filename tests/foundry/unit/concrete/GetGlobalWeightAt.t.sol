// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../shared/Shared.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_GetGlobalWeightAt_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    function test_GetGlobalWeightAt_When_EpochAsked_IsGreaterThan_SystemEpoch() public view {
        assertEq(staker.getEpoch(), 0);
        assertEq(staker.getGlobalWeightAt(1), 0);
    }

    function test_GetGlobalWeightAt_When_EpochAsked_IsEqualTo_LastUpdateEpoch_NoWeight() public view {
        assertEq(staker.globalLastUpdateEpoch(), 0);
        assertEq(staker.getEpoch(), 0);
        assertEq(staker.getGlobalWeightAt(0), 0);
    }

    function test_GetGlobalWeightAt_When_EpochAsked_IsLowerThan_LastUpdateEpoch_NoWeight()
        public
        timejump(EPOCH_LENGHT)
    {
        assertEq(staker.globalLastUpdateEpoch(), 0);
        assertEq(staker.getEpoch(), 1);
        assertEq(staker.getGlobalWeightAt(0), 0);
    }

    function test_GetGlobalWeightAt_When_EpochAsked_IsEqualTo_LastUpdateEpoch_WithWeight()
        public
        stake(Modifier_Stake({skipBefore: 0, account: address(this), amount: DEFAULT_AMOUNT, lock: false, skipAfter: 0}))
    {
        assertEq(staker.globalLastUpdateEpoch(), 0);
        assertEq(staker.getEpoch(), 0);
        assertEq(staker.getGlobalWeightAt(0), DEFAULT_AMOUNT);
    }

    function test_GetGlobalWeightAt_When_EpochAsked_IsGreaterThan_LastUpdateEpoch_RateNull()
        public
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: true,
                skipAfter: EPOCH_LENGHT
            })
        )
    {
        assertEq(staker.globalLastUpdateEpoch(), 0);
        assertEq(staker.getEpoch(), 1);
        assertEq(
            staker.getGlobalWeightAt(1),
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * STAKE_GROWTH_EPOCHS
        );
    }

    function test_GetGlobalWeightAt_When_EpochAsked_IsGreaterThan_LastUpdateEpoch_RateNotNull()
        public
        stake(
            Modifier_Stake({
                skipBefore: 0,
                account: address(this),
                amount: DEFAULT_AMOUNT,
                lock: false,
                skipAfter: EPOCH_LENGHT * 2
            })
        )
    {
        assertEq(staker.globalLastUpdateEpoch(), 0);
        assertEq(staker.getEpoch(), 2);
        assertEq(
            staker.getGlobalWeightAt(1),
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS
        );
        assertEq(
            staker.getGlobalWeightAt(2),
            DEFAULT_AMOUNT + DEFAULT_AMOUNT * (MAX_WEIGHT_MULTIPLIER - 1) / STAKE_GROWTH_EPOCHS * 2
        );
    }
}
