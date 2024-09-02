// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IGrateful, IntegrationBase, OneTime} from "test/integration/IntegrationBase.sol";

contract IntegrationGreeter is IntegrationBase {
  function test_Payment() public {
    vm.startPrank(_usdcWhale);
    _usdc.approve(address(_grateful), _amount);
    _grateful.pay(
      _merchant, address(_usdc), _amount, _grateful.calculateId(_usdcWhale, _merchant, address(_usdc), _amount)
    );
    vm.stopPrank();

    assertEq(_usdc.balanceOf(_merchant), _amount);
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

    assertGt(_usdc.balanceOf(_merchant), _amount);
  }

  function test_Subscription() public {
    vm.startPrank(_usdcWhale);
    _usdc.approve(address(_grateful), _amount * 2);
    uint256 subscriptionId = _grateful.subscribe(address(_usdc), _merchant, _amount, 30 days, 2);
    vm.stopPrank();

    // When subscription is created, a initial payment is made
    assertEq(_usdc.balanceOf(_merchant), _amount);

    // Shouldn't be able to process the subscription before 30 days have passed
    vm.expectRevert(IGrateful.Grateful_TooEarlyForNextPayment.selector);
    _grateful.processSubscription(subscriptionId);

    // Fast forward 30 days
    vm.warp(block.timestamp + 30 days);

    _grateful.processSubscription(subscriptionId);

    assertEq(_usdc.balanceOf(_merchant), _amount * 2);

    // Should revert if the payments amount has been reached

    // Fast forward 30 days
    vm.warp(block.timestamp + 30 days);

    vm.expectRevert(IGrateful.Grateful_PaymentsAmountReached.selector);
    _grateful.processSubscription(subscriptionId);
  }

  function test_OneTimePayment() public {
    // 1. Merchant calls api to make one time payment to his address
    vm.prank(_gratefulAutomation);
    address oneTimeAddress = _grateful.createOneTimePayment(_merchant, address(_usdc), _amount);

    // 2. Once the payment address is created, the client sends the payment
    vm.prank(_usdcWhale);
    _usdc.transfer(oneTimeAddress, _amount); // Only tx sent by the client, doesn't need contract interaction

    // 3. The payment is processed
    vm.prank(_gratefulAutomation);
    OneTime(oneTimeAddress).processPayment();

    // Merchant receives the payment
    assertEq(_usdc.balanceOf(_merchant), _amount);
  }
}
