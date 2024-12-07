// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Base test contract
import {UnitBase} from "./helpers/Base.t.sol";

// Contracts and interfaces

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Grateful, IGrateful} from "contracts/Grateful.sol";
import {OneTime} from "contracts/OneTime.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract UnitOneTimePayment is UnitBase {
  function test_createOneTimePaymentSuccessNonYield(uint128 amount, uint128 paymentId, uint128 salt) public {
    vm.assume(amount > 0);

    // Compute the precomputed address
    address precomputed = address(grateful.computeOneTimeAddress(merchant, tokens, amount, salt, paymentId, false));

    // User prepares funds
    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.transfer(precomputed, amount);

    // Simulate the Grateful Automation (just use owner or any address for testing)
    vm.prank(gratefulAutomation);
    // Expect event for creation
    vm.expectEmit(true, true, true, true);
    emit IGrateful.OneTimePaymentCreated(merchant, tokens, amount);
    OneTime oneTime = grateful.createOneTimePayment(merchant, tokens, amount, salt, paymentId, false, precomputed);

    uint256 feeAmount = (amount * grateful.fee()) / 1e18;
    uint256 expectedMerchantAmount = amount - feeAmount;

    assertEq(token.balanceOf(owner), feeAmount, "Owner fee mismatch");
    assertEq(token.balanceOf(merchant), expectedMerchantAmount, "Merchant amount mismatch");
    // Since yieldFunds = false and tokens are transferred directly
    assertEq(grateful.shares(merchant, address(token)), 0, "No shares should be credited");
    assertEq(grateful.userDeposits(merchant, address(token)), 0, "No deposits should be recorded");
  }

  function test_createOneTimePaymentSuccessYield(uint128 amount, uint128 paymentId, uint128 salt) public {
    vm.assume(amount > 0);

    address precomputed = address(grateful.computeOneTimeAddress(merchant, tokens, amount, salt, paymentId, true));

    // User prepares funds
    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.transfer(precomputed, amount);

    vm.prank(gratefulAutomation);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.OneTimePaymentCreated(merchant, tokens, amount);
    OneTime oneTime = grateful.createOneTimePayment(merchant, tokens, amount, salt, paymentId, true, precomputed);

    uint256 feeAmount = (amount * grateful.fee()) / 1e18;
    uint256 afterFee = amount - feeAmount;

    assertEq(token.balanceOf(owner), feeAmount, "Owner fee mismatch");
    assertEq(token.balanceOf(merchant), 0, "Merchant should receive no direct tokens");
    assertGt(grateful.shares(merchant, address(token)), 0, "Merchant should get shares");
    assertEq(grateful.userDeposits(merchant, address(token)), afterFee, "Merchant deposit mismatch");
  }

  function test_revertIfCreateOneTimePaymentInvalidMerchant(uint128 amount, uint128 paymentId, uint128 salt) public {
    vm.assume(amount > 0);

    address precomputed = address(grateful.computeOneTimeAddress(address(0), tokens, amount, salt, paymentId, false));

    vm.expectRevert(IGrateful.Grateful_InvalidAddress.selector);
    vm.prank(gratefulAutomation);
    grateful.createOneTimePayment(address(0), tokens, amount, salt, paymentId, false, precomputed);
  }

  function test_revertIfCreateOneTimePaymentNonWhitelistedToken(uint128 amount, uint128 paymentId, uint128 salt) public {
    vm.assume(amount > 0);
    ERC20Mock nonWhitelisted = new ERC20Mock();
    address[] memory nonWhitelistedTokens = new address[](1);
    nonWhitelistedTokens[0] = address(nonWhitelisted);

    address precomputed =
      address(grateful.computeOneTimeAddress(merchant, nonWhitelistedTokens, amount, salt, paymentId, false));

    // User sends funds to precomputed address
    vm.prank(user);
    nonWhitelisted.mint(user, amount);
    vm.prank(user);
    nonWhitelisted.transfer(precomputed, amount);

    vm.prank(gratefulAutomation);
    vm.expectRevert(IGrateful.Grateful_TokenNotWhitelisted.selector);
    grateful.createOneTimePayment(merchant, nonWhitelistedTokens, amount, salt, paymentId, false, precomputed);
  }

  function test_revertIfCreateOneTimePaymentNoFundsSent(uint128 amount, uint128 paymentId, uint128 salt) public {
    vm.assume(amount > 0);

    address precomputed = address(grateful.computeOneTimeAddress(merchant, tokens, amount, salt, paymentId, false));

    // No funds are sent to precomputed, so OneTime contract won't trigger receiveOneTimePayment
    vm.prank(gratefulAutomation);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.OneTimePaymentCreated(merchant, tokens, amount);
    OneTime oneTime = grateful.createOneTimePayment(merchant, tokens, amount, salt, paymentId, false, precomputed);

    // Without funds, no payment occurs
    assertEq(token.balanceOf(merchant), 0, "Merchant should have no funds");
    assertEq(token.balanceOf(owner), 0, "Owner should have no fees");
    // Also, no shares and no deposits since no payment
    assertEq(grateful.shares(merchant, address(token)), 0, "No shares should be credited");
    assertEq(grateful.userDeposits(merchant, address(token)), 0, "No deposit should be recorded");
  }

  function test_revertIfPrecomputedAddressMismatch(uint128 amount, uint128 paymentId, uint128 salt) public {
    vm.assume(amount > 0);

    // Correct precomputed
    address correctPrecomputed =
      address(grateful.computeOneTimeAddress(merchant, tokens, amount, salt, paymentId, false));
    // Provide a wrong precomputed
    address wrongPrecomputed = address(0x1234);

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.transfer(correctPrecomputed, amount);

    vm.prank(gratefulAutomation);
    vm.expectRevert(IGrateful.Grateful_PrecomputedAddressMismatch.selector);
    grateful.createOneTimePayment(merchant, tokens, amount, salt, paymentId, false, wrongPrecomputed);
  }

  function test_OverpaidOneTimePayment(uint128 amount, uint128 paymentId, uint128 salt) public {
    vm.assume(amount > 0);
    vm.assume(amount < 100 ether);

    address precomputed = address(grateful.computeOneTimeAddress(merchant, tokens, amount, salt, paymentId, false));

    // User sends double amount
    vm.startPrank(user);
    token.mint(user, amount * 2);
    token.transfer(precomputed, amount * 2);
    vm.stopPrank();

    vm.prank(gratefulAutomation);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.OneTimePaymentCreated(merchant, tokens, amount);
    OneTime oneTime = grateful.createOneTimePayment(merchant, tokens, amount, salt, paymentId, false, precomputed);

    // Merchant receives correct amount
    uint256 feeAmount = (amount * grateful.fee()) / 1e18;
    uint256 expectedMerchantAmount = amount - feeAmount;

    assertEq(token.balanceOf(merchant), expectedMerchantAmount, "Merchant didn't receive correct amount");
    assertEq(token.balanceOf(owner), feeAmount, "Owner didn't receive correct fee");

    // Excess remains in OneTime contract
    assertEq(token.balanceOf(address(oneTime)), amount, "Excess funds not in OneTime contract");

    // Rescue excess
    uint256 prevUserBalance = token.balanceOf(user);
    vm.prank(owner);
    oneTime.rescueFunds(IERC20(address(token)), user, amount);
    assertEq(token.balanceOf(user), prevUserBalance + amount, "User didn't get rescued funds back");
  }

  function test_revertIfRescueFundsNotOwner(uint128 amount, uint128 paymentId, uint128 salt) public {
    vm.assume(amount > 0);

    address precomputed = address(grateful.computeOneTimeAddress(merchant, tokens, amount, salt, paymentId, false));

    vm.prank(gratefulAutomation);
    OneTime oneTime = grateful.createOneTimePayment(merchant, tokens, amount, salt, paymentId, false, precomputed);

    vm.prank(user);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
    oneTime.rescueFunds(IERC20(address(token)), user, amount);
  }

  function test_revertIfReceiveOneTimePaymentNotOneTime(uint128 amount, uint128 paymentId) public {
    vm.assume(amount > 0);

    vm.prank(user);
    vm.expectRevert(IGrateful.Grateful_OneTimeNotFound.selector);
    grateful.receiveOneTimePayment(merchant, address(token), paymentId, amount, false);
  }

  function test_revertIfReceiveOneTimePaymentInvalidMerchant(uint128 amount, uint128 paymentId, uint128 salt) public {
    vm.assume(amount > 0);

    address precomputed = address(grateful.computeOneTimeAddress(merchant, tokens, amount, salt, paymentId, false));

    vm.prank(gratefulAutomation);
    OneTime oneTime = grateful.createOneTimePayment(merchant, tokens, amount, salt, paymentId, false, precomputed);

    vm.prank(address(oneTime));
    vm.expectRevert(IGrateful.Grateful_InvalidAddress.selector);
    grateful.receiveOneTimePayment(address(0), address(token), paymentId, amount, false);
  }
}
