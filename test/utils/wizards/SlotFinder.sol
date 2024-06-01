// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

library SlotFinder {
    /// @notice Get the slot for a specific array element
    /// @param _slot The starting slot for the array
    /// @param _elementIndex The index of the array element
    /// @return The slot for the array element
    function getSlotForArrayElement(uint256 _slot, uint256 _elementIndex) public pure returns (bytes32) {
        bytes32 startingSlotForArrayElements = keccak256(abi.encode(_slot));
        return bytes32(uint256(startingSlotForArrayElements) + _elementIndex);
    }

    /// @notice Get the slot for a specific mapping element
    /// @param _key The key of the mapping
    /// @param _mappingSlotIndex The index of the mapping slot
    /// @return The slot for the mapping element
    function getMappingElementSlotIndex(address _key, uint256 _mappingSlotIndex) public pure returns (bytes32) {
        return keccak256(abi.encode(_key, _mappingSlotIndex));
    }

    /// @notice Get the slot for a specific mapping element
    /// @param _key The key of the mapping
    /// @param _mappingSlotIndex The index of the mapping slot
    /// @return The slot for the mapping element
    function getMappingElementSlotIndex(uint256 _key, uint256 _mappingSlotIndex) public pure returns (bytes32) {
        return keccak256(abi.encode(_key, _mappingSlotIndex));
    }

    /// @notice Get the slot for a specific mapping element
    /// @param _key The key of the mapping
    /// @param _mappingSlotIndex The index of the mapping slot
    /// @return The slot for the mapping element
    function getMappingElementSlotIndex(bytes32 _key, uint256 _mappingSlotIndex) public pure returns (bytes32) {
        return keccak256(abi.encode(_key, _mappingSlotIndex));
    }
}
