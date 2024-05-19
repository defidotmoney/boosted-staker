// SPDX-License-Identifier: GNU AGPLv3
pragma solidity 0.8.25;

import { BoostedStaker } from "./BoostedStaker.sol";

/**
    @notice Boosted Staker Factory
    @author Yearn (with edits by defidotmoney)
 */
contract StakerFactory {
    string public constant VERSION = "1.0.0";

    /**
        @notice Deploy new YBS contract.
        @dev We use CREATE2 to generate deterministic deployments based on msg.sender.
    */
    function deploy(
        address _token,
        uint _max_stake_growth_weeks,
        uint _start_time,
        address _owner
    ) external returns (address distributor) {
        uint256 salt = uint256(uint160(address(msg.sender)));
        bytes memory bytecode = type(BoostedStaker).creationCode;
        bytes memory bytecodeWithArgs = abi.encodePacked(
            bytecode,
            abi.encode(_token, _max_stake_growth_weeks, _start_time, _owner)
        );
        address deployedAddress;
        assembly {
            deployedAddress := create2(0, add(bytecodeWithArgs, 0x20), mload(bytecodeWithArgs), salt)
        }
        require(deployedAddress != address(0), "Failed to deploy contract");

        return deployedAddress;
    }
}
