// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Base test contract
import {UnitBase} from "./helpers/Base.t.sol";

// Grateful contract and related interfaces
import {Grateful, IGrateful} from "contracts/Grateful.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract UnitPayment is UnitBase {
  function test_paySuccessWithoutYield(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);
    vm.assume(amount <= type(uint256).max / grateful.fee());

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.approve(address(grateful), amount);

    vm.prank(user);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.PaymentProcessed(user, merchant, address(token), amount, false, paymentId);
    grateful.pay(merchant, address(token), amount, paymentId, false);

    uint256 feeAmount = (amount * grateful.fee()) / 1e18;
    uint256 expectedMerchantAmount = amount - feeAmount;

    assertEq(token.balanceOf(owner), feeAmount);
    assertEq(token.balanceOf(merchant), expectedMerchantAmount);
  }

  function test_paySuccessWithYield(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);
    vm.assume(amount <= type(uint256).max / grateful.fee());

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.approve(address(grateful), amount);

    vm.prank(user);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.PaymentProcessed(user, merchant, address(token), amount, true, paymentId);
    grateful.pay(merchant, address(token), amount, paymentId, true);

    uint256 feeAmount = (amount * grateful.fee()) / 1e18;
    uint256 amountAfterFee = amount - feeAmount;

    assertEq(token.balanceOf(owner), feeAmount);
    assertEq(token.balanceOf(merchant), 0);

    uint256 merchantShares = grateful.shares(merchant, address(token));
    uint256 merchantDeposit = grateful.userDeposits(merchant, address(token));

    assertGt(merchantShares, 0);
    assertEq(merchantDeposit, amountAfterFee);
  }

  function test_revertIfPayWithNonWhitelistedToken(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);
    ERC20Mock nonWhitelistedToken = new ERC20Mock();

    vm.prank(user);
    nonWhitelistedToken.mint(user, amount);
    vm.prank(user);
    nonWhitelistedToken.approve(address(grateful), amount);

    vm.prank(user);
    vm.expectRevert(IGrateful.Grateful_TokenNotWhitelisted.selector);
    grateful.pay(merchant, address(nonWhitelistedToken), amount, paymentId, false);
  }

  function test_revertIfPayWithZeroAmount(
    uint256 paymentId
  ) public {
    uint256 amount = 0;

    vm.prank(user);
    token.approve(address(grateful), amount);

    vm.prank(user);
    vm.expectRevert(IGrateful.Grateful_InvalidAmount.selector);
    grateful.pay(merchant, address(token), amount, paymentId, false);
  }

  function test_revertIfPayWithInvalidMerchant(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);

    vm.prank(user);
    token.approve(address(grateful), amount);

    vm.prank(user);
    vm.expectRevert(IGrateful.Grateful_InvalidAddress.selector);
    grateful.pay(address(0), address(token), amount, paymentId, false);
  }

  function test_revertIfPayWithInsufficientAllowance(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);

    vm.prank(user);
    token.mint(user, amount);

    vm.prank(user);
    vm.expectRevert();
    grateful.pay(merchant, address(token), amount, paymentId, false);
  }

  function test_revertIfPayWithInsufficientBalance(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);

    vm.prank(user);
    token.approve(address(grateful), amount);

    vm.prank(user);
    vm.expectRevert();
    grateful.pay(merchant, address(token), amount, paymentId, false);
  }

  function test_revertIfPayWithInvalidTokenAddress(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);

    vm.prank(user);
    vm.expectRevert(IGrateful.Grateful_TokenNotWhitelisted.selector);
    grateful.pay(merchant, address(0), amount, paymentId, false);
  }

  function test_payWithoutVaultYieldFundsTrue(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);
    vm.assume(amount <= type(uint256).max / grateful.fee());

    vm.prank(owner);
    grateful.removeVault(address(token));

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.approve(address(grateful), amount);

    vm.prank(user);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.PaymentProcessed(user, merchant, address(token), amount, true, paymentId);
    grateful.pay(merchant, address(token), amount, paymentId, true);

    uint256 feeAmount = (amount * grateful.fee()) / 1e18;
    uint256 amountAfterFee = amount - feeAmount;

    assertEq(token.balanceOf(owner), feeAmount);
    assertEq(token.balanceOf(merchant), amountAfterFee);

    uint256 merchantShares = grateful.shares(merchant, address(token));
    uint256 merchantDeposit = grateful.userDeposits(merchant, address(token));

    assertEq(merchantShares, 0);
    assertEq(merchantDeposit, 0);
  }

  function test_revertIfPayWithZeroAddressToken(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);

    vm.prank(user);
    vm.expectRevert(IGrateful.Grateful_TokenNotWhitelisted.selector);
    grateful.pay(merchant, address(0), amount, paymentId, false);
  }

  function test_revertIfPayToZeroAddressMerchant(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.approve(address(grateful), amount);

    vm.prank(user);
    vm.expectRevert(IGrateful.Grateful_InvalidAddress.selector);
    grateful.pay(address(0), address(token), amount, paymentId, false);
  }

  function test_payWithCustomFee(uint256 amount, uint256 paymentId, uint256 customFee) public {
    vm.assume(amount > 0);
    vm.assume(customFee <= grateful.MAX_FEE());

    if (customFee > 0) {
      vm.assume(amount <= type(uint256).max / customFee);
    }

    vm.prank(owner);
    grateful.setCustomFee(customFee, merchant);

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.approve(address(grateful), amount);

    vm.prank(user);
    grateful.pay(merchant, address(token), amount, paymentId, false);

    uint256 feeAmount = (amount * customFee) / 1e18;
    uint256 expectedMerchantAmount = amount - feeAmount;

    assertEq(token.balanceOf(owner), feeAmount);
    assertEq(token.balanceOf(merchant), expectedMerchantAmount);
  }

  function test_payWithVaultNotSetAndYieldFundsTrue(uint256 amount, uint256 paymentId) public {
    vm.assume(amount > 0);
    vm.assume(amount <= type(uint256).max / grateful.fee());

    vm.prank(owner);
    grateful.removeVault(address(token));

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.approve(address(grateful), amount);

    vm.prank(user);
    grateful.pay(merchant, address(token), amount, paymentId, true);

    uint256 feeAmount = (amount * grateful.fee()) / 1e18;
    uint256 amountAfterFee = amount - feeAmount;

    assertEq(token.balanceOf(owner), feeAmount);
    assertEq(token.balanceOf(merchant), amountAfterFee);

    uint256 merchantShares = grateful.shares(merchant, address(token));
    uint256 merchantDeposit = grateful.userDeposits(merchant, address(token));

    assertEq(merchantShares, 0);
    assertEq(merchantDeposit, 0);
  }
}
