// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Base_Test_} from "../../Base.sol";

abstract contract Modifiers is Base_Test_ {
    //////////////////////////////////////////////////////
    /// --- STRUCTS
    //////////////////////////////////////////////////////
    struct Modifier_Stake {
        uint256 skipBefore;
        address account;
        uint256 amount;
        bool lock;
        uint256 skipAfter;
    }

    //////////////////////////////////////////////////////
    /// --- MODIFIERS
    //////////////////////////////////////////////////////

    modifier timejump(uint256 seconds_) {
        skip(seconds_);
        _;
    }

    modifier asOwner() {
        vm.startPrank(factory.owner());
        _;
        vm.stopPrank();
    }

    modifier stake(Modifier_Stake memory _m) {
        if (_m.skipBefore > 0) {
            skip(_m.skipBefore);
        }

        deal(address(token), _m.account, _m.amount);

        if (_m.lock) {
            staker.lock(_m.account, _m.amount);
        } else {
            staker.stake(_m.account, _m.amount);
        }

        if (_m.skipAfter > 0) {
            skip(_m.skipAfter);
        }

        _;
    }

    modifier approveUnstaker(address _account, address _unstaker) {
        vm.prank(_account);
        staker.setApprovedUnstaker(_unstaker, true);
        _;
    }

    modifier disableLocks() {
        vm.prank(factory.owner());
        staker.disableLocks();
        _;
    }

    modifier checkpointAccount(address _account) {
        staker.checkpointAccount(_account);
        _;
    }
}
