// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Unit_Shared_Tests_} from "../../shared/Shared.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {MockERC20} from "../../../utils/mocks/MockERC20.sol";
import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";
import {WizardBoostedStaker} from "../../../utils/wizards/WizardBoostedStaker.sol";

contract Unit_Concrete_BoostedStaker_Sweep_Tests is Unit_Shared_Tests_ {
    using WizardBoostedStaker for BoostedStaker;

    //////////////////////////////////////////////////////
    /// --- REVERTING TESTS
    //////////////////////////////////////////////////////

    function test_RevertWhen_Sweep_NotCalledByOwner() public {
        vm.expectRevert("DFM:BS Not authorized");
        staker.sweep(IERC20(address(0)), address(0));
    }

    //////////////////////////////////////////////////////
    /// --- VALIDATING TESTS
    //////////////////////////////////////////////////////

    /// @notice Test the sweep function when the staker has no staked tokens
    function test_Sweep_With_StakedToken_WhenNoExtra()
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
        asOwner
    {
        // Assertions before
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(staker)), DEFAULT_AMOUNT);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT);

        // Expected event -> not emitted in this case
        //vm.expectEmit({emitter: address(token)});
        //emit IERC20.Transfer(address(staker), alice, 0);

        // Main call
        staker.sweep(token, alice);

        // Assertions after
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(staker)), DEFAULT_AMOUNT);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT);
    }

    /// @notice Test the sweep function when the staker has staked tokens and extra tokens
    function test_Sweep_With_StakedToken_WhenExtra()
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
        // Assertions before
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(address(staker)), DEFAULT_AMOUNT);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT);

        // Use bob as intermediary otherwise deal will overwrite the staker balance
        address bob = makeAddr("bob");
        uint256 donated = 123456;
        deal(address(token), bob, donated);
        vm.prank(bob);
        token.transfer(address(staker), donated);

        // Expected event
        vm.expectEmit({emitter: address(token)});
        emit IERC20.Transfer(address(staker), alice, donated);

        // Main call
        vm.prank(factory.owner());
        staker.sweep(token, alice);

        // Assertions after
        assertEq(token.balanceOf(alice), donated);
        assertEq(token.balanceOf(address(staker)), DEFAULT_AMOUNT);
        assertEq(staker.totalSupply(), DEFAULT_AMOUNT);
    }

    /// @notice Test the sweep function when the staker has random tokens
    function test_Sweep_With_RandomToken() public asOwner {
        MockERC20 random = new MockERC20("Random", "RND");

        // Assertions before
        assertEq(random.balanceOf(alice), 0);
        assertEq(random.balanceOf(address(staker)), 0);
        assertEq(staker.totalSupply(), 0);

        uint256 donated = 123456;
        deal(address(random), address(staker), donated);

        // Expected event
        vm.expectEmit({emitter: address(random)});
        emit IERC20.Transfer(address(staker), alice, donated);

        // Main call
        staker.sweep(IERC20(address(random)), alice);

        // Assertions after
        assertEq(random.balanceOf(alice), donated);
        assertEq(random.balanceOf(address(staker)), 0);
        assertEq(staker.totalSupply(), 0);
    }
}
