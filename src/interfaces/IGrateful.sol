// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {OneTime} from "contracts/OneTime.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AaveV3ERC4626, IPool} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

/**
 * @title Grateful Contract Interface
 * @notice Interface for the Grateful contract that allows payments in whitelisted tokens with optional yield via AAVE.
 */
interface IGrateful {
  /*///////////////////////////////////////////////////////////////
                                  STRUCTS
    //////////////////////////////////////////////////////////////*/

  struct CustomFee {
    bool isSet;
    uint256 fee;
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
   */
  event PaymentProcessed(
    address indexed sender,
    address indexed merchant,
    address indexed token,
    uint256 amount,
    bool yielded,
    uint256 paymentId
  );

  /**
   * @notice Emitted when a one-time payment is created.
   * @param merchant Address of the merchant.
   * @param tokens Array of token addresses.
   * @param amount Amount of the token.
   */
  event OneTimePaymentCreated(address indexed merchant, address[] tokens, uint256 amount);

  /**
   * @notice Emitted when funds are withdrawn.
   * @param user Address of the user withdrawing funds.
   * @param token Address of the token.
   * @param amount Amount withdrawn.
   */
  event Withdraw(address indexed user, address indexed token, uint256 amount);

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
  error Grateful_usdcVaultNotSet();

  /// @notice Thrown when a token transfer fails.
  error Grateful_TransferFailed();

  /// @notice Thrown when the one-time payment is not found.
  error Grateful_OneTimeNotFound();

  /// @notice Thrown when the payment id has been used.
  error Grateful_PaymentIdAlreadyUsed();

  /// @notice Thrown when the user tries to withdraw more shares than they have.
  error Grateful_WithdrawExceedsShares();

  /*///////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

  /// @notice Returns the owner of the contract.
  function owner() external view returns (address);

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

  /// @notice Returns the fee applied to the payments.
  /// @return Fee in basis points (10000 = 100%).
  function fee() external view returns (uint256);

  /// @notice Returns the custom fee applied to the payments for a merchant.
  /// @param _merchant Address of the merchant.
  /// @return isSet True if a custom fee is set for the merchant.
  /// @return fee Custom fee in basis points.
  function customFees(
    address _merchant
  ) external view returns (bool isSet, uint256 fee);

  /// @notice Returns if a paymentId has been used.
  /// @param paymentId The payment id.
  /// @return isUsed True if the payment id has been used.
  function paymentIds(
    uint256 paymentId
  ) external view returns (bool isUsed);

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
   * @param _usdcVault Address of the vault contract.
   */
  function addVault(address _token, address _usdcVault) external;

  /**
   * @notice Makes a payment to a merchant.
   * @param _merchant Address of the merchant receiving payment.
   * @param _token Address of the token used for payment.
   * @param _amount Amount of the token to be paid.
   * @param _id ID of the payment.
   */
  function pay(address _merchant, address _token, uint256 _amount, uint256 _id) external;

  /**
   * @notice Makes a payment to a merchant with payment splitting.
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
   * @notice Creates a one-time payment with payment splitting.
   * @param _merchant Address of the merchant.
   * @param _tokens Array of token addresses.
   * @param _amount Amount of the token.
   * @param _salt Salt used for address computation.
   * @param _paymentId ID of the payment.
   * @param precomputed Precomputed address of the OneTime contract.
   * @param _recipients List of recipients for payment splitting.
   * @param _percentages Corresponding percentages for each recipient.
   * @return oneTime Address of the created OneTime contract.
   */
  function createOneTimePayment(
    address _merchant,
    address[] memory _tokens,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    address precomputed,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external returns (OneTime oneTime);

  /**
   * @notice Creates a one-time payment without payment splitting.
   * @param _merchant Address of the merchant.
   * @param _tokens Array of token addresses.
   * @param _amount Amount of the token.
   * @param _salt Salt used for address computation.
   * @param _paymentId ID of the payment.
   * @param precomputed Precomputed address of the OneTime contract.
   * @return oneTime Address of the created OneTime contract.
   */
  function createOneTimePayment(
    address _merchant,
    address[] memory _tokens,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    address precomputed
  ) external returns (OneTime oneTime);

  /**
   * @notice Receives a one-time payment with payment splitting.
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
   * @notice Receives a one-time payment without payment splitting.
   * @param _merchant Address of the merchant.
   * @param _tokens Array of token addresses.
   * @param _paymentId ID of the payment.
   * @param _amount Amount of the token.
   */
  function receiveOneTimePayment(
    address _merchant,
    IERC20[] memory _tokens,
    uint256 _paymentId,
    uint256 _amount
  ) external;

  /**
   * @notice Computes the address of a one-time payment contract with payment splitting.
   * @param _merchant Address of the merchant.
   * @param _tokens Array of token addresses.
   * @param _amount Amount of the token.
   * @param _salt Salt used for address computation.
   * @param _paymentId ID of the payment.
   * @param _recipients List of recipients for payment splitting.
   * @param _percentages Corresponding percentages for each recipient.
   * @return oneTime Address of the computed OneTime contract.
   */
  function computeOneTimeAddress(
    address _merchant,
    address[] memory _tokens,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external view returns (OneTime oneTime);

  /**
   * @notice Computes the address of a one-time payment contract without payment splitting.
   * @param _merchant Address of the merchant.
   * @param _tokens Array of token addresses.
   * @param _amount Amount of the token.
   * @param _salt Salt used for address computation.
   * @param _paymentId ID of the payment.
   * @return oneTime Address of the computed OneTime contract.
   */
  function computeOneTimeAddress(
    address _merchant,
    address[] memory _tokens,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId
  ) external view returns (OneTime oneTime);

  /**
   * @notice Withdraws all shares for a specific token.
   * @param _token Address of the token being withdrawn.
   */
  function withdraw(
    address _token
  ) external;

  /**
   * @notice Withdraws a specific amount of assets for a token.
   * @param _token Address of the token being withdrawn.
   * @param _assets Amount of the asset to withdraw.
   */
  function withdraw(address _token, uint256 _assets) external;

  /**
   * @notice Withdraws all shares for multiple tokens.
   * @param _tokens Array of token addresses to withdraw.
   */
  function withdrawMultiple(
    address[] memory _tokens
  ) external;

  /**
   * @notice Withdraws specified asset amounts for multiple tokens.
   * @param _tokens Array of token addresses to withdraw.
   * @param _assets Array of asset amounts to withdraw corresponding to each token.
   */
  function withdrawMultiple(address[] memory _tokens, uint256[] memory _assets) external;

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
   * @param _merchant Address of the merchant.
   * @param _amount Amount before fee.
   * @return amountWithFee Amount after fee is applied.
   */
  function applyFee(address _merchant, uint256 _amount) external view returns (uint256 amountWithFee);

  /**
   * @notice Sets a new fee.
   * @param _newFee New fee to be applied (in basis points, 10000 = 100%).
   */
  function setFee(
    uint256 _newFee
  ) external;

  /**
   * @notice Sets a new custom fee for a certain merchant.
   * @param _newFee New fee to be applied (in basis points, 10000 = 100%).
   * @param _merchant Address of the merchant.
   */
  function setCustomFee(uint256 _newFee, address _merchant) external;

  /**
   * @notice Unsets the custom fee for a certain merchant, reverting to the default fee.
   * @param _merchant Address of the merchant.
   */
  function unsetCustomFee(
    address _merchant
  ) external;
}
