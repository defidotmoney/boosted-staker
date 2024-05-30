// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_CheckpointAccount_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////
    function test_RevertWhen_CheckpointAccount_Because_InvalidEpoch() public timejump(EPOCH_LENGHT) {
        //staker.checkpointAccount(address(this));
        // Line 569 unreachable require(_systemEpoch > lastUpdateEpoch, "DFM:BS Invalid epoch");
    }

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    function test_CheckpointAccount_When_UpToDate_NoPosition_Epoch0() public {
        assertEq(staker.checkpointAccount(address(this)), 0);
    }

    function test_CheckPointAccount_When_UpToDate_NoPosition_Epoch1() public timejump(EPOCH_LENGHT) {
        assertEq(staker.getEpoch(), 1);
        assertEq(staker.checkpointAccount(address(this)), 0);
        assertEq(staker.getAccLastUpdateEpochBSR(address(this)), 1);
    }

    function test_CheckpointAccount_When_OnlyRealizedStake()
        public
        stake(
            Modifier_Stake({
                skipBefore: EPOCH_LENGHT,
                account: address(this),
                amount: 4e25,
                lock: false,
                skipAfter: EPOCH_LENGHT * STAKE_GROWTH_EPOCHS
            })
        )
    {
        staker.checkpointAccount(address(this)); // Checkpoint to be sure we reached the end of the stake growth period
        (BoostedStaker.AccountView memory acc,) = staker.getAccountFullView(address(this));
        assertEq(acc.realizedStake, 4e25);
        assertEq(acc.pendingStake, 0);

        uint256 epochToSkip = 200;
        skip(EPOCH_LENGHT * epochToSkip);

        uint256 maxWeight = 4e25 * MAX_WEIGHT_MULTIPLIER;
        // Main call
        assertEq(staker.checkpointAccount(address(this)), maxWeight);
    }
}
