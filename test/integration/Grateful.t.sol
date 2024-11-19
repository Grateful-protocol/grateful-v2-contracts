// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {OneTime} from "contracts/OneTime.sol";
import {IntegrationBase} from "test/integration/IntegrationBase.sol";

contract IntegrationGreeter is IntegrationBase {
  /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

  // Tests for Standard Payments
  function test_Payment() public {
    _approveAndPay(_user, _merchant, _AMOUNT_USDC, _NOT_YIELDING_FUNDS);

    assertEq(
      _usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _AMOUNT_USDC), "Merchant balance mismatch after payment"
    );
  }

  function test_PaymentYieldingFunds() public {
    // Capture owner's initial balance before payment
    uint256 ownerInitialBalance = _usdc.balanceOf(_owner);

    _approveAndPay(_user, _merchant, _AMOUNT_USDC, _YIELDING_FUNDS);

    // Advance time to accrue yield
    vm.warp(block.timestamp + 1 days);

    // Calculate profit before withdrawal
    uint256 profit = _grateful.calculateProfit(_merchant, address(_usdc));

    // Merchant withdraws funds
    vm.prank(_merchant);
    _grateful.withdraw(address(_usdc));

    // Calculate performance fee after withdrawal
    uint256 performanceFee = _grateful.calculatePerformanceFee(profit);

    uint256 initialDeposit = _grateful.applyFee(_merchant, _AMOUNT_USDC);
    uint256 expectedMerchantBalance = initialDeposit + profit - performanceFee;

    // Verify merchant's balance
    assertEq(_usdc.balanceOf(_merchant), expectedMerchantBalance, "Merchant balance mismatch after withdrawal");

    // Verify owner's balance
    uint256 ownerFinalBalance = _usdc.balanceOf(_owner);
    uint256 initialFee = _AMOUNT_USDC - initialDeposit;
    uint256 ownerExpectedBalanceIncrease = initialFee + performanceFee;

    assertEq(
      ownerFinalBalance - ownerInitialBalance,
      ownerExpectedBalanceIncrease,
      "Owner did not receive correct performance fee"
    );
  }

  // Tests for One-Time Payments
  function test_OneTimePayment() public {
    _setupAndExecuteOneTimePayment(_user, _merchant, _AMOUNT_USDC, _PAYMENT_SALT, _NOT_YIELDING_FUNDS);

    // Merchant receives the payment
    assertEq(
      _usdc.balanceOf(_merchant),
      _grateful.applyFee(_merchant, _AMOUNT_USDC),
      "Merchant balance mismatch after one-time payment"
    );
  }

  function test_OneTimePaymentYieldingFunds() public {
    // Capture owner's initial balance before payment
    uint256 ownerInitialBalance = _usdc.balanceOf(_owner);

    // Setup one-time payment with yielding funds
    _setupAndExecuteOneTimePayment(_user, _merchant, _AMOUNT_USDC, _PAYMENT_SALT, _YIELDING_FUNDS);

    // Advance time to accrue yield
    vm.warp(block.timestamp + 1 days);

    // Calculate profit before withdrawal
    uint256 profit = _grateful.calculateProfit(_merchant, address(_usdc));

    // Merchant withdraws funds
    vm.prank(_merchant);
    _grateful.withdraw(address(_usdc));

    // Calculate performance fee after withdrawal
    uint256 performanceFee = _grateful.calculatePerformanceFee(profit);

    uint256 initialDeposit = _grateful.applyFee(_merchant, _AMOUNT_USDC);
    uint256 expectedMerchantBalance = initialDeposit + profit - performanceFee;

    // Verify merchant's balance
    assertEq(_usdc.balanceOf(_merchant), expectedMerchantBalance, "Merchant balance mismatch after withdrawal");

    // Verify owner's balance
    uint256 ownerFinalBalance = _usdc.balanceOf(_owner);
    uint256 initialFee = _AMOUNT_USDC - initialDeposit;
    uint256 ownerExpectedBalanceIncrease = initialFee + performanceFee;

    assertEq(
      ownerFinalBalance - ownerInitialBalance,
      ownerExpectedBalanceIncrease,
      "Owner did not receive correct performance fee"
    );
  }

  function test_OverpaidOneTimePayment() public {
    uint256 paymentId = _grateful.calculateId(_user, _merchant, address(_usdc), _AMOUNT_USDC);
    address precomputed = address(
      _grateful.computeOneTimeAddress(_merchant, _tokens, _AMOUNT_USDC, _PAYMENT_SALT, paymentId, _NOT_YIELDING_FUNDS)
    );

    // Payer sends double the amount
    deal(address(_usdc), _user, _AMOUNT_USDC * 2);
    vm.prank(_user);
    _usdc.transfer(precomputed, _AMOUNT_USDC * 2);

    vm.prank(_gratefulAutomation);
    OneTime _oneTime = _grateful.createOneTimePayment(
      _merchant, _tokens, _AMOUNT_USDC, _PAYMENT_SALT, paymentId, _NOT_YIELDING_FUNDS, precomputed
    );

    // Merchant receives the correct amount
    assertEq(
      _usdc.balanceOf(_merchant),
      _grateful.applyFee(_merchant, _AMOUNT_USDC),
      "Merchant balance mismatch after overpaid one-time payment"
    );

    // Verify excess funds are in the OneTime contract
    assertEq(
      _usdc.balanceOf(address(_oneTime)), _AMOUNT_USDC, "Unexpected balance in OneTime contract after overpayment"
    );

    // Rescue funds
    uint256 prevPayerBalance = _usdc.balanceOf(_user);
    vm.prank(_owner);
    _oneTime.rescueFunds(_usdc, _user, _AMOUNT_USDC);

    // Verify payer's balance after rescuing funds
    assertEq(_usdc.balanceOf(_user), prevPayerBalance + _AMOUNT_USDC, "Payer balance mismatch after rescuing funds");
  }

  function test_PaymentWithCustomFee() public {
    uint256[] memory customFees = new uint256[](3);
    customFees[0] = 200; // 2%
    customFees[1] = 0; // 0%
    customFees[2] = _FEE; // Default fee after unsetting custom fee

    uint256 expectedOwnerBalance = 0;
    uint256 expectedMerchantBalance = 0;

    for (uint256 i = 0; i < customFees.length; i++) {
      // Set custom fee
      vm.prank(_owner);
      if (i < 2) {
        _grateful.setCustomFee(customFees[i], _merchant);
      } else {
        _grateful.unsetCustomFee(_merchant);
      }

      // Advance time to prevent payment ID collision
      vm.warp(block.timestamp + 1);

      // Process payment
      _approveAndPay(_user, _merchant, _AMOUNT_USDC, _NOT_YIELDING_FUNDS);

      // Calculate expected amounts
      uint256 feeAmount = (_AMOUNT_USDC * customFees[i]) / 10_000;
      uint256 merchantAmount = _AMOUNT_USDC - feeAmount;

      expectedOwnerBalance += feeAmount;
      expectedMerchantBalance += merchantAmount;

      // Verify balances
      assertEq(
        _usdc.balanceOf(_merchant),
        expectedMerchantBalance,
        string(abi.encodePacked("Merchant balance mismatch at iteration ", i))
      );
      assertEq(
        _usdc.balanceOf(_owner),
        expectedOwnerBalance,
        string(abi.encodePacked("Owner balance mismatch at iteration ", i))
      );
    }
  }
}
