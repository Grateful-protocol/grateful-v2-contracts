// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {OneTime} from "contracts/OneTime.sol";

import {IGrateful} from "interfaces/IGrateful.sol";

import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";
import {AaveV3ERC4626, IPool} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

/**
 * @title Grateful Contract
 * @notice Allows payments in whitelisted tokens with optional yield via AAVE, including payment splitting functionality.
 */
contract Grateful is IGrateful, Ownable2Step {
  using Bytes32AddressLib for bytes32;
  using SafeERC20 for IERC20;
  using ECDSA for bytes32;

  /*//////////////////////////////////////////////////////////////
                                 STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IGrateful
  IPool public aavePool;

  /// @inheritdoc IGrateful
  string public constant SWITCH_YIELD_MESSAGE = unicode"🐧 At Grateful, we love penguins 🐧";

  /// @inheritdoc IGrateful
  mapping(address => bool) public tokensWhitelisted;

  /// @inheritdoc IGrateful
  mapping(address => bool) public yieldingFunds;

  /// @inheritdoc IGrateful
  mapping(address => AaveV3ERC4626) public vaults;

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
    if (!tokensWhitelisted[_token]) {
      revert Grateful_TokenNotWhitelisted();
    }
    _;
  }

  modifier onlyWhenTokensWhitelisted(
    address[] memory _tokens
  ) {
    for (uint256 i = 0; i < _tokens.length; i++) {
      if (!tokensWhitelisted[_tokens[i]]) {
        revert Grateful_TokenNotWhitelisted();
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
  function calculateId(
    address _sender,
    address _merchant,
    address _token,
    uint256 _AMOUNT_USDC
  ) public view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(_sender, _merchant, _token, _AMOUNT_USDC, block.timestamp)));
  }

  /// @inheritdoc IGrateful
  function applyFee(address _merchant, uint256 _AMOUNT_USDC) public view returns (uint256) {
    uint256 feePercentage = fee;
    if (customFees[_merchant].isSet) {
      feePercentage = customFees[_merchant].fee;
    }
    uint256 feeAmount = (_AMOUNT_USDC * feePercentage) / 10_000;
    return _AMOUNT_USDC - feeAmount;
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
  }

  /// @inheritdoc IGrateful
  function addVault(address _token, address _usdcVault) external onlyOwner onlyWhenTokenWhitelisted(_token) {
    vaults[_token] = AaveV3ERC4626(_usdcVault);
    IERC20(_token).safeIncreaseAllowance(address(_usdcVault), type(uint256).max);
  }

  /// @inheritdoc IGrateful
  function pay(
    address _merchant,
    address _token,
    uint256 _AMOUNT_USDC,
    uint256 _id
  ) external onlyWhenTokenWhitelisted(_token) {
    _processPayment(msg.sender, _merchant, _token, _AMOUNT_USDC, _id, new address[](0), new uint256[](0));
  }

  /// @inheritdoc IGrateful
  function pay(
    address _merchant,
    address _token,
    uint256 _AMOUNT_USDC,
    uint256 _id,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external onlyWhenTokenWhitelisted(_token) {
    _processPayment(msg.sender, _merchant, _token, _AMOUNT_USDC, _id, _recipients, _percentages);
  }

  /// @inheritdoc IGrateful
  function createOneTimePayment(
    address _merchant,
    address[] memory _tokens,
    uint256 _AMOUNT_USDC,
    uint256 _salt,
    uint256 _paymentId,
    address precomputed,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external onlyWhenTokensWhitelisted(_tokens) returns (OneTime oneTime) {
    oneTimePayments[precomputed] = true;
    oneTime = new OneTime{salt: bytes32(_salt)}(
      IGrateful(address(this)), _tokens, _merchant, _AMOUNT_USDC, _paymentId, _recipients, _percentages
    );
    emit OneTimePaymentCreated(_merchant, _tokens, _AMOUNT_USDC);
  }

  /// @inheritdoc IGrateful
  function receiveOneTimePayment(
    address _merchant,
    address _token,
    uint256 _paymentId,
    uint256 _AMOUNT_USDC,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external {
    if (!oneTimePayments[msg.sender]) {
      revert Grateful_OneTimeNotFound();
    }
    _processPayment(msg.sender, _merchant, _token, _AMOUNT_USDC, _paymentId, _recipients, _percentages);
  }

  /// @inheritdoc IGrateful
  function computeOneTimeAddress(
    address _merchant,
    address[] memory _tokens,
    uint256 _AMOUNT_USDC,
    uint256 _salt,
    uint256 _paymentId,
    address[] calldata _recipients,
    uint256[] calldata _percentages
  ) external view returns (OneTime oneTime) {
    bytes memory bytecode = abi.encodePacked(
      type(OneTime).creationCode,
      abi.encode(address(this), _tokens, _merchant, _AMOUNT_USDC, _paymentId, _recipients, _percentages)
    );
    bytes32 bytecodeHash = keccak256(bytecode);
    bytes32 addressHash = keccak256(abi.encodePacked(bytes1(0xff), address(this), bytes32(_salt), bytecodeHash));
    address computedAddress = address(uint160(uint256(addressHash)));
    return OneTime(computedAddress);
  }

  /// @inheritdoc IGrateful
  function createOneTimePayment(
    address _merchant,
    address[] memory _tokens,
    uint256 _AMOUNT_USDC,
    uint256 _salt,
    uint256 _paymentId,
    address precomputed
  ) external onlyWhenTokensWhitelisted(_tokens) returns (OneTime oneTime) {
    oneTimePayments[precomputed] = true;
    oneTime = new OneTime{salt: bytes32(_salt)}(
      IGrateful(address(this)), _tokens, _merchant, _AMOUNT_USDC, _paymentId, new address[](0), new uint256[](0)
    );
    emit OneTimePaymentCreated(_merchant, _tokens, _AMOUNT_USDC);
  }

  /// @inheritdoc IGrateful
  function receiveOneTimePayment(
    address _merchant,
    IERC20[] memory _tokens,
    uint256 _paymentId,
    uint256 _AMOUNT_USDC
  ) external {
    if (!oneTimePayments[msg.sender]) {
      revert Grateful_OneTimeNotFound();
    }
    for (uint256 i = 0; i < _tokens.length; i++) {
      if (_tokens[i].balanceOf(msg.sender) >= _AMOUNT_USDC) {
        _processPayment(
          msg.sender, _merchant, address(_tokens[i]), _AMOUNT_USDC, _paymentId, new address[](0), new uint256[](0)
        );
      }
    }
  }

  /// @inheritdoc IGrateful
  function computeOneTimeAddress(
    address _merchant,
    address[] memory _tokens,
    uint256 _AMOUNT_USDC,
    uint256 _salt,
    uint256 _paymentId
  ) external view returns (OneTime oneTime) {
    bytes memory bytecode = abi.encodePacked(
      type(OneTime).creationCode,
      abi.encode(address(this), _tokens, _merchant, _AMOUNT_USDC, _paymentId, new address[](0), new uint256[](0))
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
    AaveV3ERC4626 vault = vaults[_token];
    if (address(vault) == address(0)) {
      revert Grateful_usdcVaultNotSet();
    }
    uint256 _shares = shares[msg.sender][_token];
    shares[msg.sender][_token] = 0;
    vault.redeem(_shares, msg.sender, address(this));
  }

  /// @inheritdoc IGrateful
  function withdraw(address _token, uint256 _assets) external onlyWhenTokenWhitelisted(_token) {
    AaveV3ERC4626 vault = vaults[_token];
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
      AaveV3ERC4626 vault = vaults[_token];
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
      AaveV3ERC4626 vault = vaults[_token];
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
  function switchYieldingFunds() external {
    yieldingFunds[msg.sender] = !yieldingFunds[msg.sender];
  }

  /// @inheritdoc IGrateful
  function switchYieldingFundsWithSig(bytes calldata _signature, address _merchant) external {
    // TODO: Nonce pls
    bytes32 signedMessageHash = keccak256(abi.encode(SWITCH_YIELD_MESSAGE));

    if (signedMessageHash.recover(_signature) != _merchant) {
      revert Grateful_InvalidSignature();
    }
    yieldingFunds[_merchant] = !yieldingFunds[_merchant];
  }

  /// @inheritdoc IGrateful
  function setFee(
    uint256 _newFee
  ) external onlyOwner {
    fee = _newFee;
  }

  /// @inheritdoc IGrateful
  function setCustomFee(uint256 _newFee, address _merchant) external onlyOwner {
    customFees[_merchant] = CustomFee({isSet: true, fee: _newFee});
  }

  /// @inheritdoc IGrateful
  function unsetCustomFee(
    address _merchant
  ) external onlyOwner {
    delete customFees[_merchant];
  }

  /*//////////////////////////////////////////////////////////////
                             INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /**
   * @notice Processes a payment.
   * @param _sender Address of the sender.
   * @param _merchant Address of the merchant.
   * @param _token Address of the token.
   * @param _AMOUNT_USDC Amount of the token.
   * @param _paymentId ID of the payment.
   * @param _recipients List of recipients for payment splitting.
   * @param _percentages Corresponding percentages for each recipient.
   */
  function _processPayment(
    address _sender,
    address _merchant,
    address _token,
    uint256 _AMOUNT_USDC,
    uint256 _paymentId,
    address[] memory _recipients,
    uint256[] memory _percentages
  ) internal {
    // Transfer the full amount from the sender to this contract
    IERC20(_token).safeTransferFrom(_sender, address(this), _AMOUNT_USDC);

    // Check payment id
    if (paymentIds[_paymentId]) {
      revert Grateful_PaymentIdAlreadyUsed();
    }

    // Apply the fee
    uint256 amountWithFee = applyFee(_merchant, _AMOUNT_USDC);

    // Transfer fee to owner
    IERC20(_token).safeTransfer(owner(), _AMOUNT_USDC - amountWithFee);

    // If payment splitting is requested
    if (_recipients.length > 0) {
      if (_recipients.length != _percentages.length) {
        revert Grateful_MismatchedArrays();
      }
      uint256 totalPercentage = 0;
      for (uint256 i = 0; i < _percentages.length; i++) {
        totalPercentage += _percentages[i];
      }
      if (totalPercentage != 10_000) {
        revert Grateful_InvalidTotalPercentage();
      }

      // Distribute amountWithFee among recipients
      for (uint256 i = 0; i < _recipients.length; i++) {
        address recipient = _recipients[i];
        uint256 recipientShare = (amountWithFee * _percentages[i]) / 10_000;

        if (yieldingFunds[recipient]) {
          AaveV3ERC4626 vault = vaults[_token];
          if (address(vault) == address(0)) {
            IERC20(_token).safeTransfer(recipient, recipientShare);
          } else {
            uint256 _shares = vault.deposit(recipientShare, address(this));
            shares[recipient][_token] += _shares;
          }
        } else {
          // Transfer tokens to recipient
          IERC20(_token).safeTransfer(recipient, recipientShare);
        }
      }
    } else {
      // Proceed as before, paying the merchant
      if (yieldingFunds[_merchant]) {
        AaveV3ERC4626 vault = vaults[_token];
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
    }

    paymentIds[_paymentId] = true;

    emit PaymentProcessed(_sender, _merchant, _token, _AMOUNT_USDC, yieldingFunds[_merchant], _paymentId);
  }
}
