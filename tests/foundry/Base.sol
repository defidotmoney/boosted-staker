// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Standard
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Foundry
import {Test} from "forge-std/Test.sol";

// Contracts
import {StakerFactory} from "../../contracts/Factory.sol";
import {BoostedStaker} from "../../contracts/BoostedStaker.sol";

abstract contract Base_Test_ is Test {
    //////////////////////////////////////////////////////
    /// --- CONTRACTS
    //////////////////////////////////////////////////////
    ERC20 public token;
    BoostedStaker public staker;
    StakerFactory public factory;

    //////////////////////////////////////////////////////
    /// --- EOA
    //////////////////////////////////////////////////////
    address public alice;
    address public deployer;
    address public multisig;

    //////////////////////////////////////////////////////
    /// --- SETUP
    //////////////////////////////////////////////////////
    function setUp() public virtual {}
}
