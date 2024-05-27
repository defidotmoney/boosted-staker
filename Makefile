-include .env

.EXPORT_ALL_VARIABLES:
MAKEFLAGS += --no-print-directory
ETHERSCAN_API_KEY=$(ETHERSCAN_KEY)

default:
	forge fmt && forge build

# Always keep Forge up to date
install:
	foundryup
	forge install

snapshot:
	@forge snapshot

# Testing
test:
	@forge test

test-f-%:
	@FOUNDRY_MATCH_TEST=$* make test 

test-c-%:
	@FOUNDRY_MATCH_CONTRACT=$* make test

test-%:
	@FOUNDRY_TEST=test/$* make test

# Coverage
coverage:
	@forge coverage --report lcov
	@lcov --ignore-errors unused --remove ./lcov.info -o ./lcov.info.pruned "test/*" "script/*"

coverage-html:
	@make coverage
	@genhtml ./lcov.info.pruned -o report --branch-coverage --output-dir ./coverage
	@rm ./lcov.info*

# Deployment
simulate-%:
	@forge script script/$*.s.sol --fork-url $(RPC_URL_MAINNET) -vvvvv

run-%:
	@forge script script/$*.s.sol --rpc-url  $(RPC_URL_MAINNET) --private-key $(PRIVATE_KEY) --broadcast --slow -vvvvv 

deploy-%:
	@forge script script/$*.s.sol --rpc-url  $(RPC_URL_MAINNET) --private-key ${PRIVATE_KEY} --broadcast --slow --verify --with-gas-price 40000000000 -vvvvv

.PHONY: test coverage
