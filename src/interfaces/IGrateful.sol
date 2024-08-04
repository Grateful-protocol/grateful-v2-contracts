// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {AaveV3ERC4626, IPool} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

/**
 * @title Grateful Contract Interface
 * @notice Interface for the Grateful contract that allows payments in whitelisted tokens with optional yield via AAVE.
 */
interface IGrateful {
  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Throws if the token is not whitelisted
   */
  error Grateful_TokenNotWhitelisted();

  /**
   * @notice Throws if the transfer failed
   */
  error Grateful_TransferFailed();

  /**
   * @notice Throws if the vault for a token is not set
   */
  error Grateful_VaultNotSet();

  /**
   * @notice Throws if the token is not whitelisted when adding a vault
   */
  error Grateful_VaultTokenNotWhitelisted();

  /*///////////////////////////////////////////////////////////////
                            VARIABLES
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Aave pool for yielding merchants funds
   * @return _aavePool Aave pool
   */
  function aavePool() external view returns (IPool _aavePool);

  /**
   * @notice Whitelist of tokens that can be used to pay
   * @return _isWhitelisted True if the token is whitelisted
   */
  function tokensWhitelisted(address _token) external view returns (bool _isWhitelisted);

  /**
   * @notice Returns the status of the merchant
   * @return _isYieldingFunds True if the merchant is yielding funds
   */
  function yieldingFunds(address _merchant) external view returns (bool _isYieldingFunds);

  /**
   * @notice Returns the vault associated with a token
   * @return _vault Address of the vault contract
   */
  function vaults(address _token) external view returns (AaveV3ERC4626 _vault);

  /**
   * @notice Returns the amount of shares for a merchant
   * @return _shares Amount of shares
   */
  function shares(address _merchant, address _token) external view returns (uint256 _shares);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Makes a payment to a merchant
   * @param _merchant Address of the merchant receiving payment
   * @param _token Address of the token being used for payment
   * @param _amount Amount of the token to be paid
   */
  function pay(address _merchant, address _token, uint256 _amount) external;

  /**
   * @notice Switch the preference of the merchant to yield funds or not
   */
  function switchYieldingFunds() external;

  /**
   * @notice Adds a vault for a specific token
   * @param _token Address of the token for which the vault is being set
   * @param _vault Address of the vault contract
   */
  function addVault(address _token, address _vault) external;
}
