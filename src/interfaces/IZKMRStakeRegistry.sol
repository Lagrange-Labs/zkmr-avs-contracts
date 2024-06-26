// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IStrategy} from
    "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {ISignatureUtils} from
    "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";

/// @notice An Eigenlayer strategy and shares multiplier
/// @dev A strategy is a contract that represent an underlying staked asset (ERC20)
struct StrategyParams {
    IStrategy strategy;
    uint96 multiplier;
}

/// @notice A `quorum` of Eigenlayer strategies and shares multipliers
/// @dev An array of strategy parameters define the quorum
struct Quorum {
    StrategyParams[] strategies;
}

/// @notice A point on an elliptic curve
/// @dev Used to represent an ECDSA public key
struct PublicKey {
    uint256 x;
    uint256 y;
}

interface IZKMRStakeRegistry {
    /// @notice Emitted when the operator registers
    /// @param operator The address of the registered operator
    /// @param avs The address of the associated AVS
    /// @param publicKey The ECDSA public key used only for the zkmr AVS
    event OperatorRegistered(
        address indexed operator, address indexed avs, PublicKey publicKey
    );

    /// @notice Emitted when the operator deregisters themself
    /// @param operator The address of the deregistered operator
    /// @param avs The address of the associated AVS
    event OperatorDeregistered(address indexed operator, address indexed avs);

    /// @notice Emitted when the operator updates their key
    /// @param operator The address of the updated operator
    /// @param avs The address of the associated AVS
    /// @param publicKey The ECDSA public key used only for the zkmr AVS
    event OperatorUpdated(
        address indexed operator, address indexed avs, PublicKey publicKey
    );

    /// @notice Emitted when the administrator deregisters an operator
    /// @param operator The address of the deregistered operator
    /// @param avs The address of the associated AVS
    event OperatorEvicted(address indexed operator, address indexed avs);

    /// @notice Emitted when the system updates the quorum
    /// @param oldQuorum The previous quorum configuration
    /// @param newQuorum The new quorum configuration
    event QuorumUpdated(Quorum oldQuorum, Quorum newQuorum);

    /// @notice Emitted when the shares to join the operator set updates
    /// @param oldShares The previous minimum shares
    /// @param newShares The new minimumShares
    event MinimumSharesUpdated(uint256 oldShares, uint256 newShares);

    /// @notice Thrown when setting the service manager address after it has already been set
    error ServiceManagerAlreadySet();

    /// @notice Thrown when operator specifies an invalid public key on registration and key rotation
    error InvalidPublicKey();

    /// @notice Thrown when operator tries to register a public key that has already been registered at any point in the past
    error KeyHasBeenUsed();

    /// @notice Indicates the quorum is invalid
    error InvalidQuorum();

    /// @notice Indicates the system finds a list of items unsorted
    error NotSorted();

    /// @notice Thrown when operator tries to register with less than minimum shares
    error InsufficientShares();

    /// @notice Thrown when registering an already registered operator
    error OperatorAlreadyRegistered();

    /// @notice Thrown when de-registering or updating the stake for an unregisted operator
    error OperatorNotRegistered();

    /// @notice Retrieves the current stake quorum details.
    /// @return Quorum - The current quorum of strategies and multipliers
    function quorum() external view returns (Quorum memory);

    /// @notice Checks registration status based on whether public key is set.
    /// @param operator The address of the operator.
    function isRegistered(address operator) external view returns (bool);

    /// @notice Updates the quorum configuration
    /// @dev Only callable by the contract owner.
    /// @param _quorum The new quorum configuration, including strategies and their new multipliers
    function updateQuorumConfig(Quorum memory _quorum) external;

    /// @notice Registers a new operator using a provided signature
    /// @param publicKey The ECDSA public key used only for the zkmr AVS
    /// @param operatorSignature Contains the operator's signature, salt, and expiry
    function registerOperator(
        PublicKey calldata publicKey,
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature
    ) external;

    /// @notice Deregisters an existing operator
    function deregisterOperator() external;

    /// @notice Calculates the current shares of an operator based on their delegated stake in the strategies considered in the quorum
    /// @param operator The address of the operator.
    /// @return uint256 - The current shares of the operator.
    function getOperatorShares(address operator)
        external
        view
        returns (uint256);

    /// @notice Updates the shares an operator must have to join the operator set
    /// @dev Access controlled to the contract owner
    /// @param newMinimumShares The new shares an operator must have to join the operator set
    function updateMinimumShares(uint256 newMinimumShares) external;
}
