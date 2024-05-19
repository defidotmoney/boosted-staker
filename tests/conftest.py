import pytest
from brownie_tokens import ERC20


MAX_GROWTH_EPOCHS = 10
MAX_WEIGHT_MULTIPLIER = 2
EPOCH_DAYS = 3


@pytest.fixture(scope="function", autouse=True)
def base_setup(fn_isolation):
    pass


@pytest.fixture(scope="module")
def deployer(accounts):
    return accounts[0]


@pytest.fixture(scope="module")
def alice(accounts):
    return accounts[1]


@pytest.fixture(scope="module")
def token():
    return ERC20(success=True, fail="revert")


@pytest.fixture(scope="module")
def staker(BoostedStaker, token, deployer):
    return BoostedStaker.deploy(
        token, MAX_GROWTH_EPOCHS, MAX_WEIGHT_MULTIPLIER, 0, EPOCH_DAYS, {"from": deployer}
    )
