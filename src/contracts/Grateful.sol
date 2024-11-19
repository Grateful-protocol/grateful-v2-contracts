// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {OneTime} from "contracts/OneTime.sol";
import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";

import {IGrateful} from "interfaces/IGrateful.sol";

import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {IPool} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

/**
 * @title Grateful Contract
 * @notice Allows payments in whitelisted tokens with optional yield via AAVE
 */
contract Grateful is IGrateful, Ownable2Step, ReentrancyGuard {
  using Bytes32AddressLib for bytes32;
  using FixedPointMathLib for uint256;
  using SafeERC20 for IERC20;

  /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IGrateful
  uint256 public constant MAX_FEE = 10_000; // Max 100% fee (10000 basis points)

  /// @inheritdoc IGrateful
  uint256 public constant MAX_PERFORMANCE_FEE = 5000; // Max 50% performance fee (5000 basis points)

  /*//////////////////////////////////////////////////////////////
                               STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IGrateful
  IPool public aavePool;

  /// @inheritdoc IGrateful
  mapping(address => bool) public tokensWhitelisted;

  /// @inheritdoc IGrateful
  mapping(address => AaveV3Vault) public vaults;

  /// @inheritdoc IGrateful
  mapping(address => mapping(address => uint256)) public shares;

  /// @inheritdoc IGrateful
  mapping(address => mapping(address => uint256)) public userDeposits;

  /// @inheritdoc IGrateful
  mapping(address => bool) public oneTimePayments;

  /// @inheritdoc IGrateful
  uint256 public fee;

  /// @inheritdoc IGrateful
  mapping(address => CustomFee) public override customFees;

  /// @inheritdoc IGrateful
  mapping(uint256 => bool) public paymentIds;

  /// @inheritdoc IGrateful
  uint256 public performanceFeeRate = 500; // 5% fee

  /*//////////////////////////////////////////////////////////////
                                 MODIFIERS
    //////////////////////////////////////////////////////////////*/

  modifier onlyWhenTokenWhitelisted(
    address _token
  ) {
    _ensureTokenWhitelisted(_token);
    _;
  }

  modifier onlyWhenTokensWhitelisted(
    address[] memory _tokens
  ) {
    for (uint256 i = 0; i < _tokens.length; i++) {
      _ensureTokenWhitelisted(_tokens[i]);
    }
    _;
  }

  /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Initializes the Grateful contract.
   * @param _tokens Array of token addresses to whitelist.
   * @param _aavePool Address of the Aave V3 pool.
   * @param _initialFee Initial fee in basis points (10000 = 100%).
   */
  constructor(address[] memory _tokens, IPool _aavePool, uint256 _initialFee) Ownable(msg.sender) {
    aavePool = _aavePool;
    fee = _initialFee;
    for (uint256 i = 0; i < _tokens.length; i++) {
      tokensWhitelisted[_tokens[i]] = true;
      IERC20 token = IERC20(_tokens[i]);
      token.forceApprove(address(_aavePool), type(uint256).max);
    }
  }

  /*//////////////////////////////////////////////////////////////
                              PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IGrateful
  function calculateAssets(address _merchant, address _token) public view returns (uint256 assets) {
    AaveV3Vault vault = vaults[_token];
    uint256 sharesAmount = shares[_merchant][_token];
    assets = vault.convertToAssets(sharesAmount);
  }

  /// @inheritdoc IGrateful
  function calculateId(
    address _sender,
    address _merchant,
    address _token,
    uint256 _amount
  ) public view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(_sender, _merchant, _token, _amount, block.timestamp)));
  }

  /// @inheritdoc IGrateful
  function applyFee(address _merchant, uint256 _amount) public view returns (uint256) {
    uint256 feePercentage = fee;
    if (customFees[_merchant].isSet) {
      feePercentage = customFees[_merchant].fee;
    }
    uint256 feeAmount = (_amount * feePercentage) / 10_000;
    return _amount - feeAmount;
  }

  /// @inheritdoc IGrateful
  function owner() public view override(IGrateful, Ownable) returns (address) {
    return super.owner();
  }

  /// @inheritdoc IGrateful
  function calculateProfit(address _user, address _token) public view returns (uint256 profit) {
    AaveV3Vault vault = vaults[_token];
    uint256 sharesAmount = shares[_user][_token];
    uint256 assets = vault.previewRedeem(sharesAmount); // Current value of user's shares
    uint256 initialDeposit = userDeposits[_user][_token]; // User's initial deposit
    if (assets > initialDeposit) {
      profit = assets - initialDeposit;
    } else {
      profit = 0;
    }
  }

  /// @inheritdoc IGrateful
  function calculatePerformanceFee(
    uint256 _profit
  ) public view returns (uint256 feeAmount) {
    feeAmount = (_profit * performanceFeeRate) / 10_000;
  }

  /*//////////////////////////////////////////////////////////////
                             EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IGrateful
  function addToken(
    address _token
  ) external onlyOwner {
    tokensWhitelisted[_token] = true;
    IERC20 token = IERC20(_token);
    token.forceApprove(address(aavePool), type(uint256).max);
    emit TokenAdded(_token);
  }

  /// @inheritdoc IGrateful
  function removeToken(
    address _token
  ) external onlyOwner {
    if (!tokensWhitelisted[_token]) {
      revert Grateful_TokenOrVaultNotFound();
    }
    delete tokensWhitelisted[_token];
    IERC20 token = IERC20(_token);
    token.forceApprove(address(aavePool), 0);
    token.forceApprove(address(vaults[_token]), 0);
    emit TokenRemoved(_token);
  }

  /// @inheritdoc IGrateful
  function addVault(address _token, address _vault) external onlyOwner onlyWhenTokenWhitelisted(_token) {
    vaults[_token] = AaveV3Vault(_vault);
    IERC20 token = IERC20(_token);
    token.safeIncreaseAllowance(address(_vault), type(uint256).max);
    emit VaultAdded(_token, _vault);
  }

  /// @inheritdoc IGrateful
  function removeVault(
    address _token
  ) external onlyOwner onlyWhenTokenWhitelisted(_token) {
    AaveV3Vault vault = vaults[_token];
    if (address(vault) == address(0)) {
      revert Grateful_TokenOrVaultNotFound();
    }
    IERC20 token = IERC20(_token);
    token.forceApprove(address(vault), 0);
    emit VaultRemoved(_token, address(vault));
    delete vaults[_token];
  }

  /// @inheritdoc IGrateful
  function pay(
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _id,
    bool _yieldFunds
  ) external onlyWhenTokenWhitelisted(_token) {
    _processPayment(msg.sender, _merchant, _token, _amount, _id, _yieldFunds);
  }

  /// @inheritdoc IGrateful
  function createOneTimePayment(
    address _merchant,
    address[] memory _tokens,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    bool _yieldFunds,
    address _precomputed
  ) external onlyWhenTokensWhitelisted(_tokens) returns (OneTime oneTime) {
    oneTimePayments[_precomputed] = true;
    oneTime =
      new OneTime{salt: bytes32(_salt)}(IGrateful(address(this)), _tokens, _merchant, _amount, _paymentId, _yieldFunds);
    emit OneTimePaymentCreated(_merchant, _tokens, _amount);
  }

  /// @inheritdoc IGrateful
  function receiveOneTimePayment(
    address _merchant,
    address _token,
    uint256 _paymentId,
    uint256 _amount,
    bool _yieldFunds
  ) external {
    if (!oneTimePayments[msg.sender]) {
      revert Grateful_OneTimeNotFound();
    }
    _processPayment(msg.sender, _merchant, _token, _amount, _paymentId, _yieldFunds);
  }

  /// @inheritdoc IGrateful
  function computeOneTimeAddress(
    address _merchant,
    address[] memory _tokens,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    bool _yieldFunds
  ) external view returns (OneTime oneTime) {
    bytes memory bytecode = abi.encodePacked(
      type(OneTime).creationCode, abi.encode(address(this), _tokens, _merchant, _amount, _paymentId, _yieldFunds)
    );
    bytes32 bytecodeHash = keccak256(bytecode);
    bytes32 addressHash = keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(_salt), bytecodeHash));
    address computedAddress = address(uint160(uint256(addressHash)));
    return OneTime(computedAddress);
  }

  /// @inheritdoc IGrateful
  function withdraw(
    address _token
  ) external onlyWhenTokenWhitelisted(_token) {
    _withdraw(_token, 0, true);
  }

  /// @inheritdoc IGrateful
  function withdraw(address _token, uint256 _assets) external onlyWhenTokenWhitelisted(_token) {
    _withdraw(_token, _assets, false);
  }

  /// @inheritdoc IGrateful
  function withdrawMultiple(
    address[] memory _tokens
  ) external onlyWhenTokensWhitelisted(_tokens) {
    uint256 tokensLength = _tokens.length;
    for (uint256 i = 0; i < tokensLength; i++) {
      _withdraw(_tokens[i], 0, true);
    }
  }

  /// @inheritdoc IGrateful
  function withdrawMultiple(
    address[] memory _tokens,
    uint256[] memory _assets
  ) external onlyWhenTokensWhitelisted(_tokens) {
    uint256 tokensLength = _tokens.length;
    if (tokensLength != _assets.length) {
      revert Grateful_MismatchedArrays();
    }
    for (uint256 i = 0; i < tokensLength; i++) {
      _withdraw(_tokens[i], _assets[i], false);
    }
  }

  /// @inheritdoc IGrateful
  function setFee(
    uint256 _newFee
  ) external onlyOwner {
    if (_newFee > MAX_FEE) {
      revert Grateful_FeeRateTooHigh();
    }
    fee = _newFee;
    emit FeeUpdated(_newFee);
  }

  /// @inheritdoc IGrateful
  function setPerformanceFeeRate(
    uint256 _newPerformanceFeeRate
  ) external onlyOwner {
    if (_newPerformanceFeeRate > MAX_PERFORMANCE_FEE) {
      revert Grateful_FeeRateTooHigh();
    }
    performanceFeeRate = _newPerformanceFeeRate;
    emit PerformanceFeeRateUpdated(_newPerformanceFeeRate);
  }

  /// @inheritdoc IGrateful
  function setCustomFee(uint256 _newFee, address _merchant) external onlyOwner {
    if (_newFee > MAX_FEE) {
      revert Grateful_FeeRateTooHigh();
    }
    customFees[_merchant] = CustomFee({isSet: true, fee: _newFee});
    emit CustomFeeUpdated(_merchant, _newFee);
  }

  /// @inheritdoc IGrateful
  function unsetCustomFee(
    address _merchant
  ) external onlyOwner {
    delete customFees[_merchant];
    emit CustomFeeUnset(_merchant);
  }

  /*//////////////////////////////////////////////////////////////
                             PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /**
   * @dev Reverts if the provided token is not whitelisted.
   * @param _token The address of the token to check.
   */
  function _ensureTokenWhitelisted(
    address _token
  ) private view {
    if (!tokensWhitelisted[_token]) {
      revert Grateful_TokenNotWhitelisted();
    }
  }

  /**
   * @notice Processes a payment.
   * @param _sender Address of the sender.
   * @param _merchant Address of the merchant.
   * @param _token Address of the token.
   * @param _amount Amount of the token.
   * @param _paymentId ID of the payment.
   * @param _yieldFunds Whether to yield funds or not.
   */
  function _processPayment(
    address _sender,
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _paymentId,
    bool _yieldFunds
  ) private nonReentrant {
    // Validate amount
    if (_amount == 0) {
      revert Grateful_InvalidAmount();
    }

    // Check payment id
    if (paymentIds[_paymentId]) {
      revert Grateful_PaymentIdAlreadyUsed();
    }
    paymentIds[_paymentId] = true;

    // Apply the fee
    uint256 amountWithFee = applyFee(_merchant, _amount);
    uint256 feeAmount = _amount - amountWithFee;

    IERC20 token = IERC20(_token);

    // Transfer the full amount from the sender to this contract
    token.safeTransferFrom(_sender, address(this), _amount);

    // Transfer fee to owner
    token.safeTransfer(owner(), feeAmount);

    if (_yieldFunds) {
      AaveV3Vault vault = vaults[_token];
      if (address(vault) == address(0)) {
        token.safeTransfer(_merchant, amountWithFee);
      } else {
        uint256 sharesAmount = vault.deposit(amountWithFee, address(this));
        // Update state after receiving sharesAmount
        shares[_merchant][_token] += sharesAmount;
        userDeposits[_merchant][_token] += amountWithFee;
      }
    } else {
      // Transfer tokens to merchant
      token.safeTransfer(_merchant, amountWithFee);
    }

    emit PaymentProcessed(_sender, _merchant, _token, _amount, _yieldFunds, _paymentId);
  }

  /**
   * @notice Handles a withdrawal.
   * @param _token The address of the token to withdraw.
   * @param _assets The amount of assets to withdraw (ignored if full withdrawal).
   * @param _isFullWithdrawal Indicates if it's a full withdrawal.
   */
  function _withdraw(address _token, uint256 _assets, bool _isFullWithdrawal) private nonReentrant {
    AaveV3Vault vault = vaults[_token];
    if (address(vault) == address(0)) {
      revert Grateful_VaultNotSet();
    }

    uint256 totalShares = shares[msg.sender][_token];
    uint256 sharesToWithdraw;
    uint256 assetsToWithdraw;

    if (_isFullWithdrawal) {
      sharesToWithdraw = totalShares;
      assetsToWithdraw = vault.previewRedeem(sharesToWithdraw);
    } else {
      // Validate assets amount
      if (_assets == 0) {
        revert Grateful_InvalidAmount();
      }
      sharesToWithdraw = vault.previewWithdraw(_assets);
      if (sharesToWithdraw > totalShares) {
        revert Grateful_WithdrawExceedsShares();
      }
      assetsToWithdraw = _assets;
    }

    uint256 totalAssets = vault.previewRedeem(totalShares);
    uint256 initialDeposit = userDeposits[msg.sender][_token];

    // Calculate proportion of withdrawal
    uint256 proportion = assetsToWithdraw.divWadDown(totalAssets);
    uint256 initialDepositToWithdraw = initialDeposit.mulWadDown(proportion);

    // Calculate profit and performance fee
    uint256 profit = 0;
    uint256 performanceFeeAmount = 0;
    if (assetsToWithdraw > initialDepositToWithdraw) {
      profit = assetsToWithdraw - initialDepositToWithdraw;
      performanceFeeAmount = calculatePerformanceFee(profit);
      assetsToWithdraw -= performanceFeeAmount; // Deduct fee from assets
    }

    // Update user's shares and deposits before external calls
    shares[msg.sender][_token] = totalShares - sharesToWithdraw;
    userDeposits[msg.sender][_token] = initialDeposit - initialDepositToWithdraw;

    // Ensure balances are zero in case of full withdrawal to handle rounding errors
    if (_isFullWithdrawal) {
      shares[msg.sender][_token] = 0;
      userDeposits[msg.sender][_token] = 0;
    }

    // Withdraw performance fee to fee recipient (owner)
    if (performanceFeeAmount > 0) {
      vault.withdraw(performanceFeeAmount, owner(), address(this));
    }

    // Withdraw assets to user
    vault.withdraw(assetsToWithdraw, msg.sender, address(this));

    // Emit an event for the withdrawal
    emit Withdrawal(msg.sender, _token, assetsToWithdraw, performanceFeeAmount);
  }
}
