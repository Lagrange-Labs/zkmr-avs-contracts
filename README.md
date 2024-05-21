# ZK Coprocessor AVS
This repository contains smart contracts for the Eigenlayer AVS (zkMapReduce AVS ServiceManager). These contracts are designed to manage operators and their associated strategies within the Eigenlayer ecosystem.

## Key structs and contracts
### StrategyParams
Represents an Eigenlayer strategy and weight multiplier.

```solidity
struct StrategyParams {
    IStrategy strategy;
    uint96 multiplier;
}
```

### Quorum
Defines a quorum of Eigenlayer strategies (i.e. restaked tokens) and weight multipliers.

```solidity
struct Quorum {
    StrategyParams[] strategies;
}
```

### PublicKey
Represents a point on an elliptic curve for ECDSA public keys.
Operators authenticate within the AVS by signed JWTs and proofs with this public key after registering onchain.

```solidity
struct PublicKey {
    uint256 x;
    uint256 y;
}
```

### IZKMRStakeRegistry
Interface for the ZKMR Stake Registry, which manages operator registrations, deregistrations, and quorum configurations.

```solidity
Copy code
interface IZKMRStakeRegistry {
    // Events
    event OperatorRegistered(address indexed operator, address indexed avs, PublicKey publicKey);
    event OperatorDeregistered(address indexed operator, address indexed avs);
    event OperatorUpdated(address indexed operator, address indexed avs, PublicKey publicKey);
    event OperatorEvicted(address indexed operator, address indexed avs);
    event QuorumUpdated(Quorum oldQuorum, Quorum newQuorum);
    event MinimumWeightUpdated(uint256 oldWeight, uint256 newWeight);

    // Errors
    error ServiceManagerAlreadySet();
    error InvalidPublicKey();
    error InvalidQuorum();
    error NotSorted();
    error OperatorAlreadyRegistered();
    error OperatorNotRegistered();

    // Functions
    function quorum() external view returns (Quorum memory);
    function isRegistered(address operator) external view returns (bool);
    function updateQuorumConfig(Quorum memory _quorum) external;
    function registerOperator(PublicKey calldata publicKey, ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature) external;
    function deregisterOperator() external;
    function getOperatorShares(address operator) external view returns (uint256);
    function getOperatorWeight(address operator) external view returns (uint256);
    function updateMinimumWeight(uint256 newMinimumWeight) external;
}
```

### ZKMRServiceManager
Manages AVS metadata, operator registrations, and quorum configurations. Only the ZKMRStakeRegistry can call certain functions.

## Commands and Scripts
### Environment Setup
Ensure to include a .env file and export its environment variables.

### Installation
Install dependencies:

```shell
$ forge install
$ forge update
```

### Build & Test

```shell
$ forge build
$ forge test
$ forge test -vvv
```

### Deployment

```shell
# Local development
$ anvil
$ make setup_integration_test
$ make local_deploy_avs

# Deploy to Holesky Testnet
$ make testnet_deploy_avs
```
