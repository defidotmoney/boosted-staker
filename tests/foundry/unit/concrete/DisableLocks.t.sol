// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_DisableLocks_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////

    function test_RevertWhen_DisableLocks_NotCalledByOwner() public {
        vm.expectRevert("DFM:BS Not authorized");
        staker.disableLocks();
    }

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    function test_DisableLocks() public asOwner {
        // Assertions before
        assertTrue(staker.getLocksEnabledBSR());

        // Expected event
        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.LocksDisabled();

        // Main call
        staker.disableLocks();

        // Assertions after
        assertFalse(staker.getLocksEnabledBSR());
    }
}
