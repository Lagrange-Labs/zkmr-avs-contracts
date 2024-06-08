# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

VERBOSITY=-vvvv
# VERBOSITY=
LOCAL_DEPLOY_FLAGS=--broadcast ${VERBOSITY} --ffi --slow
DEPLOY_FLAGS=--verify ${LOCAL_DEPLOY_FLAGS}
MAINNET_DEPLOYER=--account v0_owner --sender ${DEPLOYER_ADDR}

DEPLOY_PROXY_FACTORY_CMD=forge script DeployERC1967ProxyFactory --rpc-url
DEPLOY_AVS_CMD=forge script DeployAVS --rpc-url

# deps
install :; forge install
update  :; forge update

# Build & test
build    :; forge build
test     :; forge test
trace    :; forge test -vvv
clean    :; forge clean
snapshot :; forge snapshot
fmt      :; forge fmt

# -- Integration Test ---
setup_integration_test             :; local_deploy_erc1967_proxy_factory local_deploy_avs
local_deploy_erc1967_proxy_factory :; ${DEPLOY_PROXY_FACTORY_CMD} local ${LOCAL_DEPLOY_FLAGS} --json

# --- Deploy ---
# Deploy Eigenlayer AVS
local_deploy_avs   :; ${DEPLOY_AVS_CMD} local ${LOCAL_DEPLOY_FLAGS}
testnet_deploy_avs :; ${DEPLOY_AVS_CMD} holesky ${DEPLOY_FLAGS} --priority-gas-price 0.1gwei
mainnet_deploy_avs :; ${DEPLOY_AVS_CMD} mainnet ${DEPLOY_FLAGS} --priority-gas-price 0.5gwei ${MAINNET_DEPLOYER}
