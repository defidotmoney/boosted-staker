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
def factory(StakerFactory, deployer):
    return StakerFactory.deploy(EPOCH_DAYS, MAX_GROWTH_EPOCHS, {"from": deployer})


@pytest.fixture(scope="module")
def staker(BoostedStaker, factory, token, deployer):
    factory.deployBoostedStaker(token, MAX_WEIGHT_MULTIPLIER, {"from": deployer})
    return BoostedStaker.at(factory.boostedStakers(token))
