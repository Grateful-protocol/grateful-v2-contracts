// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {OneTime} from "contracts/OneTime.sol";
import {AaveV3ERC4626, IPool} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

/**
 * @title Grateful Contract Interface
 * @notice Interface for the Grateful contract that allows payments in whitelisted tokens with optional yield via AAVE.
 */
interface IGrateful {
  /*//////////////////////////////////////////////////////////////
    /                             STRUCTS
    //////////////////////////////////////////////////////////////*/

  struct Subscription {
    address token;
    address sender;
    uint256 amount;
    address receiver;
    uint40 interval;
    uint40 lastPaymentTime;
    uint16 paymentsAmount;
  }

  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a payment is processed
   * @param sender Address of the sender
   * @param merchant Address of the merchant
   * @param token Address of the token
   * @param amount Amount of the token
   * @param yielded Indicates if the payment was yielded
   */
  event PaymentProcessed(
    address sender,
    address merchant,
    address token,
    uint256 amount,
    bool yielded,
    uint256 paymentId,
    uint256 subscriptionId
  );

  event OneTimePaymentCreated(address merchant, address token, uint256 amount);

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

  /**
   * @notice Throws if the subscription does not exist
   */
  error Grateful_SubscriptionDoesNotExist();

  /**
   * @notice Throws if the subscription is too early for the next payment
   */
  error Grateful_TooEarlyForNextPayment();

  /**
   * @notice Throws if the sender is not the owner of the subscription
   */
  error Grateful_OnlySenderCanCancelSubscription();

  /**
   * @notice Throws if the payments amount has been reached
   */
  error Grateful_PaymentsAmountReached();

  /**
   * @notice Throws if the one-time payment is not found
   */
  error Grateful_OneTimeNotFound();

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

  /**
   * @notice Returns the number of subscriptions
   * @return _subscriptionCount Number of subscriptions
   */
  function subscriptionCount() external view returns (uint256 _subscriptionCount);

  /**
   * @notice Returns the fee applied to the payments
   * @return _fee Fee applied to the payments
   */
  function fee() external view returns (uint256);

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Adds a token to the whitelist
   * @param _token Address of the token to be added to the whitelist
   */
  function addToken(address _token) external;

  /**
   * @notice Makes a payment to a merchant
   * @param _merchant Address of the merchant receiving payment
   * @param _token Address of the token being used for payment
   * @param _amount Amount of the token to be paid
   * @param _id Id of the payment
   */
  function pay(address _merchant, address _token, uint256 _amount, uint256 _id) external;

  /**
   *  @notice Subscribes to a token for a specific amount and interval
   * @param _token Address of the token being subscribed
   * @param _receiver Address of the receiver of the payments
   * @param _amount Amount of the token to be paid
   * @param _interval Interval in seconds between payments
   * @return subscriptionId Id of the subscription
   */
  function subscribe(
    address _token,
    address _receiver,
    uint256 _amount,
    uint40 _interval,
    uint16 _paymentsAmount
  ) external returns (uint256 subscriptionId);

  /// @notice Creates a one-time payment
  /// @param _merchant Address of the merchant
  /// @param _token Address of the token
  /// @param _amount Amount of the token
  /// @return oneTime Contract of the one-time payment
  function createOneTimePayment(
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    address precomputed
  ) external returns (OneTime oneTime);

  /// @notice Receives a one-time payment
  /// @param _merchant Address of the merchant
  /// @param _token Address of the token
  /// @param _paymentId Id of the payment
  /// @param _amount Amount of the token
  function receiveOneTimePayment(address _merchant, address _token, uint256 _paymentId, uint256 _amount) external;

  /**
   * @notice Processes a subscription
   * @param subscriptionId Id of the subscription to be processed
   */
  function processSubscription(uint256 subscriptionId) external;

  /**
   * @notice Withdraws funds from the vault
   * @param _token Address of the token being withdrawn
   */
  function withdraw(address _token) external;

  /**
   * @notice Cancels a subscription
   * @param subscriptionId Id of the subscription to be cancelled
   */
  function cancelSubscription(uint256 subscriptionId) external;

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

  /// @notice Computes the address of a one-time payment
  /// @param _merchant Address of the merchant
  /// @param _token Address of the token
  /// @param _amount Amount of the token
  /// @param _salt Salt used to compute the address
  /// @return oneTime Address of the one-time payment
  function computeOneTimeAddress(
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId
  ) external view returns (OneTime oneTime);

  /**
   * @notice Calculates the id of a payment
   * @param _sender Address of the sender
   * @param _merchant Address of the merchant
   * @param _token Address of the token
   * @param _amount Amount of the token
   * @return id Id of the payment
   */
  function calculateId(
    address _sender,
    address _merchant,
    address _token,
    uint256 _amount
  ) external view returns (uint256);

  /// @notice Applies the fee to an amount
  /// @param amount Amount of the token
  /// @return amountWithFee Amount of the token with the fee applied
  function applyFee(uint256 amount) external view returns (uint256);
}
