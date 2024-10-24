// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {OneTime} from "contracts/OneTime.sol";
import {IntegrationBase} from "test/integration/IntegrationBase.sol";

contract IntegrationGreeter is IntegrationBase {
  function _approveAndPay(address payer, address merchant, uint256 amount) internal {
    uint256 paymentId = _grateful.calculateId(payer, merchant, address(_usdc), amount);
    vm.startPrank(payer);
    _usdc.approve(address(_grateful), amount);
    _grateful.pay(merchant, address(_usdc), amount, paymentId);
    vm.stopPrank();
  }

  function test_Payment() public {
    _approveAndPay(_payer, _merchant, _amount);

    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _amount));
  }

  function test_PaymentYieldingFunds() public {
    assertEq(_grateful.yieldingFunds(_merchant), false);

    vm.prank(_merchant);
    _grateful.switchYieldingFunds();

    assertEq(_grateful.yieldingFunds(_merchant), true);

    _approveAndPay(_payer, _merchant, _amount);

    vm.warp(block.timestamp + 60 days);

    vm.prank(_merchant);
    _grateful.withdraw(address(_usdc));

    assertGt(_usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _amount));
  }

  function test_OneTimePayment() public {
    // 1. Calculate payment id
    uint256 paymentId = _grateful.calculateId(_payer, _merchant, address(_usdc), _amount);

    // 2. Precompute address
    address precomputed = address(_grateful.computeOneTimeAddress(_merchant, _tokens, _amount, 4, paymentId));

    // 3. Once the payment address is precomputed, the client sends the payment
    vm.prank(_payer);
    _usdc.transfer(precomputed, _amount); // Only tx sent by the client, doesn't need contract interaction

    // 4. Merchant calls api to make one time payment to his address
    vm.prank(_gratefulAutomation);
    _grateful.createOneTimePayment(_merchant, _tokens, _amount, 4, paymentId, precomputed);

    // Merchant receives the payment
    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _amount));
  }

  function test_OverpaidOneTimePayment() public {
    // 1. Calculate payment id
    uint256 paymentId = _grateful.calculateId(_payer, _merchant, address(_usdc), _amount);

    // 2. Precompute address
    address precomputed = address(_grateful.computeOneTimeAddress(_merchant, _tokens, _amount, 4, paymentId));

    // 3. Once the payment address is precomputed, the client sends the payment
    vm.prank(_payer);
    _usdc.transfer(precomputed, _amount * 2); // Only tx sent by the client, doesn't need contract interaction

    // 4. Merchant calls api to make one time payment to his address
    vm.prank(_gratefulAutomation);
    OneTime _oneTime = _grateful.createOneTimePayment(_merchant, _tokens, _amount, 4, paymentId, precomputed);

    // Merchant receives the payment
    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _amount));

    // There are funds in the onetime contract stucked
    assertEq(_usdc.balanceOf(address(_oneTime)), _amount);

    uint256 prevWhaleBalance = _usdc.balanceOf(_payer);

    // Rescue funds
    vm.prank(_owner);
    _oneTime.rescueFunds(address(_usdc), _payer, _amount);

    // Client has received his funds
    assertEq(_usdc.balanceOf(address(_payer)), prevWhaleBalance + _amount);
  }

  function test_PaymentWithCustomFee() public {
    // ------------------------------
    // 1. Set custom fee of 2% (200 basis points) for the merchant
    // ------------------------------
    vm.prank(_owner);
    _grateful.setCustomFee(200, _merchant);

    // Process payment with custom fee of 2%
    _approveAndPay(_payer, _merchant, _amount);

    // Expected amounts
    uint256 expectedCustomFee = (_amount * 200) / 10_000; // 2% fee
    uint256 expectedMerchantAmount = _amount - expectedCustomFee;

    // Verify balances after first payment
    assertEq(_usdc.balanceOf(_merchant), expectedMerchantAmount, "Merchant balance mismatch after first payment");
    assertEq(_usdc.balanceOf(_owner), expectedCustomFee, "Owner balance mismatch after first payment");

    // ------------------------------
    // 2. Set custom fee of 0% (no fee) for the _merchant
    // ------------------------------
    vm.prank(_owner);
    _grateful.setCustomFee(0, _merchant);

    // Advance time so calculated paymentId doesn't collide
    vm.warp(block.timestamp + 1);

    // Process payment with custom fee of 0%
    _approveAndPay(_payer, _merchant, _amount);

    // Expected amounts
    uint256 expectedZeroFee = 0; // 0% fee
    uint256 expectedMerchantAmount2 = _amount;

    // Verify balances after second payment
    assertEq(
      _usdc.balanceOf(_merchant),
      expectedMerchantAmount + expectedMerchantAmount2,
      "Merchant balance mismatch after second payment"
    );
    assertEq(
      _usdc.balanceOf(_owner), expectedCustomFee + expectedZeroFee, "Owner balance mismatch after second payment"
    );

    // ------------------------------
    // 3. Unset custom fee for the _merchant (should revert to default fee)
    // ------------------------------
    vm.prank(_owner);
    _grateful.unsetCustomFee(_merchant);

    // Advance time so calculated paymentId doesn't collide
    vm.warp(block.timestamp + 1);

    // Process payment after unsetting custom fee
    _approveAndPay(_payer, _merchant, _amount);

    // Expected amounts
    uint256 expectedFeeAfterUnset = (_amount * 100) / 10_000; // 1% fee
    uint256 expectedMerchantAmount3 = _amount - expectedFeeAfterUnset;

    // Verify balances after fourth payment
    assertEq(
      _usdc.balanceOf(_merchant),
      expectedMerchantAmount + expectedMerchantAmount2 + expectedMerchantAmount3,
      "Merchant balance mismatch after fourth payment"
    );
    assertEq(
      _usdc.balanceOf(_owner),
      expectedCustomFee + expectedZeroFee + expectedFeeAfterUnset,
      "Owner balance mismatch after fourth payment"
    );
  }

  function test_OneTimePaymentYieldingFunds() public {
    address[] memory _tokens2 = new address[](1);
    _tokens2[0] = _tokens[0];

    // 1. Calculate payment id
    uint256 paymentId = _grateful.calculateId(_payer, _merchant, address(_usdc), _amount);

    // 2. Precompute address
    address precomputed = address(_grateful.computeOneTimeAddress(_merchant, _tokens, _amount, 4, paymentId));

    // 3. Once the payment address is precomputed, the client sends the payment
    vm.prank(_payer);
    _usdc.transfer(precomputed, _amount);

    // 4. Set merchant to yield funds
    vm.prank(_merchant);
    _grateful.switchYieldingFunds();

    // 5. Grateful automation calls api to make one time payment to his address
    vm.prank(_gratefulAutomation);
    _grateful.createOneTimePayment(_merchant, _tokens, _amount, 4, paymentId, precomputed);

    // 6. Advance time
    vm.warp(block.timestamp + 1 days);

    // 7. Merchant withdraws funds
    vm.prank(_merchant);
    _grateful.withdraw(address(_usdc));

    // 8. Check if merchant's balance is greater than the amount with fee applied
    assertGt(_usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _amount));

    // 9. Check that owner holds the fee amount
    uint256 feeAmount = _amount - _grateful.applyFee(_merchant, _amount);
    assertEq(_usdc.balanceOf(_owner), feeAmount);
  }

  function test_PaymentSplit() public {
    // 1. Define recipients and percentages
    address[] memory recipients = new address[](2);
    recipients[0] = makeAddr("recipient1"); // Recipient 1
    recipients[1] = makeAddr("recipient2"); // Recipient 2

    uint256[] memory percentages = new uint256[](2);
    percentages[0] = 7000; // 70%
    percentages[1] = 3000; // 30%

    // 2. Approve Grateful contract to spend USDC
    vm.startPrank(_payer);
    _usdc.approve(address(_grateful), _amount);

    // 3. Make a payment with splitting
    uint256 paymentId = _grateful.calculateId(_payer, _merchant, address(_usdc), _amount);

    _grateful.pay(_merchant, address(_usdc), _amount, paymentId, recipients, percentages);
    vm.stopPrank();

    // 4. Calculate expected amounts after fee
    uint256 amountAfterFee = _grateful.applyFee(_merchant, _amount);
    uint256 expectedAmountRecipient0 = (amountAfterFee * percentages[0]) / 10_000;
    uint256 expectedAmountRecipient1 = (amountAfterFee * percentages[1]) / 10_000;

    // 5. Check balances of recipients
    assertEq(_usdc.balanceOf(recipients[0]), expectedAmountRecipient0);
    assertEq(_usdc.balanceOf(recipients[1]), expectedAmountRecipient1);

    // Ensure the merchant did not receive any funds directly
    assertEq(_usdc.balanceOf(_merchant), 0);
  }

  function test_OneTimePaymentSplit() public {
    // 1. Define recipients and percentages
    address[] memory recipients = new address[](2);
    recipients[0] = makeAddr("recipient1"); // Recipient 1
    recipients[1] = makeAddr("recipient2"); // Recipient 2

    uint256[] memory percentages = new uint256[](2);
    percentages[0] = 7000; // 70%
    percentages[1] = 3000; // 30%

    // 2. Calculate payment id
    uint256 paymentId = _grateful.calculateId(_payer, _merchant, address(_usdc), _amount);

    // 3. Precompute address
    address precomputed =
      address(_grateful.computeOneTimeAddress(_merchant, _tokens, _amount, 4, paymentId, recipients, percentages));

    // 4. Once the payment address is precomputed, the client sends the payment
    vm.prank(_payer);
    _usdc.transfer(precomputed, _amount);

    // 5. Merchant calls api to make one time payment to his address
    vm.prank(_gratefulAutomation);
    _grateful.createOneTimePayment(_merchant, _tokens, _amount, 4, paymentId, precomputed, recipients, percentages);

    // 6. Calculate expected amounts after fee
    uint256 amountAfterFee = _grateful.applyFee(_merchant, _amount);
    uint256 expectedAmountRecipient0 = (amountAfterFee * percentages[0]) / 10_000;
    uint256 expectedAmountRecipient1 = (amountAfterFee * percentages[1]) / 10_000;

    // 7. Check balances of recipients
    assertEq(_usdc.balanceOf(recipients[0]), expectedAmountRecipient0);
    assertEq(_usdc.balanceOf(recipients[1]), expectedAmountRecipient1);

    // Ensure owner received the fee
    uint256 feeAmount = _amount - amountAfterFee;
    assertEq(_usdc.balanceOf(_owner), feeAmount);
  }
}
