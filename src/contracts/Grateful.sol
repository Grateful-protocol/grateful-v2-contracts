// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {OneTime} from "contracts/OneTime.sol";
import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";

import {IGrateful} from "interfaces/IGrateful.sol";

import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";
import {IPool} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

/**
 * @title Grateful Contract
 * @notice Allows payments in whitelisted tokens with optional yield via AAVE, including payment splitting functionality.
 */
contract Grateful is IGrateful, Ownable2Step {
  using Bytes32AddressLib for bytes32;
  using SafeERC20 for IERC20;

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
  mapping(address => bool) public oneTimePayments;

  /// @inheritdoc IGrateful
  uint256 public fee;

  /// @inheritdoc IGrateful
  mapping(address => CustomFee) public override customFees;

  /// @inheritdoc IGrateful
  mapping(uint256 => bool) public paymentIds;

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
      IERC20 _token = IERC20(_tokens[i]);
      _token.safeIncreaseAllowance(address(_aavePool), type(uint256).max);
    }
  }

  /*//////////////////////////////////////////////////////////////
                              PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IGrateful
  function calculateAssets(address _merchant, address _token) public view returns (uint256 assets) {
    AaveV3Vault _vault = vaults[_token];
    uint256 _shares = shares[_merchant][_token];
    assets = _vault.convertToAssets(_shares);
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

  /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IGrateful
  function addToken(
    address _token
  ) external onlyOwner {
    tokensWhitelisted[_token] = true;
    IERC20(_token).safeIncreaseAllowance(address(aavePool), type(uint256).max);
    emit TokenAdded(_token);
  }

  /// @inheritdoc IGrateful
  function addVault(address _token, address _vault) external onlyOwner onlyWhenTokenWhitelisted(_token) {
    vaults[_token] = AaveV3Vault(_vault);
    IERC20(_token).safeIncreaseAllowance(address(_vault), type(uint256).max);
    emit VaultAdded(_token, _vault);
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
    address precomputed
  ) external onlyWhenTokensWhitelisted(_tokens) returns (OneTime oneTime) {
    oneTimePayments[precomputed] = true;
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
    AaveV3Vault vault = vaults[_token];
    if (address(vault) == address(0)) {
      revert Grateful_usdcVaultNotSet();
    }
    uint256 _shares = shares[msg.sender][_token];
    shares[msg.sender][_token] = 0;
    vault.redeem(_shares, msg.sender, address(this));
  }

  /// @inheritdoc IGrateful
  function withdraw(address _token, uint256 _assets) external onlyWhenTokenWhitelisted(_token) {
    AaveV3Vault vault = vaults[_token];
    if (address(vault) == address(0)) {
      revert Grateful_usdcVaultNotSet();
    }
    uint256 _totalShares = shares[msg.sender][_token];
    uint256 _sharesToWithdraw = vault.convertToShares(_assets);
    if (_sharesToWithdraw > _totalShares) {
      revert Grateful_WithdrawExceedsShares();
    }
    shares[msg.sender][_token] = _totalShares - _sharesToWithdraw;
    vault.withdraw(_assets, msg.sender, address(this));
  }

  /// @inheritdoc IGrateful
  function withdrawMultiple(
    address[] memory _tokens
  ) external onlyWhenTokensWhitelisted(_tokens) {
    uint256 tokensLength = _tokens.length;
    for (uint256 i = 0; i < tokensLength; i++) {
      address _token = _tokens[i];
      AaveV3Vault vault = vaults[_token];
      if (address(vault) == address(0)) {
        revert Grateful_usdcVaultNotSet();
      }
      uint256 _shares = shares[msg.sender][_token];
      if (_shares > 0) {
        shares[msg.sender][_token] = 0;
        vault.redeem(_shares, msg.sender, address(this));
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
    for (uint256 i = 0; i < tokensLength; i++) {
      address _token = _tokens[i];
      uint256 _assetsToWithdraw = _assets[i];
      AaveV3Vault vault = vaults[_token];
      if (address(vault) == address(0)) {
        revert Grateful_usdcVaultNotSet();
      }
      uint256 _totalShares = shares[msg.sender][_token];
      uint256 _sharesToWithdraw = vault.convertToShares(_assetsToWithdraw);
      if (_sharesToWithdraw > _totalShares) {
        revert Grateful_WithdrawExceedsShares();
      }
      shares[msg.sender][_token] = _totalShares - _sharesToWithdraw;
      vault.withdraw(_assetsToWithdraw, msg.sender, address(this));
    }
  }

  /// @inheritdoc IGrateful
  function setFee(
    uint256 _newFee
  ) external onlyOwner {
    fee = _newFee;
    emit FeeUpdated(_newFee);
  }

  /// @inheritdoc IGrateful
  function setCustomFee(uint256 _newFee, address _merchant) external onlyOwner {
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
                             INTERNAL FUNCTIONS
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
   * @param _paymentId ID of the payment
   * @param _yieldFunds Whether to yield funds or not
   */
  function _processPayment(
    address _sender,
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _paymentId,
    bool _yieldFunds
  ) internal {
    // Transfer the full amount from the sender to this contract
    IERC20(_token).safeTransferFrom(_sender, address(this), _amount);

    // Check payment id
    if (paymentIds[_paymentId]) {
      revert Grateful_PaymentIdAlreadyUsed();
    }

    paymentIds[_paymentId] = true;

    // Apply the fee
    uint256 amountWithFee = applyFee(_merchant, _amount);

    // Transfer fee to owner
    IERC20(_token).safeTransfer(owner(), _amount - amountWithFee);

    if (_yieldFunds) {
      AaveV3Vault vault = vaults[_token];
      if (address(vault) == address(0)) {
        IERC20(_token).safeTransfer(_merchant, amountWithFee);
      } else {
        uint256 _shares = vault.deposit(amountWithFee, address(this));
        shares[_merchant][_token] += _shares;
      }
    } else {
      // Transfer tokens to merchant
      IERC20(_token).safeTransfer(_merchant, amountWithFee);
    }

    emit PaymentProcessed(_sender, _merchant, _token, _amount, _yieldFunds, _paymentId);
  }
}
