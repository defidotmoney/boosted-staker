// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakerFactory} from "../../../../../contracts/Factory.sol";
import {BoostedStaker} from "../../../../../contracts/BoostedStaker.sol";
import {DeploymentParams as DP} from "../../../utils/DeploymentParameters.sol";

contract Unit_Concrete_Factory_DisablleLocksGlobally_Tests is Unit_Shared_Tests_ {
    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////
    function test_DisableLocksGlobally() public asOwner {
        // Setup
        assertEq(factory.isLockingEnabled(), true);

        // Disable locks
        vm.expectEmit({emitter: address(factory)});
        emit StakerFactory.LocksDisabled();

        factory.disableLocksGlobally();

        // Validate
        assertEq(factory.isLockingEnabled(), false);
    }
}
