// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Standard
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Contracts
import {StakerFactory} from "../../../../contracts/Factory.sol";
import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";

// Test imports
import {Base_Test_} from "../../Base.sol";
import {MockERC20} from "../../utils/mocks/MockERC20.sol";
import {Environment as ENV} from "../../utils/Environment.sol";
import {DeploymentParams as DP} from "../../utils/DeploymentParameters.sol";

contract Unit_Shared_Tests_ is Base_Test_ {
    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public override {
        super.setUp();

        // 1. Set up realistic environment test
        _setUpRealisticEnvironment();

        // 2. Generate user addresses
        _generateAddresses();

        // 3. Deploy contracts
        _deployContracts();
    }

    //////////////////////////////////////////////////////
    /// --- CORE FUNCTIONS
    //////////////////////////////////////////////////////
    function _setUpRealisticEnvironment() internal {
        vm.warp(ENV.TIMESTAMP); // Setup realistic environment Timestamp
        vm.roll(ENV.BLOCKNUMBER); // Setup realistic environment Blocknumber
    }

    function _generateAddresses() internal {
        alice = makeAddr("alice");
        deployer = makeAddr("deployer");
        multisig = makeAddr("multisig");
    }

    function _deployContracts() internal {
        // Deploy token
        token = ERC20(address(new MockERC20("Mock Token 1", "MTKN1")));

        // Deploy factory
        vm.prank(multisig);
        factory = new StakerFactory(DP.EPOCH_DAYS, DP.STAKE_GROWTH_EPOCHS);

        // Deploy staker
        vm.prank(multisig);
        factory.deployBoostedStaker(address(token), DP.MAX_WEIGHT_MULTIPLIER);
    }
}
