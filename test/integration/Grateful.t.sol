// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OneTime} from "contracts/OneTime.sol";
import {IntegrationBase} from "test/integration/IntegrationBase.sol";

contract IntegrationGreeter is IntegrationBase {
  using SafeERC20 for IERC20;

  /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

  // Tests for Standard Payments
  function test_Payment() public {
    for (uint256 i = 0; i < _tokens.length; i++) {
      address tokenAddr = _tokens[i];
      string memory symbol = _tokenSymbols[tokenAddr];
      uint256 amount = _tokenAmounts[tokenAddr];

      _approveAndPay(_user, _merchant, tokenAddr, amount, _NOT_YIELDING_FUNDS);

      uint256 expectedMerchantBalance = _grateful.applyFee(_merchant, amount);
      assertEq(
        IERC20(tokenAddr).balanceOf(_merchant),
        expectedMerchantBalance,
        string(abi.encodePacked(symbol, ": Merchant balance mismatch after payment"))
      );
    }
  }

  function test_PaymentYieldingFunds() public {
    for (uint256 i = 0; i < _tokens.length; i++) {
      address tokenAddr = _tokens[i];
      string memory symbol = _tokenSymbols[tokenAddr];
      uint256 amount = _tokenAmounts[tokenAddr];

      IERC20 token = IERC20(tokenAddr);

      // Capture owner's initial balance before payment
      uint256 ownerInitialBalance = token.balanceOf(_owner);

      _approveAndPay(_user, _merchant, tokenAddr, amount, _YIELDING_FUNDS);

      // Advance time to accrue yield
      vm.warp(block.timestamp + 1 days);

      // Calculate profit before withdrawal
      uint256 profit = _grateful.calculateProfit(_merchant, tokenAddr);

      // Merchant withdraws funds
      vm.prank(_merchant);
      _grateful.withdraw(tokenAddr);

      // Calculate performance fee after withdrawal
      uint256 performanceFee = _grateful.calculatePerformanceFee(profit);

      uint256 initialDeposit = _grateful.applyFee(_merchant, amount);
      uint256 expectedMerchantBalance = initialDeposit + profit - performanceFee;

      // Verify merchant's balance
      assertEq(
        token.balanceOf(_merchant),
        expectedMerchantBalance,
        string(abi.encodePacked(symbol, ": Merchant balance mismatch after withdrawal"))
      );

      // Verify owner's balance
      uint256 ownerFinalBalance = token.balanceOf(_owner);
      uint256 initialFee = amount - initialDeposit;
      uint256 ownerExpectedBalanceIncrease = initialFee + performanceFee;

      assertEq(
        ownerFinalBalance - ownerInitialBalance,
        ownerExpectedBalanceIncrease,
        string(abi.encodePacked(symbol, ": Owner did not receive correct performance fee"))
      );
    }
  }

  // Tests for One-Time Payments
  function test_OneTimePayment() public {
    for (uint256 i = 0; i < _tokens.length; i++) {
      address tokenAddr = _tokens[i];
      string memory symbol = _tokenSymbols[tokenAddr];
      uint256 amount = _tokenAmounts[tokenAddr];

      _setupAndExecuteOneTimePayment(_user, _merchant, tokenAddr, amount, _PAYMENT_SALT, _NOT_YIELDING_FUNDS);

      // Merchant receives the payment
      uint256 expectedMerchantBalance = _grateful.applyFee(_merchant, amount);
      assertEq(
        IERC20(tokenAddr).balanceOf(_merchant),
        expectedMerchantBalance,
        string(abi.encodePacked(symbol, ": Merchant balance mismatch after one-time payment"))
      );
    }
  }

  function test_OneTimePaymentYieldingFunds() public {
    for (uint256 i = 0; i < _tokens.length; i++) {
      address tokenAddr = _tokens[i];
      string memory symbol = _tokenSymbols[tokenAddr];
      uint256 amount = _tokenAmounts[tokenAddr];

      IERC20 token = IERC20(tokenAddr);

      // Capture owner's initial balance before payment
      uint256 ownerInitialBalance = token.balanceOf(_owner);

      // Setup one-time payment with yielding funds
      _setupAndExecuteOneTimePayment(_user, _merchant, tokenAddr, amount, _PAYMENT_SALT, _YIELDING_FUNDS);

      // Advance time to accrue yield
      vm.warp(block.timestamp + 1 days);

      // Calculate profit before withdrawal
      uint256 profit = _grateful.calculateProfit(_merchant, tokenAddr);

      // Merchant withdraws funds
      vm.prank(_merchant);
      _grateful.withdraw(tokenAddr);

      // Calculate performance fee after withdrawal
      uint256 performanceFee = _grateful.calculatePerformanceFee(profit);

      uint256 initialDeposit = _grateful.applyFee(_merchant, amount);
      uint256 expectedMerchantBalance = initialDeposit + profit - performanceFee;

      // Verify merchant's balance
      assertEq(
        token.balanceOf(_merchant),
        expectedMerchantBalance,
        string(abi.encodePacked(symbol, ": Merchant balance mismatch after withdrawal"))
      );

      // Verify owner's balance
      uint256 ownerFinalBalance = token.balanceOf(_owner);
      uint256 initialFee = amount - initialDeposit;
      uint256 ownerExpectedBalanceIncrease = initialFee + performanceFee;

      assertEq(
        ownerFinalBalance - ownerInitialBalance,
        ownerExpectedBalanceIncrease,
        string(abi.encodePacked(symbol, ": Owner did not receive correct performance fee"))
      );
    }
  }

  function test_OverpaidOneTimePayment() public {
    for (uint256 i = 0; i < _tokens.length; i++) {
      address tokenAddr = _tokens[i];
      string memory symbol = _tokenSymbols[tokenAddr];
      uint256 amount = _tokenAmounts[tokenAddr];

      uint256 paymentId = _grateful.calculateId(_user, _merchant, tokenAddr, amount);
      address precomputed = address(
        _grateful.computeOneTimeAddress(_merchant, _tokens, amount, _PAYMENT_SALT, paymentId, _NOT_YIELDING_FUNDS)
      );

      // Payer sends double the amount
      deal(tokenAddr, _user, amount * 2);
      vm.prank(_user);
      IERC20 token = IERC20(tokenAddr);
      token.safeTransfer(precomputed, amount * 2);

      vm.prank(_gratefulAutomation);
      OneTime _oneTime = _grateful.createOneTimePayment(
        _merchant, _tokens, amount, _PAYMENT_SALT, paymentId, _NOT_YIELDING_FUNDS, precomputed
      );

      // Merchant receives the correct amount
      uint256 expectedMerchantBalance = _grateful.applyFee(_merchant, amount);
      assertEq(
        token.balanceOf(_merchant),
        expectedMerchantBalance,
        string(abi.encodePacked(symbol, ": Merchant balance mismatch after overpaid one-time payment"))
      );

      // Verify excess funds are in the OneTime contract
      assertEq(
        token.balanceOf(address(_oneTime)),
        amount,
        string(abi.encodePacked(symbol, ": Unexpected balance in OneTime contract after overpayment"))
      );

      // Rescue funds
      uint256 prevPayerBalance = token.balanceOf(_user);
      vm.prank(_owner);
      _oneTime.rescueFunds(token, _user, amount);

      // Verify payer's balance after rescuing funds
      assertEq(
        token.balanceOf(_user),
        prevPayerBalance + amount,
        string(abi.encodePacked(symbol, ": Payer balance mismatch after rescuing funds"))
      );
    }
  }

  function test_PaymentWithCustomFee() public {
    uint256[] memory customFees = new uint256[](3);
    customFees[0] = 200; // 2%
    customFees[1] = 0; // 0%
    customFees[2] = _FEE; // Default fee after unsetting custom fee

    for (uint256 i = 0; i < _tokens.length; i++) {
      address tokenAddr = _tokens[i];
      string memory symbol = _tokenSymbols[tokenAddr];
      uint256 amount = _tokenAmounts[tokenAddr];

      uint256 expectedOwnerBalance = 0;
      uint256 expectedMerchantBalance = 0;

      for (uint256 j = 0; j < customFees.length; j++) {
        // Set custom fee
        vm.prank(_owner);
        if (j < 2) {
          _grateful.setCustomFee(customFees[j], _merchant);
        } else {
          _grateful.unsetCustomFee(_merchant);
        }

        // Advance time to prevent payment ID collision
        vm.warp(block.timestamp + 1);

        // Process payment
        _approveAndPay(_user, _merchant, tokenAddr, amount, _NOT_YIELDING_FUNDS);

        // Calculate expected amounts
        uint256 feeAmount = (amount * customFees[j]) / 10_000;
        uint256 merchantAmount = amount - feeAmount;

        expectedOwnerBalance += feeAmount;
        expectedMerchantBalance += merchantAmount;

        // Verify balances
        assertEq(
          IERC20(tokenAddr).balanceOf(_merchant),
          expectedMerchantBalance,
          string(abi.encodePacked(symbol, ": Merchant balance mismatch at iteration ", j))
        );
        assertEq(
          IERC20(tokenAddr).balanceOf(_owner),
          expectedOwnerBalance,
          string(abi.encodePacked(symbol, ": Owner balance mismatch at iteration ", j))
        );
      }
    }
  }
}
