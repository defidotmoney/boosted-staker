// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StakerFactory} from "../../../../../contracts/Factory.sol";
import {BoostedStaker} from "../../../../../contracts/BoostedStaker.sol";
import {DeploymentParams as DP} from "../../../utils/DeploymentParameters.sol";

contract Unit_Concrete_Factory_DeployBoostedStaker_Tests is Unit_Shared_Tests_ {
    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////

    function test_RevertWhen_DeployBoostedStaker_Because_AlreadyDeployed() public asOwner {
        // Setup
        // Deploy new Staker with token_
        address token_ = makeAddr("token");
        factory.deployBoostedStaker(token_, 2);

        // Try to deploy again
        vm.expectRevert("DFM:BSF Already deployed");
        factory.deployBoostedStaker(token_, 0);
    }

    function test_RevertWhen_DeployBoostedStaker_Because_MaxWeightMultiplierIsLessThan2() public asOwner {
        // Setup
        // Deploy new Staker with token_
        address token_ = makeAddr("token");
        vm.expectRevert("DFM:BSF MAX_WEIGHT_MULTIPLIER");
        factory.deployBoostedStaker(token_, 1);
    }

    function test_RevertWhen_DeployBoostedStaker_Because_MaxWeightMultiplierIsGreaterThan255() public asOwner {
        // Setup
        // Deploy new Staker with token_
        address token_ = makeAddr("token");
        vm.expectRevert("DFM:BSF MAX_WEIGHT_MULTIPLIER");
        factory.deployBoostedStaker(token_, 256);
    }

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    function test_DeployBoostedStaker() public asOwner {
        // Setup
        address token_ = makeAddr("token");
        uint256 maxWeightMultiplier = 10;

        // Predict address
        address predicted = _predictAddress(token_, maxWeightMultiplier);

        // Deploy new Staker with token_
        vm.expectEmit({emitter: address(factory)});
        emit StakerFactory.BoostedStakerDeployed(token_, predicted);

        assertEq(factory.deployBoostedStaker(token_, maxWeightMultiplier), predicted);

        // Assertions
        assertEq(factory.boostedStakers(token_), predicted);
    }

    function _predictAddress(address token, uint256 maxWeightMultiplier) internal view returns (address) {
        uint256 stakeGrowthEpochs = factory.STAKE_GROWTH_EPOCHS();
        uint256 startTime = factory.START_TIME();
        uint256 epochDays = factory.EPOCH_DAYS();

        uint256 salt = uint256(uint160(token));
        bytes32 hash = keccak256(
            abi.encodePacked(
                type(BoostedStaker).creationCode,
                abi.encode(token, stakeGrowthEpochs, maxWeightMultiplier, startTime, epochDays)
            )
        );

        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, hash)))));
    }
}
