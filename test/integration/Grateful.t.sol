// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IGrateful, IntegrationBase} from "test/integration/IntegrationBase.sol";

contract IntegrationGreeter is IntegrationBase {
  function test_Payment() public {
    vm.startPrank(_usdcWhale);
    _usdc.approve(address(_grateful), _amount);
    _grateful.pay(
      _merchant, address(_usdc), _amount, _grateful.calculateId(_usdcWhale, _merchant, address(_usdc), _amount)
    );
    vm.stopPrank();

    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_amount));
  }

  function test_PaymentYieldingFunds() public {
    assertEq(_grateful.yieldingFunds(_merchant), false);

    vm.prank(_merchant);
    _grateful.switchYieldingFunds();

    assertEq(_grateful.yieldingFunds(_merchant), true);

    vm.startPrank(_usdcWhale);
    _usdc.approve(address(_grateful), _amount);
    _grateful.pay(
      _merchant, address(_usdc), _amount, _grateful.calculateId(_usdcWhale, _merchant, address(_usdc), _amount)
    );
    vm.stopPrank();

    vm.warp(block.timestamp + 60 days);

    vm.prank(_merchant);
    _grateful.withdraw(address(_usdc));

    assertGt(_usdc.balanceOf(_merchant), _grateful.applyFee(_amount));
  }

  function test_Subscription() public {
    vm.startPrank(_usdcWhale);
    _usdc.approve(address(_grateful), _amount * 2);

    vm.expectEmit(address(_grateful));

    emit IGrateful.SubscriptionCreated(
      0, // Because it is the first subscription
      _usdcWhale,
      _merchant,
      _amount,
      _subscriptionPlanId
    );

    uint256 subscriptionId = _grateful.subscribe(address(_usdc), _merchant, _amount, _subscriptionPlanId, 30 days, 2);
    vm.stopPrank();

    // When subscription is created, a initial payment is made
    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_amount));

    // Shouldn't be able to process the subscription before 30 days have passed
    vm.expectRevert(IGrateful.Grateful_TooEarlyForNextPayment.selector);
    _grateful.processSubscription(subscriptionId);

    // Fast forward 30 days
    vm.warp(block.timestamp + 30 days);

    _grateful.processSubscription(subscriptionId);

    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_amount) * 2);

    // Should revert if the payments amount has been reached

    // Fast forward 30 days
    vm.warp(block.timestamp + 30 days);

    vm.expectRevert(IGrateful.Grateful_PaymentsAmountReached.selector);
    _grateful.processSubscription(subscriptionId);

    // Now, the sender extends the subscription
    vm.startPrank(_usdcWhale);

    // Approve additional funds for the extended payments
    _usdc.approve(address(_grateful), _amount * 2);

    // Extend the subscription by 2 additional payments
    _grateful.extendSubscription(subscriptionId, 2);

    vm.stopPrank();

    // Process the extended payments

    // Fast forward 30 days
    vm.warp(block.timestamp + 30 days);

    _grateful.processSubscription(subscriptionId);

    // The merchant should have received three payments in total
    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_amount) * 3);

    // Fast forward another 30 days
    vm.warp(block.timestamp + 30 days);

    _grateful.processSubscription(subscriptionId);

    // The merchant should have received four payments in total
    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_amount) * 4);

    // Should revert if the payments amount has been reached again

    // Fast forward 30 days
    vm.warp(block.timestamp + 30 days);

    vm.expectRevert(IGrateful.Grateful_PaymentsAmountReached.selector);
    _grateful.processSubscription(subscriptionId);

    // Now, test cancellation by the sender

    // Sender cancels the subscription
    vm.prank(_usdcWhale);
    _grateful.cancelSubscription(subscriptionId);

    // Attempt to process the subscription after cancellation
    vm.warp(block.timestamp + 30 days);
    vm.expectRevert(IGrateful.Grateful_SubscriptionDoesNotExist.selector);
    _grateful.processSubscription(subscriptionId);
  }

  function test_OneTimePayment() public {
    // 1. Calculate payment id
    uint256 paymentId = _grateful.calculateId(_usdcWhale, _merchant, address(_usdc), _amount);

    // 2. Precompute address
    address precomputed = address(_grateful.computeOneTimeAddress(_merchant, _tokens, _amount, 4, paymentId));

    // 3. Once the payment address is precomputed, the client sends the payment
    vm.prank(_usdcWhale);
    _usdc.transfer(precomputed, _amount); // Only tx sent by the client, doesn't need contract interaction

    // 4. Merchant calls api to make one time payment to his address
    vm.prank(_gratefulAutomation);
    _grateful.createOneTimePayment(_merchant, _tokens, _amount, 4, paymentId, precomputed);

    // Merchant receives the payment
    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_amount));
  }

  function test_OneTimePaymentYieldingFunds() public {
    address[] memory _tokens2 = new address[](1);
    _tokens2[0] = _tokens[0];

    // 1. Calculate payment id
    uint256 paymentId = _grateful.calculateId(_usdcWhale, _merchant, address(_usdc), _amount);

    // 2. Precompute address
    address precomputed = address(_grateful.computeOneTimeAddress(_merchant, _tokens, _amount, 4, paymentId));

    // 3. Once the payment address is precomputed, the client sends the payment
    vm.prank(_usdcWhale);
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
    assertGt(_usdc.balanceOf(_merchant), _grateful.applyFee(_amount));

    // 9. Check that owner holds the fee amount
    uint256 feeAmount = _amount - _grateful.applyFee(_amount);
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
    vm.startPrank(_usdcWhale);
    _usdc.approve(address(_grateful), _amount);

    // 3. Make a payment with splitting
    uint256 paymentId = _grateful.calculateId(_usdcWhale, _merchant, address(_usdc), _amount);

    _grateful.pay(_merchant, address(_usdc), _amount, paymentId, recipients, percentages);
    vm.stopPrank();

    // 4. Calculate expected amounts after fee
    uint256 amountAfterFee = _grateful.applyFee(_amount);
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
    uint256 paymentId = _grateful.calculateId(_usdcWhale, _merchant, address(_usdc), _amount);

    // 3. Precompute address
    address precomputed =
      address(_grateful.computeOneTimeAddress(_merchant, _tokens, _amount, 4, paymentId, recipients, percentages));

    // 4. Once the payment address is precomputed, the client sends the payment
    vm.prank(_usdcWhale);
    _usdc.transfer(precomputed, _amount);

    // 5. Merchant calls api to make one time payment to his address
    vm.prank(_gratefulAutomation);
    _grateful.createOneTimePayment(_merchant, _tokens, _amount, 4, paymentId, precomputed, recipients, percentages);

    // 6. Calculate expected amounts after fee
    uint256 amountAfterFee = _grateful.applyFee(_amount);
    uint256 expectedAmountRecipient0 = (amountAfterFee * percentages[0]) / 10_000;
    uint256 expectedAmountRecipient1 = (amountAfterFee * percentages[1]) / 10_000;

    // 7. Check balances of recipients
    assertEq(_usdc.balanceOf(recipients[0]), expectedAmountRecipient0);
    assertEq(_usdc.balanceOf(recipients[1]), expectedAmountRecipient1);

    // Ensure owner received the fee
    uint256 feeAmount = _amount - amountAfterFee;
    assertEq(_usdc.balanceOf(_owner), feeAmount);
  }

  function test_SubscriptionSplit() public {
    // 1. Define recipients and percentages
    address[] memory recipients = new address[](2);
    recipients[0] = makeAddr("recipient1"); // Recipient 1
    recipients[1] = makeAddr("recipient2"); // Recipient 2

    uint256[] memory percentages = new uint256[](2);
    percentages[0] = 7000; // 70%
    percentages[1] = 3000; // 30%

    // 2. Subscribe to a plan
    vm.startPrank(_usdcWhale);
    _usdc.approve(address(_grateful), _amount * 2);

    uint256 subscriptionId =
      _grateful.subscribe(address(_usdc), _merchant, _amount, _subscriptionPlanId, 30 days, 2, recipients, percentages);
    vm.stopPrank();

    // 3. Calculate expected amounts after fee
    uint256 amountAfterFee = _grateful.applyFee(_amount);
    uint256 expectedAmountRecipient0 = (amountAfterFee * percentages[0]) / 10_000;
    uint256 expectedAmountRecipient1 = (amountAfterFee * percentages[1]) / 10_000;

    // 4. Check balances of recipients
    assertEq(_usdc.balanceOf(recipients[0]), expectedAmountRecipient0);
    assertEq(_usdc.balanceOf(recipients[1]), expectedAmountRecipient1);

    // Ensure owner received the fee
    uint256 feeAmount = _amount - amountAfterFee;
    assertEq(_usdc.balanceOf(_owner), feeAmount);

    // 5. Fast forward time
    vm.warp(block.timestamp + 30 days);

    // 6. Process subscription
    vm.prank(_gratefulAutomation);
    _grateful.processSubscription(subscriptionId);

    // 7. Check balances of recipients
    assertEq(_usdc.balanceOf(recipients[0]), expectedAmountRecipient0 * 2);
    assertEq(_usdc.balanceOf(recipients[1]), expectedAmountRecipient1 * 2);

    // Ensure owner received the fee
    assertEq(_usdc.balanceOf(_owner), feeAmount * 2);
  }
}
