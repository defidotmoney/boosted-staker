// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Vm} from "forge-std/Vm.sol";
import {SlotFinder} from "./SlotFinder.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";

library WizardBoostedStaker {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    //////////////////////////////////////////////////////
    /// --- SLOTS REFERENCES
    //////////////////////////////////////////////////////
    /// -------------------------------------------------
    /// Global storage slots
    /// -------------------------------------------------
    ///
    /// accountData ---------------------|-> 0
    ///
    /// accountEpochWeights -------------|-> 1
    ///
    /// accountEpochToRealize -----------|-> 2
    ///
    /// isApprovedUnstaker --------------|-> 3
    ///
    /// globalEpochWeights --------------|-> 4 -> 32_771
    ///                                     (2 values per slots, 65_535 values in array, 32_767 slots required)
    ///
    /// globalEpochToRealize ------------|-> 32_772 -> 65_539
    ///                                     (2 values per slots, 65_535 values in array, 32_767 slots required)
    ///
    /// globalGrowthRate ----------------|
    /// globalLastUpdateEpoch -----------|
    /// totalSupply ---------------------|
    /// locksEnabled --------------------|-> 65_540
    ///
    /// -------------------------------------------------
    /// Struct storage slots
    /// -------------------------------------------------
    ///
    /// --- AccountData
    /// realizedStake -------------------|
    /// pendingStake --------------------|-> 0
    ///
    /// lockedStake ---------------------|
    /// lastUpdateEpoch------------------|
    /// updateEpochBitmap----------------|-> 1
    ///
    /// --- ToRealize
    /// pending -------------------------|
    /// locked --------------------------|-> 0
    ///
    /// -------------------------------------------------
    /// -------------------------------------------------

    uint256 public constant ACCOUNT_DATA_MAPPING_SLOT_REF = 0;
    uint256 public constant ACCOUNT_EPOCH_WEIGHTS_MAPPING_SLOT_REF = 1;
    uint256 public constant ACCOUNT_EPOCH_TO_REALIZE_MAPPING_SLOT_REF = 2;
    uint256 public constant IS_APPROVED_UNSTAKER_SLOT_REF = 3;

    uint256 public constant GLOBAL_EPOCH_WEIGHTS_ARRAY_SLOT_REF = 4;
    uint256 public constant GLOBAL_EPOCH_TO_REALIZE_ARRAY_SLOT_REF = 32_772;

    uint256 public constant LOCKS_ENABLED_SLOT_REF = 65_540;

    uint256 public constant ACCOUNT_DATA_REALIZED_STAKE_SLOT_REF = 0;
    uint256 public constant ACCOUNT_DATA_PENDING_STAKE_SLOT_REF = 0;
    uint256 public constant ACCOUNT_DATA_LOCKED_STAKE_SLOT_REF = 1;
    uint256 public constant ACCOUNT_DATA_LAST_UPDATE_EPOCH_SLOT_REF = 1;
    uint256 public constant ACCOUNT_DATA_UPDATE_EPOCH_BITMAP_SLOT_REF = 1;

    function getRealizedStakeBSR(BoostedStaker _contract, address _account) internal view returns (uint256) {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_DATA_MAPPING_SLOT_REF))
                + ACCOUNT_DATA_REALIZED_STAKE_SLOT_REF
        );
        uint256 data = uint256(vm.load(address(_contract), slot));
        uint256 mask = 2 ** 112 - 1;
        return data & mask;
    }

    function getPendingStakeBSR(BoostedStaker _contract, address _account) internal view returns (uint256) {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_DATA_MAPPING_SLOT_REF))
                + ACCOUNT_DATA_PENDING_STAKE_SLOT_REF
        );
        uint256 data = uint256(vm.load(address(_contract), slot));
        uint256 mask = (2 ** 224 - 1) ^ (2 ** 112 - 1);
        return data & mask;
    }

    function getLockedStakeBSR(BoostedStaker _contract, address _account) internal view returns (uint256) {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_DATA_MAPPING_SLOT_REF))
                + ACCOUNT_DATA_LOCKED_STAKE_SLOT_REF
        );
        uint256 data = uint256(vm.load(address(_contract), slot));
        uint256 mask = (2 ** 112 - 1);
        return data & mask;
    }

    function getLastUpdateEpochBSR(BoostedStaker _contract, address _account) internal view returns (uint256) {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_DATA_MAPPING_SLOT_REF))
                + ACCOUNT_DATA_LAST_UPDATE_EPOCH_SLOT_REF
        );
        uint256 data = uint256(vm.load(address(_contract), slot));
        uint256 mask = (2 ** 128 - 1) ^ (2 ** 112 - 1);
        return data & mask;
    }

    function getUpdateEpochBitmapBSR(BoostedStaker _contract, address _account, uint256 _epoch)
        internal
        view
        returns (uint256)
    {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_DATA_MAPPING_SLOT_REF))
                + ACCOUNT_DATA_UPDATE_EPOCH_BITMAP_SLOT_REF
        );
        uint256 data = uint256(vm.load(address(_contract), slot));
        uint256 mask = (2 ** (128 + _epoch + 1) - 1) ^ (2 ** (128 + _epoch) - 1);
        return data & mask;
    }
}
//11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
//                                                                                                                1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
//11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
