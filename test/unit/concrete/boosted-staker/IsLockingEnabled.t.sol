// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_IsLockingEnable_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    function test_IsLockingEnabled_Enable() public view {
        assertEq(staker.isLockingEnabled(), true);
    }

    function test_IsLockingEnabled_DisableLocally() public disableLocks {
        assertEq(staker.isLockingEnabled(), false);
    }

    function test_IsLockingEnabled_DisableGlobally() public {
        vm.prank(factory.owner());
        factory.disableLocksGlobally();

        assertEq(staker.isLockingEnabled(), false);
    }
}
