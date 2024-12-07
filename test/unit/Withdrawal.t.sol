// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Base test contract
import {UnitBase} from "./helpers/Base.t.sol";

// Grateful contract and related interfaces
import {Grateful, IGrateful} from "contracts/Grateful.sol";

import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract UnitWithdrawal is UnitBase {
  function test_withdrawFullSuccess(
    uint128 amount
  ) public {
    vm.assume(amount > 1e8);
    vm.assume(amount <= 10 ether);
    vm.assume(amount <= type(uint256).max / grateful.fee());
    uint256 paymentId = 1;

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.approve(address(grateful), amount);
    vm.prank(user);
    grateful.pay(merchant, address(token), amount, paymentId, true);

    uint256 initialDeposit = grateful.userDeposits(merchant, address(token));

    vm.prank(merchant);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.Withdrawal(merchant, address(token), initialDeposit, 0);
    grateful.withdraw(address(token));

    uint256 finalMerchantBalance = token.balanceOf(merchant);
    uint256 finalShares = grateful.shares(merchant, address(token));
    uint256 finalDeposit = grateful.userDeposits(merchant, address(token));

    assertEq(finalShares, 0);
    assertEq(finalDeposit, 0);
    assertEq(finalMerchantBalance, initialDeposit);
  }

  function test_withdrawPartialSuccess(uint128 amount, uint128 withdrawAmount) public {
    vm.assume(amount > 0);
    vm.assume(amount <= 10 ether);
    vm.assume(amount <= type(uint256).max / grateful.fee());
    vm.assume(withdrawAmount > 0);
    vm.assume(withdrawAmount <= grateful.applyFee(merchant, amount));
    vm.assume(withdrawAmount >= 100_000); // Ensure withdrawAmount is large enough for meaningful tolerance

    uint256 paymentId = 1;
    uint256 tolerance = withdrawAmount / 10_000; // 0.01% precision loss tolerance

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.approve(address(grateful), amount);
    vm.prank(user);
    grateful.pay(merchant, address(token), amount, paymentId, true);

    uint256 initialShares = grateful.shares(merchant, address(token));
    uint256 initialDeposit = grateful.userDeposits(merchant, address(token));

    vm.prank(merchant);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.Withdrawal(merchant, address(token), withdrawAmount, 0);
    grateful.withdraw(address(token), withdrawAmount);

    uint256 finalMerchantBalance = token.balanceOf(merchant);
    uint256 finalShares = grateful.shares(merchant, address(token));
    uint256 finalDeposit = grateful.userDeposits(merchant, address(token));

    // Use assertApproxEqAbs to allow for small precision errors
    assertApproxEqAbs(finalMerchantBalance, withdrawAmount, tolerance);
    assertLt(finalShares, initialShares);
    assertLt(finalDeposit, initialDeposit);
    assertApproxEqAbs(finalDeposit, initialDeposit - withdrawAmount, tolerance);
  }

  function test_withdrawMultipleFullSuccess(
    uint128 amount
  ) public {
    vm.assume(amount > 0);
    vm.assume(amount <= 10 ether);
    vm.assume(amount <= type(uint256).max / grateful.fee());

    (address token2, AaveV3Vault vault2) = _deployNewTokenAndVault();

    uint256 paymentId1 = 1;
    uint256 paymentId2 = 2;

    vm.startPrank(user);
    token.mint(user, amount);
    token.approve(address(grateful), amount);
    grateful.pay(merchant, address(token), amount, paymentId1, true);

    // mint new token
    ERC20Mock(token2).mint(user, amount);
    ERC20Mock(token2).approve(address(grateful), amount);
    grateful.pay(merchant, token2, amount, paymentId2, true);
    vm.stopPrank();

    address[] memory tokens = new address[](2);
    tokens[0] = address(token);
    tokens[1] = token2;

    uint256 expectedMerchantBalanceToken1 = grateful.userDeposits(merchant, address(token));
    uint256 expectedMerchantBalanceToken2 = grateful.userDeposits(merchant, token2);

    vm.prank(merchant);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.Withdrawal(merchant, address(token), expectedMerchantBalanceToken1, 0);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.Withdrawal(merchant, token2, expectedMerchantBalanceToken2, 0);
    grateful.withdrawMultiple(tokens);

    uint256 finalMerchantBalanceToken1 = token.balanceOf(merchant);
    uint256 finalMerchantBalanceToken2 = ERC20Mock(token2).balanceOf(merchant);

    assertEq(finalMerchantBalanceToken1, expectedMerchantBalanceToken1);
    assertEq(finalMerchantBalanceToken2, expectedMerchantBalanceToken2);
  }

  function test_withdrawMultiplePartialSuccess(uint128 amount, uint128 withdrawAmount) public {
    vm.assume(amount > 0);
    vm.assume(amount <= 10 ether);
    vm.assume(amount <= type(uint256).max / grateful.fee());
    vm.assume(withdrawAmount > 0);
    vm.assume(withdrawAmount <= grateful.applyFee(merchant, amount));
    vm.assume(withdrawAmount >= 100_000); // Ensure withdrawAmount is large enough for meaningful tolerance

    (address token2, AaveV3Vault vault2) = _deployNewTokenAndVault();

    uint256 paymentId1 = 1;
    uint256 paymentId2 = 2;

    vm.startPrank(user);
    token.mint(user, amount);
    token.approve(address(grateful), amount);
    grateful.pay(merchant, address(token), amount, paymentId1, true);

    ERC20Mock(token2).mint(user, amount);
    ERC20Mock(token2).approve(address(grateful), amount);
    grateful.pay(merchant, token2, amount, paymentId2, true);
    vm.stopPrank();

    address[] memory tokens = new address[](2);
    tokens[0] = address(token);
    tokens[1] = token2;

    uint256[] memory assets = new uint256[](2);
    assets[0] = withdrawAmount;
    assets[1] = withdrawAmount;

    vm.prank(merchant);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.Withdrawal(merchant, address(token), assets[0], 0);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.Withdrawal(merchant, token2, assets[1], 0);
    grateful.withdrawMultiple(tokens, assets);

    uint256 finalMerchantBalanceToken1 = token.balanceOf(merchant);
    uint256 finalMerchantBalanceToken2 = ERC20Mock(token2).balanceOf(merchant);

    uint256 tolerance = (withdrawAmount * 1) / 10_000; // 0.01% precision loss tolerance

    assertApproxEqAbs(finalMerchantBalanceToken1, assets[0], tolerance);
    assertApproxEqAbs(finalMerchantBalanceToken2, assets[1], tolerance);
  }

  function test_revertIfWithdrawTokenNotWhitelisted() public {
    address nonWhitelistedToken = address(new ERC20Mock());

    vm.prank(merchant);
    vm.expectRevert(IGrateful.Grateful_TokenNotWhitelisted.selector);
    grateful.withdraw(nonWhitelistedToken);
  }

  function test_revertIfWithdrawVaultNotSet() public {
    vm.prank(owner);
    grateful.removeVault(address(token));

    vm.prank(merchant);
    vm.expectRevert(IGrateful.Grateful_VaultNotSet.selector);
    grateful.withdraw(address(token));
  }

  function test_revertIfWithdrawInvalidTokenAddress() public {
    vm.prank(merchant);
    vm.expectRevert(IGrateful.Grateful_TokenNotWhitelisted.selector);
    grateful.withdraw(address(0));
  }

  function test_revertIfWithdrawInvalidAmount(
    uint128 amount
  ) public {
    vm.assume(amount > 0);
    vm.assume(amount <= 10 ether);
    vm.assume(amount <= type(uint256).max / grateful.fee());
    uint256 paymentId = 1;

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.approve(address(grateful), amount);
    vm.prank(user);
    grateful.pay(merchant, address(token), amount, paymentId, true);

    vm.prank(merchant);
    vm.expectRevert(IGrateful.Grateful_InvalidAmount.selector);
    grateful.withdraw(address(token), 0);
  }

  function test_revertIfWithdrawExceedsShares(
    uint128 amount
  ) public {
    vm.assume(amount > 0);
    vm.assume(amount <= 10 ether);
    vm.assume(amount <= type(uint256).max / grateful.fee());
    uint256 paymentId = 1;

    vm.prank(user);
    token.mint(user, amount);
    vm.prank(user);
    token.approve(address(grateful), amount);
    vm.prank(user);
    grateful.pay(merchant, address(token), amount, paymentId, true);

    vm.prank(merchant);
    vm.expectRevert();
    grateful.withdraw(address(token), amount * 2);
  }

  function test_revertIfWithdrawMultipleMismatchedArrays(
    uint128 amount
  ) public {
    vm.assume(amount > 0);
    vm.assume(amount <= 10 ether);

    address[] memory tokens = new address[](2);
    tokens[0] = address(token);
    tokens[1] = address(token);

    uint256[] memory assets = new uint256[](1);
    assets[0] = amount;

    vm.prank(merchant);
    vm.expectRevert(IGrateful.Grateful_MismatchedArrays.selector);
    grateful.withdrawMultiple(tokens, assets);
  }

  function test_revertIfWithdrawWithNoShares() public {
    vm.prank(merchant);
    vm.expectRevert();
    grateful.withdraw(address(token));
  }
}
