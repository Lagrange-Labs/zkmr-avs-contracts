// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {OwnableWhitelist} from "./utils/OwnableWhitelist.sol";
import {IStrategy} from
    "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IDelegationManager} from
    "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {ISignatureUtils} from
    "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IServiceManager} from "./interfaces/IServiceManager.sol";
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    IZKMRStakeRegistry,
    Quorum,
    StrategyParams,
    PublicKey
} from "./interfaces/IZKMRStakeRegistry.sol";

/// @title zkMapReduce AVS Stake Registry
/// @notice Manages operator registration and quorum updates for the ZKMR AVS.
contract ZKMRStakeRegistry is
    IZKMRStakeRegistry,
    OwnableWhitelist,
    Initializable
{
    /// @dev The total amount of multipliers to weigh stakes
    uint256 private constant BPS = 10_000;

    /// @notice Manages staking delegations through the DelegationManager interface
    IDelegationManager public delegationManager;

    /// @notice The size of the current operator set
    uint256 public totalOperators;

    /// @notice Specifies the weight required to become an operator
    uint256 public minimumWeight;

    /// @notice Holds the address of the service manager
    IServiceManager public serviceManager;

    /// @notice Maps an operator to their zkmr ECDSA public key
    mapping(address operator => PublicKey publicKey) public operators;

    /// @notice Stores the current quorum configuration
    Quorum private _quorum;

    /// @notice Ensures unique registration of public keys
    mapping(bytes32 publicKeyHash => bool used) private usedKeys;

    /// @dev Reserves storage slots for future upgrades
    uint256[50] private __gap;

    modifier ensureValidPublicKey(PublicKey calldata publicKey) {
        if (publicKey.x == 0 || publicKey.y == 0) {
            revert InvalidPublicKey();
        }

        if (_keyHasBeenUsed(publicKey)) {
            revert KeyHasBeenUsed();
        }
        _;
    }

    modifier onlyRegistered(address operator) {
        if (!_isRegistered(operator)) {
            revert OperatorNotRegistered();
        }
        _;
    }

    /// @notice Initializes the contract with the given parameters.
    /// @param delegationManager_ The eigenlayer delegation manager.
    /// @param quorum_ The quorum struct containing the details of the quorum thresholds.
    /// @param owner_ The owner of the contract.
    function initialize(
        address delegationManager_,
        Quorum memory quorum_,
        address owner_
    ) external initializer {
        delegationManager = IDelegationManager(delegationManager_);
        _updateQuorumConfig(quorum_);
        OwnableWhitelist._initialize(owner_);
    }

    /// @notice Sets the service manager address.
    /// @param serviceManager_ The zkmr service manager.
    function setServiceManager(address serviceManager_) external onlyOwner {
        if (address(serviceManager) != address(0)) {
            revert ServiceManagerAlreadySet();
        }

        serviceManager = IServiceManager(serviceManager_);
    }

    function evictOperator(address operator)
        external
        onlyOwner
        onlyRegistered(operator)
    {
        _deregisterOperator(operator);

        emit OperatorEvicted(operator, address(serviceManager));
    }

    function registerOperator(
        PublicKey calldata publicKey,
        ISignatureUtils.SignatureWithSaltAndExpiry calldata operatorSignature
    ) external onlyWhitelist(msg.sender) ensureValidPublicKey(publicKey) {
        if (_isRegistered(msg.sender)) {
            revert OperatorAlreadyRegistered();
        }
        totalOperators++;
        operators[msg.sender] = publicKey;
        usedKeys[_pubkeyHash(publicKey)] = true;
        serviceManager.registerOperatorToAVS(msg.sender, operatorSignature);

        emit OperatorRegistered(msg.sender, address(serviceManager), publicKey);
    }

    function deregisterOperator() external onlyRegistered(msg.sender) {
        _deregisterOperator(msg.sender);

        emit OperatorDeregistered(msg.sender, address(serviceManager));
    }

    function updateOperatorKey(PublicKey calldata publicKey)
        external
        ensureValidPublicKey(publicKey)
        onlyRegistered(msg.sender)
    {
        operators[msg.sender] = publicKey;
        usedKeys[_pubkeyHash(publicKey)] = true;

        emit OperatorUpdated(msg.sender, address(serviceManager), publicKey);
    }

    function updateQuorumConfig(Quorum memory quorum_) external onlyOwner {
        _updateQuorumConfig(quorum_);
    }

    function updateMinimumWeight(uint256 newMinimumWeight) external onlyOwner {
        uint256 oldMinimumWeight = minimumWeight;
        minimumWeight = newMinimumWeight;
        emit MinimumWeightUpdated(oldMinimumWeight, newMinimumWeight);
    }

    function quorum() external view returns (Quorum memory) {
        return _quorum;
    }

    function isRegistered(address operator) external view returns (bool) {
        return _isRegistered(operator);
    }

    function keyHasBeenUsed(PublicKey memory publicKey)
        external
        view
        returns (bool)
    {
        return _keyHasBeenUsed(publicKey);
    }

    function getOperatorShares(address operator)
        external
        view
        returns (uint256)
    {
        return _getOperatorShares(operator);
    }

    function getOperatorWeight(address operator)
        external
        view
        returns (uint256)
    {
        uint256 weight = _getOperatorShares(operator) / BPS;

        if (weight >= minimumWeight) {
            return weight;
        } else {
            return 0;
        }
    }

    function _getOperatorShares(address operator)
        private
        view
        returns (uint256)
    {
        uint256 totalShares;
        StrategyParams[] memory strategyParams = _quorum.strategies;
        IStrategy[] memory strategies = new IStrategy[](strategyParams.length);

        for (uint256 i; i < strategyParams.length; i++) {
            strategies[i] = strategyParams[i].strategy;
        }

        uint256[] memory shares =
            delegationManager.getOperatorShares(operator, strategies);

        for (uint256 i; i < strategyParams.length; i++) {
            totalShares += shares[i] * strategyParams[i].multiplier;
        }

        return totalShares;
    }

    function _isRegistered(address operator) private view returns (bool) {
        return operators[operator].x != 0;
    }

    function _keyHasBeenUsed(PublicKey memory publicKey)
        private
        view
        returns (bool)
    {
        return usedKeys[_pubkeyHash(publicKey)];
    }

    function _deregisterOperator(address operator) private {
        totalOperators--;
        delete operators[operator];
        serviceManager.deregisterOperatorFromAVS(operator);
    }

    /// @notice Updates the quorum configuration
    /// @dev Replaces the current quorum configuration with `newQuorum` if valid.
    /// Reverts with `InvalidQuorum` if the new quorum configuration is not valid.
    /// Emits `QuorumUpdated` event with the old and new quorum configurations.
    /// @param newQuorum The new quorum configuration to set.
    function _updateQuorumConfig(Quorum memory newQuorum) private {
        if (!_isValidQuorum(newQuorum)) {
            revert InvalidQuorum();
        }
        Quorum memory oldQuorum = _quorum;
        delete _quorum;
        for (uint256 i; i < newQuorum.strategies.length; i++) {
            _quorum.strategies.push(newQuorum.strategies[i]);
        }
        emit QuorumUpdated(oldQuorum, newQuorum);
    }

    /// @dev Verifies that a specified quorum configuration is valid. A valid quorum has:
    ///      1. Weights that sum to exactly 10,000 basis points, ensuring proportional representation.
    ///      2. Unique strategies without duplicates to maintain quorum integrity.
    /// @param quorum_ The quorum configuration to be validated.
    /// @return bool True if the quorum configuration is valid, otherwise false.
    function _isValidQuorum(Quorum memory quorum_)
        private
        pure
        returns (bool)
    {
        StrategyParams[] memory strategies = quorum_.strategies;
        address lastStrategy;
        address currentStrategy;
        uint256 totalMultiplier;
        for (uint256 i; i < strategies.length; i++) {
            currentStrategy = address(strategies[i].strategy);
            if (lastStrategy >= currentStrategy) revert NotSorted();
            lastStrategy = currentStrategy;
            totalMultiplier += strategies[i].multiplier;
        }
        if (totalMultiplier != BPS) {
            return false;
        } else {
            return true;
        }
    }

    /// @dev Hash of x + y coordinates of operator's public key
    /// @return bytes32 keccak256 hash of 32 bytes of X and 32 bytes of Y
    function _pubkeyHash(PublicKey memory publicKey)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(publicKey.x, publicKey.y));
    }
}
