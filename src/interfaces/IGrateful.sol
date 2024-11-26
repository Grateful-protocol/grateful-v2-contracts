// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {OneTime} from "contracts/OneTime.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";
import {IPool} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

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
   * @notice Emitted when the default fee is updated.
   * @param newFee The new fee in basis points.
   */
  event FeeUpdated(uint256 newFee);

  /**
   * @notice Emitted when the performance fee rate is updated.
   * @param newRate The new performance fee rate in basis points.
   */
  event PerformanceFeeUpdated(uint256 newRate);

  /**
   * @notice Emitted when a custom fee is set for a merchant.
   * @param merchant Address of the merchant.
   * @param newFee The new custom fee in basis points.
   */
  event CustomFeeUpdated(address indexed merchant, uint256 newFee);

  /**
   * @notice Emitted when a custom fee is unset for a merchant.
   * @param merchant Address of the merchant.
   */
  event CustomFeeUnset(address indexed merchant);

  /**
   * @notice Emitted when a new token is added to the whitelist.
   * @param token Address of the token added.
   */
  event TokenAdded(address indexed token);

  /**
   * @notice Emitted when a new vault is added for a token.
   * @param token Address of the token.
   * @param vault Address of the vault added.
   */
  event VaultAdded(address indexed token, address indexed vault);

  /**
   * @notice Emitted when a token is removed from the whitelist.
   * @param token Address of the token removed.
   */
  event TokenRemoved(address indexed token);

  /**
   * @notice Emitted when a vault is removed for a token.
   * @param token Address of the token.
   * @param vault Address of the vault removed.
   */
  event VaultRemoved(address indexed token, address indexed vault);

  /**
   * @notice Emitted when a withdrawal is made.
   * @param user Address of the user making the withdrawal.
   * @param token Address of the token being withdrawn.
   * @param amount Amount of the token being withdrawn.
   * @param performanceFee Amount of the performance fee deducted.
   */
  event Withdrawal(address indexed user, address indexed token, uint256 amount, uint256 performanceFee);

  /*///////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////*/
  /// @notice Thrown when the token is not whitelisted.
  error Grateful_TokenNotWhitelisted();

  /// @notice Thrown when array lengths mismatch.
  error Grateful_MismatchedArrays();

  /// @notice Thrown when the vault for a token is not set.
  error Grateful_VaultNotSet();

  /// @notice Thrown when the one-time payment is not found.
  error Grateful_OneTimeNotFound();

  /// @notice Thrown when the payment id has been used.
  error Grateful_PaymentIdAlreadyUsed();

  /// @notice Thrown when the user tries to withdraw more shares than they have.
  error Grateful_WithdrawExceedsShares(uint256 totalShares, uint256 sharesToWithdraw);

  /// @notice Thrown when attempting to remove a token or vault that does not exist.
  error Grateful_TokenOrVaultNotFound();

  /// @notice Thrown when the fee rate is too high.
  error Grateful_FeeRateTooHigh();

  /// @notice Thrown when the provided amount is invalid.
  error Grateful_InvalidAmount();

  /// @notice Thrown when the provided address is invalid.
  error Grateful_InvalidAddress();

  /// @notice Thrown when the precomputed address does not match the one-time address created.
  error Grateful_PrecomputedAddressMismatch();

  /*///////////////////////////////////////////////////////////////
                                   VARIABLES
    //////////////////////////////////////////////////////////////*/
  /// @notice Returns the maximum fee in basis points (10000 = 100%).
  function MAX_FEE() external pure returns (uint256);

  /// @notice Returns the maximum performance fee in basis points (5000 = 50%).
  function MAX_PERFORMANCE_FEE() external pure returns (uint256);

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

  /// @notice Returns the vault associated with a token.
  /// @param _token Address of the token.
  /// @return Address of the vault contract.
  function vaults(
    address _token
  ) external view returns (AaveV3Vault);

  /// @notice Returns the amount of shares for a merchant.
  /// @param _merchant Address of the merchant.
  /// @param _token Address of the token.
  /// @return Amount of shares.
  function shares(address _merchant, address _token) external view returns (uint256);

  /// @notice Returns the user deposit amount for a merchant and token.
  /// @param _merchant Address of the merchant.
  /// @param _token Address of the token.
  /// @return Amount of initial deposit.
  function userDeposits(address _merchant, address _token) external view returns (uint256);

  /// @notice Checks if an address is a registered one-time payment.
  /// @param _address Address to check.
  /// @return True if it's a registered one-time payment, false otherwise.
  function oneTimePayments(
    address _address
  ) external view returns (bool);

  /// @notice Returns the fee applied to the payments.
  /// @return Fee in basis points (10000 = 100%).
  function fee() external view returns (uint256);

  /// @notice Returns the performance fee rate.
  /// @return Performance fee rate in basis points.
  function performanceFee() external view returns (uint256);

  /// @notice Returns the custom fee applied to the payments for a merchant.
  /// @param _merchant Address of the merchant.
  /// @return isSet True if a custom fee is set for the merchant.
  /// @return fee Custom fee in basis points.
  function customFees(
    address _merchant
  ) external view returns (bool isSet, uint256 fee);

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
   * @notice Removes a token from the whitelist.
   * @param _token Address of the token to be removed.
   */
  function removeToken(
    address _token
  ) external;

  /**
   * @notice Removes a vault for a specific token.
   * @param _token Address of the token.
   */
  function removeVault(
    address _token
  ) external;

  /**
   * @notice Makes a payment to a merchant.
   * @param _merchant Address of the merchant receiving payment.
   * @param _token Address of the token used for payment.
   * @param _amount Amount of the token to be paid.
   * @param _id ID of the payment.
   * @param _yieldFunds Whether to yield funds or not.
   */
  function pay(address _merchant, address _token, uint256 _amount, uint256 _id, bool _yieldFunds) external;

  /**
   * @notice Creates a one-time payment.
   * @param _merchant Address of the merchant.
   * @param _tokens Array of token addresses.
   * @param _amount Amount of the token.
   * @param _salt Salt used for address computation.
   * @param _paymentId ID of the payment.
   * @param _yieldFunds Whether to yield funds or not.
   * @param precomputed Precomputed address of the OneTime contract.
   * @return oneTime Address of the created OneTime contract.
   */
  function createOneTimePayment(
    address _merchant,
    address[] memory _tokens,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    bool _yieldFunds,
    address precomputed
  ) external returns (OneTime oneTime);

  /**
   * @notice Receives a one-time payment.
   * @param _merchant Address of the merchant.
   * @param _token Token address.
   * @param _paymentId ID of the payment.
   * @param _amount Amount of the token.
   * @param _yieldFunds Whether to yield funds or not.
   */
  function receiveOneTimePayment(
    address _merchant,
    address _token,
    uint256 _paymentId,
    uint256 _amount,
    bool _yieldFunds
  ) external;

  /**
   * @notice Computes the address of a one-time payment contract.
   * @param _merchant Address of the merchant.
   * @param _tokens Array of token addresses.
   * @param _amount Amount of the token.
   * @param _salt Salt used for address computation.
   * @param _paymentId ID of the payment.
   * @param _yieldFunds Whether to yield funds or not.
   * @return oneTime Address of the computed OneTime contract.
   */
  function computeOneTimeAddress(
    address _merchant,
    address[] memory _tokens,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    bool _yieldFunds
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
   * @notice Calculates the assets of a merchant in a vault.
   * @param _merchant Address of the merchant.
   * @param _token Address of the token.
   * @return assets The total assets.
   */
  function calculateAssets(address _merchant, address _token) external view returns (uint256 assets);

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
   * @notice Calculates the profit (yield) earned by a user on a specific token.
   * @param _user The address of the user.
   * @param _token The address of the token.
   * @return profit The profit amount.
   */
  function calculateProfit(address _user, address _token) external view returns (uint256 profit);

  /**
   * @notice Calculates the performance fee on a given profit amount.
   * @param _profit The profit amount.
   * @return feeAmount The performance fee amount.
   */
  function calculatePerformanceFee(
    uint256 _profit
  ) external view returns (uint256 feeAmount);

  /**
   * @notice Sets a new fee.
   * @param _newFee New fee to be applied (in basis points, 10000 = 100%).
   */
  function setFee(
    uint256 _newFee
  ) external;

  /**
   * @notice Sets the performance fee rate.
   * @param _newPerformanceFee The new performance fee rate in basis points.
   */
  function setPerformanceFee(
    uint256 _newPerformanceFee
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
