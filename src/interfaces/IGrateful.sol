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
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

  struct Subscription {
    address token;
    address sender;
    uint256 amount;
    uint256 subscriptionPlanId;
    address receiver;
    uint40 interval;
    uint16 paymentsAmount;
    uint40 lastPaymentTime;
    address[] recipients;
    uint256[] percentages;
  }

  struct PaymentDetails {
    address merchant;
    address token;
    uint256 amount;
    uint256 id;
    address[] recipients;
    uint256[] percentages;
  }

  /*///////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a payment is processed.
   * @param sender Address of the sender.
   * @param merchant Address of the merchant.
   * @param token Address of the token.
   * @param amount Amount of the token.
   * @param yielded Indicates if the payment was yielded.
   * @param paymentId ID of the payment.
   * @param subscriptionId ID of the subscription.
   */
  event PaymentProcessed(
    address indexed sender,
    address indexed merchant,
    address indexed token,
    uint256 amount,
    bool yielded,
    uint256 paymentId,
    uint256 subscriptionId
  );

  /**
   * @notice Emitted when a one-time payment is created.
   * @param merchant Address of the merchant.
   * @param token Address of the token.
   * @param amount Amount of the token.
   */
  event OneTimePaymentCreated(address indexed merchant, address indexed token, uint256 amount);

  event SubscriptionCreated(
    uint256 indexed subscriptionId,
    address indexed sender,
    address indexed receiver,
    uint256 amount,
    uint256 subscriptionPlanId
  );

  /*///////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when the token is not whitelisted.
  error Grateful_TokenNotWhitelisted();

  /// @notice Thrown when array lengths mismatch.
  error Grateful_MismatchedArrays();

  /// @notice Thrown when the total percentage is invalid.
  error Grateful_InvalidTotalPercentage();

  /// @notice Thrown when the vault for a token is not set.
  error Grateful_VaultNotSet();

  /// @notice Thrown when a token transfer fails.
  error Grateful_TransferFailed();

  /// @notice Thrown when the subscription does not exist.
  error Grateful_SubscriptionDoesNotExist();

  /// @notice Thrown when it's too early for the next subscription payment.
  error Grateful_TooEarlyForNextPayment();

  /// @notice Thrown when the maximum number of payments has been reached.
  error Grateful_PaymentsAmountReached();

  /// @notice Thrown when the one-time payment is not found.
  error Grateful_OneTimeNotFound();

  /// @notice Thrown when only the sender or receiver can cancel the subscription.
  error Grateful_OnlySenderOrReceiverCanCancelSubscription();

  /// @notice Thrown when only the sender can extend subscription.
  error Grateful_OnlySenderCanExtendSubscription();

  /*///////////////////////////////////////////////////////////////
                               VARIABLES
    //////////////////////////////////////////////////////////////*/

  /// @notice Aave pool for yielding merchants' funds.
  function aavePool() external view returns (IPool);

  /// @notice Checks if a token is whitelisted.
  /// @param _token Address of the token.
  /// @return True if the token is whitelisted, false otherwise.
  function tokensWhitelisted(
    address _token
  ) external view returns (bool);

  /// @notice Returns the yielding preference of a merchant.
  /// @param _merchant Address of the merchant.
  /// @return True if the merchant prefers yielding funds, false otherwise.
  function yieldingFunds(
    address _merchant
  ) external view returns (bool);

  /// @notice Returns the vault associated with a token.
  /// @param _token Address of the token.
  /// @return Address of the vault contract.
  function vaults(
    address _token
  ) external view returns (AaveV3ERC4626);

  /// @notice Returns the amount of shares for a merchant.
  /// @param _merchant Address of the merchant.
  /// @param _token Address of the token.
  /// @return Amount of shares.
  function shares(address _merchant, address _token) external view returns (uint256);

  /// @notice Checks if an address is a registered one-time payment.
  /// @param _address Address to check.
  /// @return True if it's a registered one-time payment, false otherwise.
  function oneTimePayments(
    address _address
  ) external view returns (bool);

  /// @notice Returns the total number of subscriptions.
  /// @return Number of subscriptions.
  function subscriptionCount() external view returns (uint256);

  /// @notice Returns the fee applied to the payments.
  /// @return Fee in basis points (10000 = 100%).
  function fee() external view returns (uint256);

  /*///////////////////////////////////////////////////////////////
                                LOGIC
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Adds a token to the whitelist.
   * @param _token Address of the token to be added.
   */
  function addToken(
    address _token
  ) external;

  /**
   * @notice Adds a vault for a specific token.
   * @param _token Address of the token.
   * @param _vault Address of the vault contract.
   */
  function addVault(address _token, address _vault) external;

  /**
   * @notice Makes a payment to a merchant.
   * @param _merchant Address of the merchant receiving payment.
   * @param _token Address of the token used for payment.
   * @param _amount Amount of the token to be paid.
   * @param _id ID of the payment.
   */
  function pay(address _merchant, address _token, uint256 _amount, uint256 _id) external;

  /**
   * @notice Makes a payment to a merchant.
   * @param _merchant Address of the merchant receiving payment.
   * @param _token Address of the token used for payment.
   * @param _amount Amount of the token to be paid.
   * @param _id ID of the payment.
   * @param _recipients List of recipients for payment splitting.
   * @param _percentages Corresponding percentages for each recipient (in basis points, 10000 = 100%).
   */
  function pay(
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _id,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external;

  /**
   * @notice Subscribes to a service with recurring payments.
   * @param _token Address of the token.
   * @param _receiver Address of the payment receiver.
   * @param _amount Amount per payment.
   * @param _interval Interval in seconds between payments.
   * @param _paymentsAmount Total number of payments.
   * @param _recipients List of recipients for payment splitting.
   * @param _percentages Corresponding percentages for each recipient.
   * @return subscriptionId ID of the created subscription.
   */
  function subscribe(
    address _token,
    address _receiver,
    uint256 _amount,
    uint256 _subscriptionPlanId,
    uint40 _interval,
    uint16 _paymentsAmount,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external returns (uint256 subscriptionId);

  /**
   * @notice Subscribes to a service with recurring payments.
   * @param _token Address of the token.
   * @param _receiver Address of the payment receiver.
   * @param _amount Amount per payment.
   * @param _interval Interval in seconds between payments.
   * @param _paymentsAmount Total number of payments.
   * @return subscriptionId ID of the created subscription.
   */
  function subscribe(
    address _token,
    address _receiver,
    uint256 _amount,
    uint256 _subscriptionPlanId,
    uint40 _interval,
    uint16 _paymentsAmount
  ) external returns (uint256 subscriptionId);

  function cancelSubscription(
    uint256 subscriptionId
  ) external;

  function extendSubscription(uint256 subscriptionId, uint16 additionalPayments) external;

  /**
   * @notice Processes a subscription payment.
   * @param subscriptionId ID of the subscription.
   */
  function processSubscription(
    uint256 subscriptionId
  ) external;

  /**
   * @notice Creates a one-time payment.
   * @param _merchant Address of the merchant.
   * @param _token Address of the token.
   * @param _amount Amount of the token.
   * @param _salt Salt used for address computation.
   * @param _paymentId ID of the payment.
   * @param precomputed Precomputed address of the OneTime contract.
   * @return oneTime Address of the created OneTime contract.
   */
  function createOneTimePayment(
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    address precomputed,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external returns (OneTime oneTime);

  /**
   * @notice Creates a one-time payment without recipients and percentages.
   * @param _merchant Address of the merchant.
   * @param _token Address of the token.
   * @param _amount Amount of the token.
   * @param _salt Salt used for address computation.
   * @param _paymentId ID of the payment.
   * @param precomputed Precomputed address of the OneTime contract.
   * @return oneTime Address of the created OneTime contract.
   */
  function createOneTimePayment(
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    address precomputed
  ) external returns (OneTime oneTime);

  /**
   * @notice Receives a one-time payment.
   * @param _merchant Address of the merchant.
   * @param _token Address of the token.
   * @param _paymentId ID of the payment.
   * @param _amount Amount of the token.
   * @param _recipients List of recipients for payment splitting.
   * @param _percentages Corresponding percentages for each recipient.
   */
  function receiveOneTimePayment(
    address _merchant,
    address _token,
    uint256 _paymentId,
    uint256 _amount,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external;

  /**
   * @notice Receives a one-time payment without recipients and percentages.
   * @param _merchant Address of the merchant.
   * @param _token Address of the token.
   * @param _paymentId ID of the payment.
   * @param _amount Amount of the token.
   */
  function receiveOneTimePayment(address _merchant, address _token, uint256 _paymentId, uint256 _amount) external;

  /**
   * @notice Computes the address of a one-time payment contract.
   * @param _merchant Address of the merchant.
   * @param _token Address of the token.
   * @param _amount Amount of the token.
   * @param _salt Salt used for address computation.
   * @param _paymentId ID of the payment.
   * @param _recipients List of recipients for payment splitting.
   * @param _percentages Corresponding percentages for each recipient.
   * @return oneTime Address of the computed OneTime contract.
   */
  function computeOneTimeAddress(
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external view returns (OneTime oneTime);

  /**
   * @notice Computes the address of a one-time payment contract without recipients and percentages.
   * @param _merchant Address of the merchant.
   * @param _token Address of the token.
   * @param _amount Amount of the token.
   * @param _salt Salt used for address computation.
   * @param _paymentId ID of the payment.
   * @return oneTime Address of the computed OneTime contract.
   */
  function computeOneTimeAddress(
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId
  ) external view returns (OneTime oneTime);

  /**
   * @notice Withdraws funds from the vault.
   * @param _token Address of the token being withdrawn.
   */
  function withdraw(
    address _token
  ) external;

  /**
   * @notice Toggles the merchant's preference to yield funds.
   */
  function switchYieldingFunds() external;

  /**
   * @notice Calculates the ID of a payment.
   * @param _sender Address of the sender.
   * @param _merchant Address of the merchant.
   * @param _token Address of the token.
   * @param _amount Amount of the token.
   * @return id ID of the payment.
   */
  function calculateId(
    address _sender,
    address _merchant,
    address _token,
    uint256 _amount
  ) external view returns (uint256 id);

  /**
   * @notice Applies the fee to an amount.
   * @param amount Amount before fee.
   * @return amountWithFee Amount after fee is applied.
   */
  function applyFee(
    uint256 amount
  ) external view returns (uint256 amountWithFee);

  /**
   * @notice Sets a new fee.
   * @param _newFee New fee to be applied (in basis points, 10000 = 100%).
   */
  function setFee(
    uint256 _newFee
  ) external;
}
