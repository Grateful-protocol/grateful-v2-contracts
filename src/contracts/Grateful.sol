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
  uint256 public constant MAX_FEE = 1 ether; // Max 100% fee (1 ether)

  /// @inheritdoc IGrateful
  uint256 public constant MAX_PERFORMANCE_FEE = 0.5 ether; // Max 50% performance fee (0.5 ether)

  /*//////////////////////////////////////////////////////////////
                               STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IGrateful
  IPool public immutable aavePool;

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
  uint256 public performanceFee;

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
    uint256 tokensLength = _tokens.length;
    for (uint256 i = 0; i < tokensLength;) {
      _ensureTokenWhitelisted(_tokens[i]);
      unchecked {
        i++;
      }
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
   * @param _initialFee Initial fee in fixed-point (1 ether = 100%).
   * @param _owner Address of the contract owner.
   */
  constructor(
    address[] memory _tokens,
    IPool _aavePool,
    uint256 _initialFee,
    uint256 _initialPerformanceFee,
    address _owner
  ) Ownable(_owner) {
    if (address(_aavePool) == address(0)) {
      revert Grateful_InvalidAddress();
    }
    aavePool = _aavePool;
    uint256 tokensLength = _tokens.length;
    for (uint256 i = 0; i < tokensLength;) {
      tokensWhitelisted[_tokens[i]] = true;
      IERC20 token = IERC20(_tokens[i]);
      token.forceApprove(address(_aavePool), type(uint256).max);
      unchecked {
        i++;
      }
    }

    _setFee(_initialFee);
    _setPerformanceFee(_initialPerformanceFee);
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
    uint256 feeAmount = (_amount * feePercentage) / 1e18;
    return _amount - feeAmount;
  }

  /// @inheritdoc IGrateful
  function owner() public view override(IGrateful, Ownable) returns (address) {
    return super.owner();
  }

  /// @inheritdoc IGrateful
  function calculateProfit(address _user, address _token) public view returns (uint256 profit) {
    if (shares[_user][_token] == 0) {
      return 0;
    }
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
    feeAmount = (_profit * performanceFee) / 1e18;
  }

  /*//////////////////////////////////////////////////////////////
                             EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IGrateful
  function addToken(
    address _token
  ) external onlyOwner {
    if (_token == address(0)) {
      revert Grateful_InvalidAddress();
    }
    tokensWhitelisted[_token] = true;
    IERC20 token = IERC20(_token);
    token.forceApprove(address(aavePool), type(uint256).max);
    emit TokenAdded(_token);
  }

  /// @inheritdoc IGrateful
  function removeToken(
    address _token
  ) external onlyOwner onlyWhenTokenWhitelisted(_token) {
    delete tokensWhitelisted[_token];
    IERC20 token = IERC20(_token);
    token.forceApprove(address(aavePool), 0);
    token.forceApprove(address(vaults[_token]), 0);
    emit TokenRemoved(_token);
  }

  /// @inheritdoc IGrateful
  function addVault(address _token, address _vault) external onlyOwner onlyWhenTokenWhitelisted(_token) {
    if (_vault == address(0)) {
      revert Grateful_InvalidAddress();
    }
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
    if (_merchant == address(0)) {
      revert Grateful_InvalidAddress();
    }
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
    if (_merchant == address(0)) {
      revert Grateful_InvalidAddress();
    }

    address precomputed = address(computeOneTimeAddress(_merchant, _tokens, _amount, _salt, _paymentId, _yieldFunds));

    if (precomputed != _precomputed) {
      revert Grateful_PrecomputedAddressMismatch();
    }

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
    if (_merchant == address(0)) {
      revert Grateful_InvalidAddress();
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
  ) public view returns (OneTime oneTime) {
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
    for (uint256 i = 0; i < tokensLength;) {
      _withdraw(_tokens[i], 0, true);
      unchecked {
        i++;
      }
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
    for (uint256 i = 0; i < tokensLength;) {
      _withdraw(_tokens[i], _assets[i], false);
      unchecked {
        i++;
      }
    }
  }

  /// @inheritdoc IGrateful
  function setFee(
    uint256 _newFee
  ) external onlyOwner {
    _setFee(_newFee);
  }

  /// @inheritdoc IGrateful
  function setPerformanceFee(
    uint256 _newPerformanceFee
  ) external onlyOwner {
    _setPerformanceFee(_newPerformanceFee);
  }

  /// @inheritdoc IGrateful
  function setCustomFee(uint256 _newFee, address _merchant) external onlyOwner {
    if (_merchant == address(0)) {
      revert Grateful_InvalidAddress();
    }
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
    if (_merchant == address(0)) {
      revert Grateful_InvalidAddress();
    }
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
   * @notice Sets the general fee. Must be called internally.
   * @param _newFee The new fee to set in fixed-point (1 ether = 100%).
   */
  function _setFee(
    uint256 _newFee
  ) private {
    if (_newFee > MAX_FEE) {
      revert Grateful_FeeRateTooHigh();
    }
    fee = _newFee;
    emit FeeUpdated(_newFee);
  }

  /**
   * @notice Sets the performance fee. Must be called internally.
   * @param _newPerformanceFee The new performance fee in fixed-point (1 ether = 100%).
   */
  function _setPerformanceFee(
    uint256 _newPerformanceFee
  ) private {
    if (_newPerformanceFee > MAX_PERFORMANCE_FEE) {
      revert Grateful_FeeRateTooHigh();
    }
    performanceFee = _newPerformanceFee;
    emit PerformanceFeeUpdated(_newPerformanceFee);
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
    if (_merchant == address(0)) {
      revert Grateful_InvalidAddress();
    }

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
    if (_token == address(0)) {
      revert Grateful_InvalidAddress();
    }
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
        revert Grateful_WithdrawExceedsShares(totalShares, sharesToWithdraw);
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
    }

    // Update user's shares and deposits before external calls
    shares[msg.sender][_token] = totalShares - sharesToWithdraw;
    userDeposits[msg.sender][_token] = initialDeposit - initialDepositToWithdraw;

    // Ensure balances are zero in case of full withdrawal to handle rounding errors
    if (_isFullWithdrawal) {
      shares[msg.sender][_token] = 0;
      userDeposits[msg.sender][_token] = 0;
    }

    // Redeem shares to Grateful contract
    vault.redeem(sharesToWithdraw, address(this), address(this));

    IERC20 token = IERC20(_token);

    if (profit > 0) {
      // Transfer performance fee to owner
      token.safeTransfer(owner(), performanceFeeAmount);

      // Transfer remaining assets to merchant
      uint256 merchantAmount = assetsToWithdraw - performanceFeeAmount;
      token.safeTransfer(msg.sender, merchantAmount);
    } else {
      // No profit, transfer all assets to merchant
      token.safeTransfer(msg.sender, assetsToWithdraw);
    }

    // Emit an event for the withdrawal
    emit Withdrawal(msg.sender, _token, assetsToWithdraw, performanceFeeAmount);
  }
}
