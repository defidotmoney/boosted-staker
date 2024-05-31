// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Vm} from "forge-std/Vm.sol";
import {SlotFinder} from "./SlotFinder.sol";

import {BoostedStaker} from "../../../../contracts/BoostedStaker.sol";

/// @notice Library to interact with BoostedStaker contract storage marked as private/internal
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

    //////////////////////////////////////////////////////
    /// --- ACCOUNT DATA
    //////////////////////////////////////////////////////

    /// @notice Get Account data -> Realized Stake
    /// @param _contract BoostedStaker contract
    /// @param _account Account address
    /// @return Realized stake
    function getAccRealizedStakeBSR(BoostedStaker _contract, address _account) internal view returns (uint256) {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_DATA_MAPPING_SLOT_REF))
                + ACCOUNT_DATA_REALIZED_STAKE_SLOT_REF
        );
        uint256 data = uint256(vm.load(address(_contract), slot));
        uint256 mask = 2 ** 112 - 1;
        return data & mask;
    }

    /// @notice Get Account data -> Pending Stake
    /// @param _contract BoostedStaker contract
    /// @param _account Account address
    /// @return Pending stake
    function getAccPendingStakeBSR(BoostedStaker _contract, address _account) internal view returns (uint256) {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_DATA_MAPPING_SLOT_REF))
                + ACCOUNT_DATA_PENDING_STAKE_SLOT_REF
        );
        uint256 data = uint256(vm.load(address(_contract), slot)) >> 112;
        uint256 mask = (2 ** 112 - 1);
        return data & mask;
    }

    /// @notice Get Account data -> Locked Stake
    /// @param _contract BoostedStaker contract
    /// @param _account Account address
    /// @return Locked stake
    function getAccLockedStakeBSR(BoostedStaker _contract, address _account) internal view returns (uint256) {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_DATA_MAPPING_SLOT_REF))
                + ACCOUNT_DATA_LOCKED_STAKE_SLOT_REF
        );
        uint256 data = uint256(vm.load(address(_contract), slot));
        uint256 mask = (2 ** 112 - 1);
        return data & mask;
    }

    /// @notice Get Account data -> Last Update Epoch
    /// @param _contract BoostedStaker contract
    /// @param _account Account address
    /// @return Last update epoch
    function getAccLastUpdateEpochBSR(BoostedStaker _contract, address _account) internal view returns (uint256) {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_DATA_MAPPING_SLOT_REF))
                + ACCOUNT_DATA_LAST_UPDATE_EPOCH_SLOT_REF
        );
        uint256 data = uint256(vm.load(address(_contract), slot)) >> 112;
        uint256 mask = 2 ** 16 - 1;
        return data & mask;
    }

    /// @notice Get Account data -> Update Epoch Bitmap
    /// @param _contract BoostedStaker contract
    /// @param _account Account address
    /// @param _epoch Epoch index
    /// @return True if there is a bit set for the given epoch
    function getAccUpdateEpochBitmapBSR(BoostedStaker _contract, address _account, uint256 _epoch)
        internal
        view
        returns (bool)
    {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_DATA_MAPPING_SLOT_REF))
                + ACCOUNT_DATA_UPDATE_EPOCH_BITMAP_SLOT_REF
        );
        uint256 data = uint256(vm.load(address(_contract), slot)) >> (128 + _epoch);
        return data & 1 == 1;
    }

    //////////////////////////////////////////////////////
    /// --- ACCOUNT EPOCH WEIGHTS
    //////////////////////////////////////////////////////

    /// @notice Get Account Epoch Weights
    /// @param _contract BoostedStaker contract
    /// @param _account Account address
    /// @param _epoch Epoch index
    /// @return Account epoch weight
    function getAccEpochWeightBSR(BoostedStaker _contract, address _account, uint256 _epoch)
        internal
        view
        returns (uint256)
    {
        uint256 valuePerSlot = 2; // How many uint128 fit in a slot? 256 / 128 = 2
        uint256 level = _epoch / valuePerSlot;
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_EPOCH_WEIGHTS_MAPPING_SLOT_REF)) + level
        );
        uint256 offset = _epoch % valuePerSlot;
        uint256 data = uint256(vm.load(address(_contract), slot)) >> (128 * offset);
        return data & ((2 ** 128) - 1);
    }

    //////////////////////////////////////////////////////
    /// --- ACCOUNT EPOCH TO REALIZE
    //////////////////////////////////////////////////////

    /// @notice Get Account Epoch To Realize -> Pending amount
    /// @param _contract BoostedStaker contract
    /// @param _account Account address
    /// @param _epoch Epoch index
    /// @return Pending amount
    function getAccEpochToRealizePendingBSR(BoostedStaker _contract, address _account, uint256 _epoch)
        internal
        view
        returns (uint256)
    {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_EPOCH_TO_REALIZE_MAPPING_SLOT_REF)) + _epoch
        );
        uint256 data = uint256(vm.load(address(_contract), slot));
        uint256 mask = (2 ** 128 - 1);
        return data & mask;
    }

    /// @notice Get Account Epoch To Realize -> Locked amount
    /// @param _contract BoostedStaker contract
    /// @param _account Account address
    /// @param _epoch Epoch index
    function getAccEpochToRealizeLockedBSR(BoostedStaker _contract, address _account, uint256 _epoch)
        internal
        view
        returns (uint256)
    {
        bytes32 slot = bytes32(
            uint256(SlotFinder.getMappingElementSlotIndex(_account, ACCOUNT_EPOCH_TO_REALIZE_MAPPING_SLOT_REF)) + _epoch
        );
        uint256 data = uint256(vm.load(address(_contract), slot)) >> 128;
        uint256 mask = (2 ** 128 - 1);
        return data & mask;
    }

    //////////////////////////////////////////////////////
    /// --- GLOBAL DATA
    //////////////////////////////////////////////////////

    /// @notice Get Global Epoch Weights
    /// @param _contract BoostedStaker contract
    /// @param _epoch Epoch index
    /// @return Global epoch weight
    function getGlobalEpochWeightsBSR(BoostedStaker _contract, uint256 _epoch) internal view returns (uint256) {
        uint256 valuePerSlot = 2; // How many uint128 fit in a slot? 256 / 128 = 2
        uint256 level = _epoch / valuePerSlot;
        bytes32 slot = bytes32(GLOBAL_EPOCH_WEIGHTS_ARRAY_SLOT_REF + level);
        uint256 offset = _epoch % valuePerSlot;
        uint256 data = uint256(vm.load(address(_contract), slot)) >> (128 * offset);
        return data & ((2 ** 128) - 1);
    }

    function getLocksEnabledBSR(BoostedStaker _contract) internal view returns (bool) {
        bytes32 slot = bytes32(LOCKS_ENABLED_SLOT_REF);
        uint256 data = uint256(vm.load(address(_contract), slot)) >> (112 + 16 + 120);
        return data & 1 == 1;
    }
}
