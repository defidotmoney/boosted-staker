import pytest

from brownie import chain


@pytest.fixture(scope="module", autouse=True)
def setup(token, staker, alice):
    token.approve(staker, 2**256 - 1, {"from": alice})
    token._mint_for_testing(alice, 10**20)


@pytest.mark.parametrize("unstake_week", (1, 9, 10, 11, 15, 16, 17))
def test_weight_adjustments(staker, alice, unstake_week):
    staker.stake(10**18, {"from": alice})

    for i in range(1, 18):
        chain.mine(timedelta=604801)
        if i == unstake_week:
            staker.unstake(10**18, alice, {"from": alice})

        if i < unstake_week:
            assert staker.getAccountWeight(alice) == 10**18 + (10**18 * min(i, 10) // 10)
            assert staker.getGlobalWeight() == 10**18 + (10**18 * min(i, 10) // 10)
            assert staker.balanceOf(alice) == 10**18
        else:
            assert staker.getAccountWeight(alice) == 0
            assert staker.getGlobalWeight() == 0
            assert staker.balanceOf(alice) == 0


@pytest.mark.parametrize("unstake_week", (1, 9, 10, 11, 15, 16, 17))
def test_weight_adjustments_with_checkpoint(staker, alice, unstake_week):
    staker.stake(10**18, {"from": alice})

    for i in range(1, 18):
        chain.mine(timedelta=604801)
        staker.checkpointAccount(alice, {"from": alice})
        staker.checkpointGlobal({"from": alice})

        if i == unstake_week:
            staker.unstake(10**18, alice, {"from": alice})

        if i < unstake_week:
            assert staker.getAccountWeight(alice) == 10**18 + (10**18 * min(i, 10) // 10)
            assert staker.getGlobalWeight() == 10**18 + (10**18 * min(i, 10) // 10)
            assert staker.balanceOf(alice) == 10**18
        else:
            assert staker.getAccountWeight(alice) == 0
            assert staker.getGlobalWeight() == 0
            assert staker.balanceOf(alice) == 0