// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IFactory } from "./interfaces/IFactory.sol";

/**
    @notice Boosted Staker
    @author Yearn (with edits by defidotmoney)
 */
contract BoostedStaker {
    using SafeERC20 for IERC20;

    uint256 private constant MAX_EPOCHS = 65535;
    uint16 private immutable MAX_EPOCH_BIT;
    uint256 public immutable STAKE_GROWTH_EPOCHS;
    uint256 public immutable MAX_WEIGHT_MULTIPLIER;
    uint256 public immutable START_TIME;
    uint256 public immutable EPOCH_LENGTH;
    IERC20 public immutable STAKE_TOKEN;
    IFactory public immutable FACTORY;

    // Account weight tracking state vars.
    mapping(address account => AccountData data) private accountData;
    mapping(address account => uint128[MAX_EPOCHS]) private accountEpochWeights;
    mapping(address account => ToRealize[MAX_EPOCHS] weight) private accountEpochToRealize;

    mapping(address account => mapping(address caller => bool approvalStatus)) public isApprovedUnstaker;

    // Global weight tracking stats vars.
    uint128[MAX_EPOCHS] private globalEpochWeights;
    uint128[MAX_EPOCHS] public globalEpochToRealize;
    uint112 public globalGrowthRate;
    uint16 public globalLastUpdateEpoch;

    uint120 public totalSupply;

    bool private locksEnabled;

    struct AccountData {
        uint112 realizedStake; // Amount of stake that has fully realized weight.
        uint112 pendingStake; // Amount of stake that has not yet fully realized weight.
        uint112 lockedStake; // Amount of stake that has fully realized weight, but cannot be withdrawn.
        uint16 lastUpdateEpoch; // Epoch of last sync.
        // One byte member to represent epochs in which an account has pending weight changes.
        // A bit is set to true when the account has a non-zero token balance to be realized in
        // the corresponding epoch. We use this as a "map", allowing us to reduce gas consumption
        // by avoiding unnecessary lookups on epochs which an account has zero pending stake.
        //
        // Example: 0100000000000001
        // The left-most bit represents the final epoch of pendingStake.
        // Therefore, we can see that account has stake updates to process only in epochs 15 and 1.
        uint16 updateEpochBitmap;
    }

    struct ToRealize {
        uint128 pending;
        uint128 locked;
    }

    struct AccountView {
        uint256 balance;
        uint256 weight;
        uint256 realizedStake;
        uint256 pendingStake;
        uint256 lockedStake;
    }

    struct FutureRealizedStake {
        uint256 epochsToMaturity;
        uint256 timestampAtMaturity;
        uint256 pendingStake;
        uint256 lockedStake;
    }

    event Staked(
        address indexed account,
        uint256 indexed epoch,
        uint256 amount,
        uint256 newUserWeight,
        uint256 weightAdded,
        bool isLocked
    );
    event Unstaked(
        address indexed account,
        uint256 indexed epoch,
        uint256 amount,
        uint256 newUserWeight,
        uint256 weightRemoved
    );
    event ApprovedUnstakerSet(address indexed account, address indexed caller, bool isApproved);
    event LocksDisabled();

    /**
        @dev Not intended for direct deployment, use `StakerFactory.deployBoostedStaker`
    */
    constructor(
        IERC20 token,
        uint256 stakeGrowthEpochs,
        uint256 maxWeightMultiplier,
        uint256 startTime,
        uint256 epochDays
    ) {
        FACTORY = IFactory(msg.sender);
        STAKE_TOKEN = token;
        STAKE_GROWTH_EPOCHS = stakeGrowthEpochs;
        MAX_WEIGHT_MULTIPLIER = maxWeightMultiplier;
        MAX_EPOCH_BIT = uint16(1 << STAKE_GROWTH_EPOCHS);
        EPOCH_LENGTH = epochDays * 1 days;
        START_TIME = startTime;

        locksEnabled = true;
    }

    modifier onlyOwner() {
        require(msg.sender == FACTORY.owner(), "DFM:BS Not authorized");
        _;
    }

    /// ----- External view functions -----

    function getEpoch() public view returns (uint256 epoch) {
        unchecked {
            return (block.timestamp - START_TIME) / EPOCH_LENGTH;
        }
    }

    function isLockingEnabled() public view returns (bool) {
        if (!locksEnabled) return false;
        return FACTORY.isLockingEnabled();
    }

    /**
        @notice Returns the balance of underlying staked tokens for an account
        @param _account Account to query balance.
        @return balance of account.
    */
    function balanceOf(address _account) external view returns (uint256) {
        AccountData memory acctData = accountData[_account];
        return (acctData.pendingStake + acctData.realizedStake + acctData.lockedStake);
    }

    /**
        @notice View function to get the current weight for an account
    */
    function getAccountWeight(address account) external view returns (uint256) {
        return getAccountWeightAt(account, getEpoch());
    }

    /**
        @notice Get the weight for an account in a given epoch
    */
    function getAccountWeightAt(address _account, uint256 _epoch) public view returns (uint256) {
        if (_epoch > getEpoch()) return 0;

        AccountData memory acctData = accountData[_account];

        uint16 lastUpdateEpoch = acctData.lastUpdateEpoch;

        if (lastUpdateEpoch >= _epoch) return accountEpochWeights[_account][_epoch];

        uint256 weight = accountEpochWeights[_account][lastUpdateEpoch];

        uint256 pending = uint256(acctData.pendingStake);
        if (pending == 0) return weight;

        uint16 bitmap = acctData.updateEpochBitmap;

        while (lastUpdateEpoch < _epoch) {
            // Populate data for missed epochs
            unchecked {
                lastUpdateEpoch++;
            }
            weight += _getWeightGrowth(pending, 1);

            // Our bitmap is used to determine if epoch has any amount to realize.
            bitmap = bitmap << 1;
            if (bitmap & MAX_EPOCH_BIT == MAX_EPOCH_BIT) {
                // If left-most bit is true, we have something to realize; push pending to realized.
                pending -= accountEpochToRealize[_account][lastUpdateEpoch].pending;
                if (pending == 0) break; // All pending has now been realized, let's exit.
            }
        }

        return weight;
    }

    /**
        @notice Get a detailed view of staked balances and weight for `account`
        @return accountView Detailed information on account weight and balances:
                 * total deposited balance
                 * current weight
                 * realized stake (balance receiving maximum weight)
                 * pending stake (balance where weight is still increasing)
                 * locked stake (max weight, but cannot be withdrawn)
        @return futureRealizedStake Array detailing pending and locked stake balances:
                 * number of epochs remaining until balances convert to realized
                 * timestamp when balances are realized
                 * pending balance to be realized in this epoch
                 * locked balance to be realized in this epoch
     */
    function getAccountFullView(
        address account
    ) external view returns (AccountView memory accountView, FutureRealizedStake[] memory futureRealizedStake) {
        uint256 systemEpoch = getEpoch();

        AccountData storage acctData = accountData[account];
        uint256 lastUpdateEpoch = acctData.lastUpdateEpoch;

        accountView.pendingStake = acctData.pendingStake;
        accountView.lockedStake = acctData.lockedStake;
        accountView.realizedStake = acctData.realizedStake;
        accountView.weight = accountEpochWeights[account][lastUpdateEpoch];
        accountView.balance = acctData.pendingStake + acctData.lockedStake + acctData.realizedStake;

        if (accountView.lockedStake > 0 && !isLockingEnabled()) {
            accountView.realizedStake += accountView.lockedStake;
            accountView.lockedStake = 0;
        }

        if (accountView.pendingStake + accountView.lockedStake > 0) {
            uint16 bitmap = acctData.updateEpochBitmap;
            uint256 targetSyncEpoch = min(systemEpoch, lastUpdateEpoch + STAKE_GROWTH_EPOCHS);

            // Populate data for missed epochs
            while (lastUpdateEpoch < targetSyncEpoch) {
                unchecked {
                    lastUpdateEpoch++;
                }
                accountView.weight += _getWeightGrowth(accountView.pendingStake, 1);

                // Shift left on bitmap as we pass over each epoch.
                bitmap = bitmap << 1;
                if (bitmap & MAX_EPOCH_BIT == MAX_EPOCH_BIT) {
                    // If left-most bit is true, we have something to realize; push pending to realized.
                    // Do any updates needed to realize an amount for an account.
                    ToRealize memory epochRealized = accountEpochToRealize[account][lastUpdateEpoch];
                    accountView.pendingStake -= epochRealized.pending;
                    accountView.realizedStake += epochRealized.pending;

                    if (accountView.lockedStake > 0) {
                        // skip if `locked == 0` to avoid issues after disabling locks
                        accountView.lockedStake -= epochRealized.locked;
                        accountView.realizedStake += epochRealized.locked;
                    }

                    if (accountView.pendingStake == 0 && accountView.lockedStake == 0) break;
                }
            }

            lastUpdateEpoch = systemEpoch;
            futureRealizedStake = new FutureRealizedStake[](STAKE_GROWTH_EPOCHS);
            uint256 length = 0;
            while (bitmap != 0) {
                lastUpdateEpoch++;
                bitmap = bitmap << 1;
                if (bitmap & MAX_EPOCH_BIT == MAX_EPOCH_BIT) {
                    ToRealize memory epochRealized = accountEpochToRealize[account][lastUpdateEpoch];
                    futureRealizedStake[length] = FutureRealizedStake({
                        epochsToMaturity: lastUpdateEpoch - systemEpoch,
                        timestampAtMaturity: START_TIME + (lastUpdateEpoch * EPOCH_LENGTH),
                        pendingStake: epochRealized.pending,
                        lockedStake: epochRealized.locked
                    });
                    length++;
                }
            }
            // reduce length of `futureRealizedStake` prior to returning
            assembly {
                mstore(futureRealizedStake, length)
            }
        }
    }

    /**
        @notice Get the system weight for current epoch.
    */
    function getGlobalWeight() external view returns (uint256) {
        return getGlobalWeightAt(getEpoch());
    }

    /**
        @notice Get the system weight for a specified epoch in the past.
        @dev querying a epoch in the future will always return 0.
        @param epoch the epoch number to query global weight for.
    */
    function getGlobalWeightAt(uint256 epoch) public view returns (uint256) {
        uint256 systemEpoch = getEpoch();
        if (epoch > systemEpoch) return 0;

        // Read these together since they are packed in the same slot.
        uint16 lastUpdateEpoch = globalLastUpdateEpoch;
        uint256 rate = globalGrowthRate;

        if (epoch <= lastUpdateEpoch) return globalEpochWeights[epoch];

        uint256 weight = globalEpochWeights[lastUpdateEpoch];
        if (rate == 0) {
            return weight;
        }

        while (lastUpdateEpoch < epoch) {
            unchecked {
                lastUpdateEpoch++;
            }

            weight += _getWeightGrowth(rate, 1);
            rate -= globalEpochToRealize[lastUpdateEpoch];
        }

        return weight;
    }

    /// ----- Unguarded nonpayable functions -----

    /**
        @notice Allow another address to unstake on behalf of the caller.
                Useful for zaps and other functionality.
        @param _caller Address of the caller to approve or unapprove.
        @param isApproved is `_caller` approved?
    */
    function setApprovedUnstaker(address _caller, bool isApproved) external {
        isApprovedUnstaker[msg.sender][_caller] = isApproved;
        emit ApprovedUnstakerSet(msg.sender, _caller, isApproved);
    }

    /**
        @notice Stake tokens into the staking contract.
        @param _amount Amount of tokens to stake.
    */
    function stake(address _account, uint256 _amount) external {
        _stake(_account, _amount, false);
    }

    /**
        @notice Lock tokens in the staking contract.
        @dev Locked tokens receive maximum boost immediately, but cannot be
             withdrawn until `STAKE_GROWTH_EPOCHS` have passed. The only
             exception is if the contract owner disables locks.
        @param _amount Amount of tokens to lock.
    */
    function lock(address _account, uint256 _amount) external {
        require(isLockingEnabled(), "DFM:BS Locks are disabled");
        _stake(_account, _amount, true);
    }

    /**
        @notice Unstake tokens from the contract.
        @dev In a partial restake, tokens giving the least weight are withdrawn first.
    */
    function unstake(address _account, uint256 _amount, address _receiver) external {
        require(_amount > 0, "DFM:BS Cannot unstake 0");

        if (msg.sender != _account) {
            require(isApprovedUnstaker[_account][msg.sender], "DFM:BS Not approved unstaker");
        }

        // Before going further, let's sync our account and global weights
        uint256 systemEpoch = getEpoch();
        (AccountData memory acctData, ) = _checkpointAccount(_account, systemEpoch);
        _checkpointGlobal(systemEpoch);

        require(acctData.realizedStake + acctData.pendingStake >= _amount, "DFM:BS Insufficient balance");

        // Here we do work to pull from most recent (least weighted) stake first
        uint16 bitmap = acctData.updateEpochBitmap;
        uint256 weightToRemove;

        uint128 amountNeeded = uint128(_amount);
        ToRealize[MAX_EPOCHS] storage epochToRealize = accountEpochToRealize[_account];

        if (bitmap > 0) {
            for (uint128 epochIndex; epochIndex < STAKE_GROWTH_EPOCHS; ) {
                // Move right to left, checking each bit if there's an update for corresponding epoch.
                uint16 mask = uint16(1 << epochIndex);
                if (bitmap & mask == mask) {
                    uint256 epochToCheck = systemEpoch + STAKE_GROWTH_EPOCHS - epochIndex;
                    uint128 pending = epochToRealize[epochToCheck].pending;
                    if (pending > 0) {
                        if (amountNeeded > pending) {
                            weightToRemove += _getWeight(pending, epochIndex);
                            epochToRealize[epochToCheck].pending = 0;
                            globalEpochToRealize[epochToCheck] -= pending;
                            amountNeeded -= pending;
                            if (epochToRealize[epochToCheck].locked == 0) bitmap = bitmap ^ mask;
                        } else {
                            // handle the case where we have more pending than needed
                            weightToRemove += _getWeight(amountNeeded, epochIndex);
                            epochToRealize[epochToCheck].pending -= amountNeeded;
                            globalEpochToRealize[epochToCheck] -= amountNeeded;
                            if (amountNeeded == pending) bitmap = bitmap ^ mask;
                            amountNeeded = 0;
                            break;
                        }
                    }
                }
                unchecked {
                    epochIndex++;
                }
            }
            acctData.updateEpochBitmap = bitmap;
        }

        uint256 pendingRemoved = _amount - amountNeeded;
        if (amountNeeded > 0) {
            weightToRemove += _getWeight(amountNeeded, STAKE_GROWTH_EPOCHS);
            acctData.realizedStake -= uint112(amountNeeded);
            acctData.pendingStake = 0;
        } else {
            acctData.pendingStake -= uint112(pendingRemoved);
        }

        accountData[_account] = acctData;

        globalGrowthRate -= uint112(pendingRemoved);
        globalEpochWeights[systemEpoch] -= uint128(weightToRemove);
        uint256 newAccountWeight = accountEpochWeights[_account][systemEpoch] - weightToRemove;
        accountEpochWeights[_account][systemEpoch] = uint128(newAccountWeight);

        totalSupply -= uint120(_amount);

        emit Unstaked(_account, systemEpoch, _amount, newAccountWeight, weightToRemove);

        STAKE_TOKEN.safeTransfer(_receiver, _amount);
    }

    /**
        @notice Checkpoint an account and get the account's current weight
        @dev Prefer to use this function over it's view counterpart for
             contract -> contract interactions.
        @param _account Account to checkpoint.
        @return weight Most current account weight.

    */
    function checkpointAccount(address _account) external returns (uint256 weight) {
        AccountData memory acctData;
        (acctData, weight) = _checkpointAccount(_account, getEpoch());
        accountData[_account] = acctData;
        return weight;
    }

    /**
        @notice Checkpoint an account using a specified epoch limit.
        @dev    To use in the event that significant number of epochs have passed since last
                heckpoint and single call becomes too expensive.
        @param _account Account to checkpoint.
        @param _epoch Epoch which we want to checkpoint to.
        @return weight Account weight for provided epoch.
    */
    function checkpointAccountWithLimit(address _account, uint256 _epoch) external returns (uint256 weight) {
        uint256 systemEpoch = getEpoch();
        if (_epoch >= systemEpoch) _epoch = systemEpoch;
        AccountData memory acctData;
        (acctData, weight) = _checkpointAccount(_account, _epoch);
        accountData[_account] = acctData;
        return weight;
    }

    /**
        @notice Get the current total system weight
        @dev Also updates local storage values for total weights. Using
             this function over it's `view` counterpart is preferred for
             contract -> contract interactions.
    */
    function checkpointGlobal() external returns (uint256) {
        uint256 systemEpoch = getEpoch();
        return _checkpointGlobal(systemEpoch);
    }

    /// ----- Owner-only nonpayable functions -----

    /**
        @notice Disable locks in this contract
        @dev Allows immediate withdrawal for all depositors. Cannot be undone.
     */
    function disableLocks() external onlyOwner {
        locksEnabled = false;
        emit LocksDisabled();
    }

    function sweep(IERC20 token, address receiver) external onlyOwner {
        uint256 amount = token.balanceOf(address(this));
        if (token == STAKE_TOKEN) {
            amount = amount - totalSupply;
        }
        if (amount > 0) token.safeTransfer(receiver, amount);
    }

    /// ----- Internal functions -----

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /** @dev The increased weight from `amount` after a number of epochs has passed */
    function _getWeightGrowth(uint256 amount, uint256 epochs) internal view returns (uint128 growth) {
        assert(STAKE_GROWTH_EPOCHS >= epochs); // TODO remove me
        amount *= MAX_WEIGHT_MULTIPLIER - 1;
        return uint128((amount / STAKE_GROWTH_EPOCHS) * epochs);
    }

    /** @dev The total weight of `amount` after a number of epochs has passed */
    function _getWeight(uint256 amount, uint256 epochs) internal view returns (uint256 weight) {
        uint256 growth = _getWeightGrowth(amount, epochs);
        return amount + growth;
    }

    function _stake(address _account, uint256 _amount, bool isLocked) internal {
        require(_amount > 0, "DFM:BS Cannot stake 0");
        require(_amount < type(uint112).max, "DFM:BS Amount too large");

        // Before going further, let's sync our account and global weights
        uint256 systemEpoch = getEpoch();
        (AccountData memory acctData, uint256 accountWeight) = _checkpointAccount(_account, systemEpoch);
        uint112 globalWeight = uint112(_checkpointGlobal(systemEpoch));

        uint256 realizeEpoch = systemEpoch + STAKE_GROWTH_EPOCHS;

        uint256 weight;
        if (isLocked) {
            weight = _getWeight(_amount, STAKE_GROWTH_EPOCHS);
            acctData.lockedStake += uint112(_amount);

            accountEpochToRealize[_account][realizeEpoch].locked += uint128(_amount);
        } else {
            weight = _amount;
            acctData.pendingStake += uint112(_amount);
            globalGrowthRate += uint112(_amount);

            accountEpochToRealize[_account][realizeEpoch].pending += uint128(_amount);
            globalEpochToRealize[realizeEpoch] += uint128(_amount);
        }

        accountEpochWeights[_account][systemEpoch] = uint128(accountWeight + weight);
        globalEpochWeights[systemEpoch] = uint128(globalWeight + weight);

        acctData.updateEpochBitmap |= 1; // Use bitwise or to ensure bit is flipped at least weighted position.
        accountData[_account] = acctData;
        totalSupply += uint120(_amount);

        STAKE_TOKEN.safeTransferFrom(msg.sender, address(this), uint256(_amount));
        emit Staked(_account, systemEpoch, _amount, accountWeight + weight, weight, isLocked);
    }

    function _checkpointAccount(
        address _account,
        uint256 _systemEpoch
    ) internal returns (AccountData memory acctData, uint128 weight) {
        acctData = accountData[_account];
        uint256 lastUpdateEpoch = acctData.lastUpdateEpoch;
        uint128[MAX_EPOCHS] storage epochWeights = accountEpochWeights[_account];

        uint256 pending = acctData.pendingStake;
        uint256 locked = acctData.lockedStake;
        uint256 realized = acctData.realizedStake;

        if (locked > 0 && !isLockingEnabled()) {
            realized += locked;
            locked = 0;
            acctData.realizedStake = uint112(realized);
            acctData.lockedStake = 0;
        }

        if (_systemEpoch == lastUpdateEpoch) {
            return (acctData, epochWeights[lastUpdateEpoch]);
        }

        require(_systemEpoch > lastUpdateEpoch, "DFM:BS Invalid epoch");

        if (pending == 0 && locked == 0) {
            if (realized != 0) {
                weight = epochWeights[lastUpdateEpoch];
                while (lastUpdateEpoch < _systemEpoch) {
                    unchecked {
                        lastUpdateEpoch++;
                    }
                    // Fill in any missing epochs
                    epochWeights[lastUpdateEpoch] = weight;
                }
            }
            accountData[_account].lastUpdateEpoch = uint16(_systemEpoch);
            acctData.lastUpdateEpoch = uint16(_systemEpoch);
            return (acctData, weight);
        }

        weight = epochWeights[lastUpdateEpoch];
        uint16 bitmap = acctData.updateEpochBitmap;
        uint256 targetSyncEpoch = min(_systemEpoch, lastUpdateEpoch + STAKE_GROWTH_EPOCHS);

        // Populate data for missed epochs
        while (lastUpdateEpoch < targetSyncEpoch) {
            unchecked {
                lastUpdateEpoch++;
            }
            weight += _getWeightGrowth(pending, 1);
            epochWeights[lastUpdateEpoch] = weight;

            // Shift left on bitmap as we pass over each epoch.
            bitmap = bitmap << 1;
            if (bitmap & MAX_EPOCH_BIT == MAX_EPOCH_BIT) {
                // If left-most bit is true, we have something to realize; push pending to realized.
                // Do any updates needed to realize an amount for an account.
                ToRealize memory epochRealized = accountEpochToRealize[_account][lastUpdateEpoch];
                pending -= epochRealized.pending;
                realized += epochRealized.pending;

                if (locked > 0) {
                    // skip if `locked == 0` to avoid issues after disabling locks
                    locked -= epochRealized.locked;
                    realized += epochRealized.locked;
                }

                if (pending == 0 && locked == 0) break; // All pending has been realized. No need to continue.
            }
        }

        // Fill in any missed epochs.
        while (lastUpdateEpoch < _systemEpoch) {
            unchecked {
                lastUpdateEpoch++;
            }
            epochWeights[lastUpdateEpoch] = weight;
        }

        // Write new account data to storage.
        acctData = AccountData({
            updateEpochBitmap: bitmap,
            pendingStake: uint112(pending),
            realizedStake: uint112(realized),
            lockedStake: uint112(locked),
            lastUpdateEpoch: uint16(_systemEpoch)
        });
    }

    function _checkpointGlobal(uint256 systemEpoch) internal returns (uint256) {
        // These two share a storage slot.
        uint16 lastUpdateEpoch = globalLastUpdateEpoch;
        uint256 rate = globalGrowthRate;

        uint128 weight = globalEpochWeights[lastUpdateEpoch];

        if (weight == 0) {
            globalLastUpdateEpoch = uint16(systemEpoch);
            return 0;
        }

        if (lastUpdateEpoch == systemEpoch) {
            return weight;
        }

        while (lastUpdateEpoch < systemEpoch) {
            unchecked {
                lastUpdateEpoch++;
            }
            weight += _getWeightGrowth(rate, 1);
            globalEpochWeights[lastUpdateEpoch] = weight;
            rate -= globalEpochToRealize[lastUpdateEpoch];
        }

        globalGrowthRate = uint112(rate);
        globalLastUpdateEpoch = uint16(systemEpoch);

        return weight;
    }
}

// 1111111111111111