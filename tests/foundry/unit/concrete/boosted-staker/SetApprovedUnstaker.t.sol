// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";

import {MockERC20} from "../../../utils/mocks/MockERC20.sol";
import {BoostedStaker} from "../../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_SetApprovedUnstaker_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    function test_SetApprovedUnstaker_True() public {
        // Assertions before
        assertEq(staker.isApprovedUnstaker(address(this), alice), false);

        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.ApprovedUnstakerSet(address(this), alice, true);

        // Main call
        staker.setApprovedUnstaker(alice, true);

        // Assertions after
        assertEq(staker.isApprovedUnstaker(address(this), alice), true);
    }

    function test_SetApprovedUnstaker_False() public {
        test_SetApprovedUnstaker_True();

        vm.expectEmit({emitter: address(staker)});
        emit BoostedStaker.ApprovedUnstakerSet(address(this), alice, false);

        // Main call
        staker.setApprovedUnstaker(alice, false);

        // Assertions after
        assertEq(staker.isApprovedUnstaker(address(this), alice), false);
    }
}
