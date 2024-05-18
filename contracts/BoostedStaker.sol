// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.25;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
    @notice Boosted Staker
    @author Yearn (with edits by defidotmoney)
 */
contract BoostedStaker {
    using SafeERC20 for IERC20;

    uint public immutable MAX_STAKE_GROWTH_WEEKS;
    uint16 public immutable MAX_WEEK_BIT;
    uint public immutable START_TIME;
    uint public immutable EPOCH_LENGTH;
    IERC20 public immutable stakeToken;

    // Account weight tracking state vars.
    mapping(address account => AccountData data) public accountData;
    mapping(address account => mapping(uint week => uint weight)) private accountWeeklyWeights;
    mapping(address account => mapping(uint week => ToRealize weight)) public accountWeeklyToRealize;

    // Global weight tracking stats vars.
    uint112 public globalGrowthRate;
    uint16 public globalLastUpdateWeek;
    mapping(uint week => uint weight) private globalWeeklyWeights;
    mapping(uint week => ToRealize weight) public globalWeeklyToRealize;

    // Generic token interface.
    uint public totalSupply;

    // Permissioned roles
    address public owner;
    address public pendingOwner;
    mapping(address account => mapping(address caller => ApprovalStatus approvalStatus)) public approvedCaller;

    struct ToRealize {
        uint128 weightPersistent;
        uint128 weight;
    }

    struct AccountData {
        uint112 realizedStake; // Amount of stake that has fully realized weight.
        uint112 pendingStake; // Amount of stake that has not yet fully realized weight.
        uint16 lastUpdateWeek; // Week of last sync.
        // One byte member to represent weeks in which an account has pending weight changes.
        // A bit is set to true when the account has a non-zero token balance to be realized in
        // the corresponding week. We use this as a "map", allowing us to reduce gas consumption
        // by avoiding unnecessary lookups on weeks which an account has zero pending stake.
        //
        // Example: 0100000000000001
        // The left-most bit represents the final week of pendingStake.
        // Therefore, we can see that account has stake updates to process only in weeks 15 and 1.
        uint16 updateWeeksBitmap;
    }

    enum ApprovalStatus {
        None, // 0. Default value, indicating no approval
        StakeOnly, // 1. Approved for stake only
        UnstakeOnly, // 2. Approved for unstake only
        StakeAndUnstake // 3. Approved for both stake and unstake
    }

    event Staked(address indexed account, uint indexed week, uint amount, uint newUserWeight, uint weightAdded);
    event Unstaked(address indexed account, uint indexed week, uint amount, uint newUserWeight, uint weightRemoved);
    event ApprovedCallerSet(address indexed account, address indexed caller, ApprovalStatus status);
    event OwnershipTransferred(address indexed newOwner);

    /**
        @param _token The token to be staked.
        @param _max_stake_growth_weeks The number of weeks a stake will grow for.
                            Not including desposit week.
        @param _start_time  allows deployer to optionally set a custom start time.
                            useful if needed to line up with week count in another system.
                            Passing a value of 0 will start at block.timestamp.
        @param _owner       Owner is able to grant access to stake with max boost.
    */
    constructor(address _token, uint _max_stake_growth_weeks, uint _start_time, uint epoch_days, address _owner) {
        owner = _owner;
        emit OwnershipTransferred(_owner);
        stakeToken = IERC20(_token);
        require(_max_stake_growth_weeks > 0 && _max_stake_growth_weeks <= 15, "Invalid weeks");
        MAX_STAKE_GROWTH_WEEKS = _max_stake_growth_weeks;
        MAX_WEEK_BIT = uint16(1 << MAX_STAKE_GROWTH_WEEKS);
        EPOCH_LENGTH = epoch_days * 1 days;
        if (_start_time == 0) {
            START_TIME = block.timestamp;
        } else {
            require(_start_time <= block.timestamp, "!Past");
            START_TIME = _start_time;
        }
    }

    /**
        @notice Stake tokens into the staking contract.
        @param _amount Amount of tokens to stake.
    */
    function stake(uint _amount) external returns (uint) {
        return _stake(msg.sender, _amount);
    }

    function stakeFor(address _account, uint _amount) external returns (uint) {
        if (msg.sender != _account) {
            ApprovalStatus status = approvedCaller[_account][msg.sender];
            require(status == ApprovalStatus.StakeAndUnstake || status == ApprovalStatus.StakeOnly, "!Permission");
        }

        return _stake(_account, _amount);
    }

    function _stake(address _account, uint _amount) internal returns (uint) {
        require(_amount > 1 && _amount < type(uint112).max, "invalid amount");

        // Before going further, let's sync our account and global weights
        uint systemWeek = getEpoch();
        (AccountData memory acctData, uint accountWeight) = _checkpointAccount(_account, systemWeek);
        uint112 globalWeight = uint112(_checkpointGlobal(systemWeek));

        uint weight = _amount;

        acctData.pendingStake += uint112(weight);
        globalGrowthRate += uint112(weight);

        uint realizeWeek = systemWeek + MAX_STAKE_GROWTH_WEEKS;
        ToRealize memory toRealize = accountWeeklyToRealize[_account][realizeWeek];
        toRealize.weight += uint128(weight);
        toRealize.weightPersistent += uint128(weight);
        accountWeeklyToRealize[_account][realizeWeek] = toRealize;

        toRealize = globalWeeklyToRealize[realizeWeek];
        toRealize.weight += uint128(weight);
        toRealize.weightPersistent += uint128(weight);
        globalWeeklyToRealize[realizeWeek] = toRealize;

        accountWeeklyWeights[_account][systemWeek] = accountWeight + weight;
        globalWeeklyWeights[systemWeek] = globalWeight + weight;

        acctData.updateWeeksBitmap |= 1; // Use bitwise or to ensure bit is flipped at least weighted position.
        accountData[_account] = acctData;
        totalSupply += _amount;

        stakeToken.safeTransferFrom(msg.sender, address(this), uint(_amount));
        emit Staked(_account, systemWeek, _amount, accountWeight + weight, weight);

        return _amount;
    }

    /**
        @notice Unstake tokens from the contract.
        @dev During partial unstake, this will always remove from the least-weighted first.
    */
    function unstake(uint _amount, address _receiver) external returns (uint) {
        return _unstake(msg.sender, _amount, _receiver);
    }

    /**
        @notice Unstake tokens from the contract on behalf of another user.
        @dev During partial unstake, this will always remove from the least-weighted first.
    */
    function unstakeFor(address _account, uint _amount, address _receiver) external returns (uint) {
        if (msg.sender != _account) {
            ApprovalStatus status = approvedCaller[_account][msg.sender];
            require(status == ApprovalStatus.StakeAndUnstake || status == ApprovalStatus.UnstakeOnly, "!Permission");
        }
        return _unstake(_account, _amount, _receiver);
    }

    function _unstake(address _account, uint _amount, address _receiver) internal returns (uint) {
        require(_amount > 1 && _amount < type(uint112).max, "invalid amount");
        uint systemWeek = getEpoch();

        // Before going further, let's sync our account and global weights
        (AccountData memory acctData, ) = _checkpointAccount(_account, systemWeek);
        _checkpointGlobal(systemWeek);

        // Here we do work to pull from most recent (least weighted) stake first
        uint16 bitmap = acctData.updateWeeksBitmap;
        uint128 weightToRemove;

        uint128 amountNeeded = uint128(_amount);

        if (bitmap > 0) {
            for (uint128 weekIndex; weekIndex < MAX_STAKE_GROWTH_WEEKS; ) {
                // Move right to left, checking each bit if there's an update for corresponding week.
                uint16 mask = uint16(1 << weekIndex);
                if (bitmap & mask == mask) {
                    uint weekToCheck = systemWeek + MAX_STAKE_GROWTH_WEEKS - weekIndex;
                    uint128 pending = accountWeeklyToRealize[_account][weekToCheck].weight;
                    if (amountNeeded > pending) {
                        weightToRemove += _getWeight(pending, weekIndex);
                        accountWeeklyToRealize[_account][weekToCheck].weight = 0;
                        globalWeeklyToRealize[weekToCheck].weight -= pending;
                        if (weekIndex == 0) {
                            // Current system week
                            accountWeeklyToRealize[_account][weekToCheck].weightPersistent = 0;
                            globalWeeklyToRealize[weekToCheck].weightPersistent -= pending;
                        }
                        bitmap = bitmap ^ mask;
                        amountNeeded -= pending;
                    } else {
                        // handle the case where we have more pending than needed
                        weightToRemove += _getWeight(amountNeeded, weekIndex);
                        accountWeeklyToRealize[_account][weekToCheck].weight -= amountNeeded;
                        globalWeeklyToRealize[weekToCheck].weight -= amountNeeded;
                        if (weekIndex == 0) {
                            // Current system week
                            accountWeeklyToRealize[_account][weekToCheck].weightPersistent -= amountNeeded;
                            globalWeeklyToRealize[weekToCheck].weightPersistent -= amountNeeded;
                        }
                        if (amountNeeded == pending) bitmap = bitmap ^ mask;
                        amountNeeded = 0;
                        break;
                    }
                }
                unchecked {
                    weekIndex++;
                }
            }
            acctData.updateWeeksBitmap = bitmap;
        }

        uint pendingRemoved = _amount - amountNeeded;
        if (amountNeeded > 0) {
            weightToRemove += _getWeight(amountNeeded, MAX_STAKE_GROWTH_WEEKS);
            acctData.realizedStake -= uint112(amountNeeded);
            acctData.pendingStake = 0;
        } else {
            acctData.pendingStake -= uint112(pendingRemoved);
        }

        accountData[_account] = acctData;

        globalGrowthRate -= uint112(pendingRemoved);
        globalWeeklyWeights[systemWeek] -= weightToRemove;
        uint newAccountWeight = accountWeeklyWeights[_account][systemWeek] - weightToRemove;
        accountWeeklyWeights[_account][systemWeek] = newAccountWeight;

        totalSupply -= _amount;

        emit Unstaked(_account, systemWeek, _amount, newAccountWeight, weightToRemove);

        stakeToken.safeTransfer(_receiver, _amount);

        return _amount;
    }

    /**
        @notice Get the current realized weight for an account
        @param _account Account to checkpoint.
        @return acctData Most recent account data written to storage.
        @return weight Most current account weight.
        @dev Prefer to use this function over it's view counterpart for
             contract -> contract interactions.
    */
    function checkpointAccount(address _account) external returns (AccountData memory acctData, uint weight) {
        (acctData, weight) = _checkpointAccount(_account, getEpoch());
        accountData[_account] = acctData;
    }

    /**
        @notice Checkpoint an account using a specified week limit.
        @dev    To use in the event that significant number of weeks have passed since last
                heckpoint and single call becomes too expensive.
        @param _account Account to checkpoint.
        @param _week Week which we want to checkpoint to.
        @return acctData Most recent account data written to storage.
        @return weight Account weight for provided week.
    */
    function checkpointAccountWithLimit(
        address _account,
        uint _week
    ) external returns (AccountData memory acctData, uint weight) {
        uint systemWeek = getEpoch();
        if (_week >= systemWeek) _week = systemWeek;
        (acctData, weight) = _checkpointAccount(_account, _week);
        accountData[_account] = acctData;
    }

    function _checkpointAccount(
        address _account,
        uint _systemWeek
    ) internal returns (AccountData memory acctData, uint weight) {
        acctData = accountData[_account];
        uint lastUpdateWeek = acctData.lastUpdateWeek;

        if (_systemWeek == lastUpdateWeek) {
            return (acctData, accountWeeklyWeights[_account][lastUpdateWeek]);
        }

        require(_systemWeek > lastUpdateWeek, "specified week is older than last update.");

        uint pending = uint(acctData.pendingStake);
        uint realized = acctData.realizedStake;

        if (pending == 0) {
            if (realized != 0) {
                weight = accountWeeklyWeights[_account][lastUpdateWeek];
                while (lastUpdateWeek < _systemWeek) {
                    unchecked {
                        lastUpdateWeek++;
                    }
                    // Fill in any missing weeks
                    accountWeeklyWeights[_account][lastUpdateWeek] = weight;
                }
            }
            accountData[_account].lastUpdateWeek = uint16(_systemWeek);
            acctData.lastUpdateWeek = uint16(_systemWeek);
            return (acctData, weight);
        }

        weight = accountWeeklyWeights[_account][lastUpdateWeek];
        uint16 bitmap = acctData.updateWeeksBitmap;
        uint targetSyncWeek = min(_systemWeek, lastUpdateWeek + MAX_STAKE_GROWTH_WEEKS);

        // Populate data for missed weeks
        while (lastUpdateWeek < targetSyncWeek) {
            unchecked {
                lastUpdateWeek++;
            }
            weight = _applyGrowthFactor(weight, pending);
            accountWeeklyWeights[_account][lastUpdateWeek] = weight;

            // Shift left on bitmap as we pass over each week.
            bitmap = bitmap << 1;
            if (bitmap & MAX_WEEK_BIT == MAX_WEEK_BIT) {
                // If left-most bit is true, we have something to realize; push pending to realized.
                // Do any updates needed to realize an amount for an account.
                uint toRealize = accountWeeklyToRealize[_account][lastUpdateWeek].weight;
                pending -= toRealize;
                realized += toRealize;
                if (pending == 0) break; // All pending has been realized. No need to continue.
            }
        }

        // Fill in any missed weeks.
        while (lastUpdateWeek < _systemWeek) {
            unchecked {
                lastUpdateWeek++;
            }
            accountWeeklyWeights[_account][lastUpdateWeek] = weight;
        }

        // Write new account data to storage.
        acctData = AccountData({
            updateWeeksBitmap: bitmap,
            pendingStake: uint112(pending),
            realizedStake: uint112(realized),
            lastUpdateWeek: uint16(_systemWeek)
        });
    }

    /**
        @notice View function to get the current weight for an account
    */
    function getAccountWeight(address account) external view returns (uint) {
        return getAccountWeightAt(account, getEpoch());
    }

    /**
        @notice Get the weight for an account in a given week
    */
    function getAccountWeightAt(address _account, uint _week) public view returns (uint) {
        if (_week > getEpoch()) return 0;

        AccountData memory acctData = accountData[_account];

        uint16 lastUpdateWeek = acctData.lastUpdateWeek;

        if (lastUpdateWeek >= _week) return accountWeeklyWeights[_account][_week];

        uint weight = accountWeeklyWeights[_account][lastUpdateWeek];

        uint pending = uint(acctData.pendingStake);
        if (pending == 0) return weight;

        uint16 bitmap = acctData.updateWeeksBitmap;

        while (lastUpdateWeek < _week) {
            // Populate data for missed weeks
            unchecked {
                lastUpdateWeek++;
            }
            weight = _applyGrowthFactor(weight, pending);

            // Our bitmap is used to determine if week has any amount to realize.
            bitmap = bitmap << 1;
            if (bitmap & MAX_WEEK_BIT == MAX_WEEK_BIT) {
                // If left-most bit is true, we have something to realize; push pending to realized.
                pending -= accountWeeklyToRealize[_account][lastUpdateWeek].weight;
                if (pending == 0) break; // All pending has now been realized, let's exit.
            }
        }

        return weight;
    }

    /**
        @notice Get the current total system weight
        @dev Also updates local storage values for total weights. Using
             this function over it's `view` counterpart is preferred for
             contract -> contract interactions.
    */
    function checkpointGlobal() external returns (uint) {
        uint systemWeek = getEpoch();
        return _checkpointGlobal(systemWeek);
    }

    /**
        @notice Get the current total system weight
        @dev Also updates local storage values for total weights. Using
             this function over it's `view` counterpart is preferred for
             contract -> contract interactions.
    */
    function _checkpointGlobal(uint systemWeek) internal returns (uint) {
        // These two share a storage slot.
        uint16 lastUpdateWeek = globalLastUpdateWeek;
        uint rate = globalGrowthRate;

        uint weight = globalWeeklyWeights[lastUpdateWeek];

        if (weight == 0) {
            globalLastUpdateWeek = uint16(systemWeek);
            return 0;
        }

        if (lastUpdateWeek == systemWeek) {
            return weight;
        }

        while (lastUpdateWeek < systemWeek) {
            unchecked {
                lastUpdateWeek++;
            }
            weight = _applyGrowthFactor(weight, rate);
            globalWeeklyWeights[lastUpdateWeek] = weight;
            rate -= globalWeeklyToRealize[lastUpdateWeek].weight;
        }

        globalGrowthRate = uint112(rate);
        globalLastUpdateWeek = uint16(systemWeek);

        return weight;
    }

    /**
        @notice Get the system weight for current week.
    */
    function getGlobalWeight() external view returns (uint) {
        return getGlobalWeightAt(getEpoch());
    }

    /**
        @notice Get the system weight for a specified week in the past.
        @dev querying a week in the future will always return 0.
        @param week the week number to query global weight for.
    */
    function getGlobalWeightAt(uint week) public view returns (uint) {
        uint systemWeek = getEpoch();
        if (week > systemWeek) return 0;

        // Read these together since they are packed in the same slot.
        uint16 lastUpdateWeek = globalLastUpdateWeek;
        uint rate = globalGrowthRate;

        if (week <= lastUpdateWeek) return globalWeeklyWeights[week];

        uint weight = globalWeeklyWeights[lastUpdateWeek];
        if (rate == 0) {
            return weight;
        }

        while (lastUpdateWeek < week) {
            unchecked {
                lastUpdateWeek++;
            }
            weight = _applyGrowthFactor(weight, rate);
            rate -= globalWeeklyToRealize[lastUpdateWeek].weight;
        }

        return weight;
    }

    /**
        @notice Returns the balance of underlying staked tokens for an account
        @param _account Account to query balance.
        @return balance of account.
    */
    function balanceOf(address _account) external view returns (uint) {
        AccountData memory acctData = accountData[_account];
        return (acctData.pendingStake + acctData.realizedStake);
    }

    /**
        @notice Allow another address to stake or unstake on behalf of. Useful for zaps and other functionality.
        @param _caller Address of the caller to approve or unapprove.
        @param _status Enum representing various approval status states.
    */
    function setApprovedCaller(address _caller, ApprovalStatus _status) external {
        approvedCaller[msg.sender][_caller] = _status;
        emit ApprovedCallerSet(msg.sender, _caller, _status);
    }

    /**
        @notice Set a pending owner which can later be accepted.
        @param _pendingOwner Address of the new owner.
    */
    function transferOwnership(address _pendingOwner) external {
        require(msg.sender == owner, "!authorized");
        pendingOwner = _pendingOwner;
    }

    /**
        @notice Allow pending owner to accept ownership
    */
    function acceptOwnership() external {
        require(msg.sender == pendingOwner, "!authorized");
        owner = msg.sender;
        pendingOwner = address(0);
        emit OwnershipTransferred(msg.sender);
    }

    function sweep(address _token) external {
        require(msg.sender == owner, "!authorized");
        uint amount = IERC20(_token).balanceOf(address(this));
        if (_token == address(stakeToken)) {
            amount = amount - totalSupply;
        }
        if (amount > 0) IERC20(_token).safeTransfer(owner, amount);
    }

    function getEpoch() public view returns (uint week) {
        unchecked {
            return (block.timestamp - START_TIME) / EPOCH_LENGTH;
        }
    }

    function min(uint a, uint b) internal pure returns (uint) {
        return a < b ? a : b;
    }

    function _applyGrowthFactor(uint256 currentWeight, uint256 pendingStake) internal view returns (uint256 newWeight) {
        return currentWeight + (pendingStake / MAX_STAKE_GROWTH_WEEKS);
    }

    function _getWeight(uint256 pendingStake, uint256 stakedWeeks) internal view returns (uint128 weight) {
        uint256 weightMul = (pendingStake * stakedWeeks) / MAX_STAKE_GROWTH_WEEKS;
        return uint128(pendingStake + weightMul);
    }
}
