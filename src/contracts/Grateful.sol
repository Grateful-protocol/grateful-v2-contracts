// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {OneTime} from "contracts/OneTime.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IGrateful} from "interfaces/IGrateful.sol";

import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";
import {AaveV3ERC4626, IPool} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract Grateful is IGrateful, Ownable2Step {
  using Bytes32AddressLib for bytes32;

  // @inheritdoc IGrateful
  IPool public aavePool;

  // @inheritdoc IGrateful
  mapping(address => bool) public tokensWhitelisted;

  // @inheritdoc IGrateful
  mapping(address => bool) public yieldingFunds;

  // @inheritdoc IGrateful
  mapping(address => AaveV3ERC4626) public vaults;

  // @inheritdoc IGrateful
  mapping(address => mapping(address => uint256)) public shares;

  mapping(uint256 => Subscription) public subscriptions;

  mapping(address => bool) public oneTimePayments;

  // @inheritdoc IGrateful
  uint256 public subscriptionCount;

  // @inheritdoc IGrateful
  uint256 public fee;

  modifier onlyWhenTokenWhitelisted(address _token) {
    if (!tokensWhitelisted[_token]) {
      revert Grateful_TokenNotWhitelisted();
    }
    _;
  }

  constructor(address[] memory _tokens, IPool _aavePool) Ownable(msg.sender) {
    aavePool = _aavePool;
    for (uint256 i = 0; i < _tokens.length; i++) {
      tokensWhitelisted[_tokens[i]] = true;
      IERC20(_tokens[i]).approve(address(_aavePool), type(uint256).max);
    }
  }

  // @inheritdoc IGrateful
  function calculateId(
    address _sender,
    address _merchant,
    address _token,
    uint256 _amount
  ) public view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(_sender, _merchant, _token, _amount, block.timestamp)));
  }

  /// @inheritdoc IGrateful
  function addToken(address _token) external onlyOwner {
    tokensWhitelisted[_token] = true;
    IERC20(_token).approve(address(aavePool), type(uint256).max);
  }

  // @inheritdoc IGrateful
  function addVault(address _token, address _vault) external onlyWhenTokenWhitelisted(_token) onlyOwner {
    vaults[_token] = AaveV3ERC4626(_vault);
    IERC20(_token).approve(address(_vault), type(uint256).max);
  }

  // @inheritdoc IGrateful
  function pay(address _merchant, address _token, uint256 _amount, uint256 _id) public onlyWhenTokenWhitelisted(_token) {
    _processPayment(msg.sender, _merchant, _token, _amount, _id, 0); // 0 because no subscription is involved
  }

  // @inheritdoc IGrateful
  function subscribe(
    address _token,
    address _receiver,
    uint256 _amount,
    uint40 _interval,
    uint16 _paymentsAmount
  ) external onlyWhenTokenWhitelisted(_token) returns (uint256 subscriptionId) {
    subscriptionId = subscriptionCount++;
    subscriptions[subscriptionId] = Subscription({
      token: _token,
      sender: msg.sender,
      amount: _amount,
      receiver: _receiver,
      interval: _interval,
      paymentsAmount: _paymentsAmount - 1, // Subtract 1 because the first payment is already processed
      lastPaymentTime: uint40(block.timestamp)
    });

    _processPayment(
      msg.sender, _receiver, _token, _amount, calculateId(msg.sender, _receiver, _token, _amount), subscriptionId
    );
  }

  // @inheritdoc IGrateful
  function processSubscription(uint256 subscriptionId) external {
    Subscription storage subscription = subscriptions[subscriptionId];

    if (subscription.amount == 0) {
      revert Grateful_SubscriptionDoesNotExist();
    }
    if (
      block.timestamp < subscription.lastPaymentTime + subscription.interval // min timestamp for next payment
    ) {
      revert Grateful_TooEarlyForNextPayment();
    }
    if (subscription.paymentsAmount == 0) {
      revert Grateful_PaymentsAmountReached();
    }

    _processPayment(
      subscription.sender,
      subscription.receiver,
      subscription.token,
      subscription.amount,
      calculateId(subscription.sender, subscription.receiver, subscription.token, subscription.amount),
      subscriptionId
    );
    subscription.lastPaymentTime = uint40(block.timestamp);
    subscription.paymentsAmount--;
  }

  // @inheritdoc IGrateful
  function createOneTimePayment(
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId,
    address precomputed
  ) external onlyWhenTokenWhitelisted(_token) returns (OneTime oneTime) {
    oneTimePayments[precomputed] = true;
    oneTime =
      new OneTime{salt: bytes32(_salt)}(IGrateful(address(this)), IERC20(_token), _merchant, _amount, _paymentId);
    emit OneTimePaymentCreated(_merchant, _token, _amount);
  }

  function receiveOneTimePayment(address _merchant, address _token, uint256 _paymentId, uint256 _amount) external {
    if (!oneTimePayments[msg.sender]) {
      revert Grateful_OneTimeNotFound();
    }
    _processPayment(msg.sender, _merchant, _token, _amount, _paymentId, 0);
  }

  function computeOneTimeAddress(
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _salt,
    uint256 _paymentId
  ) external view returns (OneTime oneTime) {
    return OneTime(
      keccak256(
        abi.encodePacked(
          bytes1(0xFF),
          address(this),
          bytes32(_salt),
          keccak256(
            abi.encodePacked(
              type(OneTime).creationCode, abi.encode(address(this), _token, _merchant, _amount, _paymentId)
            )
          )
        )
      ).fromLast20Bytes()
    );
  }

  // @inheritdoc IGrateful
  function withdraw(address _token) external onlyWhenTokenWhitelisted(_token) {
    AaveV3ERC4626 vault = vaults[_token];
    if (address(vault) == address(0)) {
      revert Grateful_VaultNotSet();
    }
    uint256 _shares = shares[msg.sender][_token];
    shares[msg.sender][_token] = 0;
    vault.redeem(_shares, msg.sender, address(this));
  }

  // @inheritdoc IGrateful
  function cancelSubscription(uint256 subscriptionId) external {
    Subscription storage subscription = subscriptions[subscriptionId];

    if (subscription.amount == 0) {
      revert Grateful_SubscriptionDoesNotExist();
    }
    if (subscription.sender != msg.sender) {
      revert Grateful_OnlySenderCanCancelSubscription();
    }

    delete subscriptions[subscriptionId];
  }

  // @inheritdoc IGrateful
  function switchYieldingFunds() external {
    yieldingFunds[msg.sender] = !yieldingFunds[msg.sender];
  }

  function applyFee(uint256 amount) public view returns (uint256) {
    uint256 fee = (amount * 100) / 10_000;
    return amount - fee;
  }

  /**
   * @notice Processes a payment
   * @param _sender Address of the sender
   * @param _merchant Address of the merchant
   * @param _token Address of the token
   * @param _amount Amount of the token
   * @param _paymentId Id of the payment
   * @param _subscriptionId Id of the subscription, 0 if it is one-time
   */
  function _processPayment(
    address _sender,
    address _merchant,
    address _token,
    uint256 _amount,
    uint256 _paymentId,
    uint256 _subscriptionId
  ) internal {
    uint256 amountWithFee = applyFee(_amount);
    if (yieldingFunds[_merchant]) {
      AaveV3ERC4626 vault = vaults[_token];
      if (address(vault) == address(0)) {
        revert Grateful_VaultNotSet();
      }
      IERC20(_token).transferFrom(_sender, address(this), amountWithFee);
      uint256 _shares = vault.deposit(amountWithFee, address(this));
      shares[_merchant][_token] += _shares;
    } else {
      if (!IERC20(_token).transferFrom(_sender, _merchant, amountWithFee)) {
        revert Grateful_TransferFailed();
      }
    }

    IERC20(_token).transferFrom(_sender, owner(), _amount - amountWithFee);

    emit PaymentProcessed(_sender, _merchant, _token, _amount, yieldingFunds[_merchant], _paymentId, _subscriptionId);
  }
}
