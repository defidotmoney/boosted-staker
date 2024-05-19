# boosted-staker

Token staker with boosted weighting based on deposit duration.

Based on Yearn's [`yearn-boosted-staker`](https://github.com/yearn/yearn-boosted-staker).

## Overview

### `BoostedStaker`

* `BoostedStaker` defines periods of time known as "epochs". Each epoch is `EPOCH_LENGTH` seconds long.
* Users deposit ERC20 tokens into `BoostedStaker` in order to receive "weight". The amount of weight is based on the number of epochs that have passed since the deposit.
* Weight starts 1:1 with the number of tokens deposited. Weight increases linearly over `STAKE_GROWTH_EPOCHS` until 1 token is equal to `MAX_WEIGHT_MULTIPLIER`.
* Staked tokens can be withdrawn at any time. Partial withdrawals always start with tokens that were deposited most recently (and so give the least weight).
* Users can also choose to lock their tokens at the time of deposit. Locked tokens immediately receive the maximum possible weight. Locked tokens cannot be withdrawn until `STAKE_GROWTH_EPOCHS` have passed.

### `StakerFactory`

* `StakerFactory` deploys `BoostedStaker` contracts and defines shared constants across all deployments.
* The factory owner also owns all staker contracts.
* The owner can disable locks across all `BoostedStaker` deployments at the same time. This is useful when sunsetting the protocol, to allow users to withdraw.
