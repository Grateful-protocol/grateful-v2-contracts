// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';

/**
 * @title Grateful Contract
 * @author Chin
 * @notice Contract for allowing payments in whitelisted tokens. Payments can be done using Uniswap's Permit2. Merchants can choose to yield their payments in AAVE and withdraw them at any time. Recurring payments are enabled by using Chainlink Keepers
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

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Makes a payment to merchant
   */
  function pay(address _merchant, address _token, uint256 _amount) external;

  /**
   * @notice Switch the preference of the merchant to yield funds or not
   */
  function switchYieldingFunds() external;
}
