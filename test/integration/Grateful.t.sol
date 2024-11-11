// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {OneTime} from "contracts/OneTime.sol";
import {IntegrationBase} from "test/integration/IntegrationBase.sol";

contract IntegrationGreeter is IntegrationBase {
  function _approveAndPay(address payer, address merchant, uint256 amount, bool _yieldFunds) internal {
    uint256 paymentId = _grateful.calculateId(payer, merchant, address(_usdc), amount);
    vm.startPrank(payer);
    _usdc.approve(address(_grateful), amount);
    _grateful.pay(merchant, address(_usdc), amount, paymentId, _yieldFunds);
    vm.stopPrank();
  }

  function test_Payment() public {
    _approveAndPay(_payer, _merchant, _AMOUNT_USDC, false);

    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _AMOUNT_USDC));
  }

  function test_PaymentYieldingFunds() public {
    _approveAndPay(_payer, _merchant, _AMOUNT_USDC, true);

    vm.warp(block.timestamp + 1 days);

    vm.prank(_merchant);
    _grateful.withdraw(address(_usdc));

    assertGt(_usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _AMOUNT_USDC));
  }

  function test_OneTimePayment() public {
    // 1. Calculate payment id
    uint256 paymentId = _grateful.calculateId(_payer, _merchant, address(_usdc), _AMOUNT_USDC);

    // 2. Precompute address
    address precomputed =
      address(_grateful.computeOneTimeAddress(_merchant, _tokens, _AMOUNT_USDC, 4, paymentId, false));

    // 3. Once the payment address is precomputed, the client sends the payment
    vm.prank(_payer);
    _usdc.transfer(precomputed, _AMOUNT_USDC); // Only tx sent by the client, doesn't need contract interaction

    // 4. Merchant calls api to make one time payment to his address
    vm.prank(_gratefulAutomation);
    _grateful.createOneTimePayment(_merchant, _tokens, _AMOUNT_USDC, 4, paymentId, false, precomputed);

    // Merchant receives the payment
    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _AMOUNT_USDC));
  }

  function test_OverpaidOneTimePayment() public {
    // 1. Calculate payment id
    uint256 paymentId = _grateful.calculateId(_payer, _merchant, address(_usdc), _AMOUNT_USDC);

    // 2. Precompute address
    address precomputed =
      address(_grateful.computeOneTimeAddress(_merchant, _tokens, _AMOUNT_USDC, 4, paymentId, false));

    // 3. Once the payment address is precomputed, the client sends the payment
    vm.prank(_payer);
    _usdc.transfer(precomputed, _AMOUNT_USDC * 2); // Only tx sent by the client, doesn't need contract interaction

    // 4. Merchant calls api to make one time payment to his address
    vm.prank(_gratefulAutomation);
    OneTime _oneTime =
      _grateful.createOneTimePayment(_merchant, _tokens, _AMOUNT_USDC, 4, paymentId, false, precomputed);

    // Merchant receives the payment
    assertEq(_usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _AMOUNT_USDC));

    // There are funds in the onetime contract stucked
    assertEq(_usdc.balanceOf(address(_oneTime)), _AMOUNT_USDC);

    uint256 prevWhaleBalance = _usdc.balanceOf(_payer);

    // Rescue funds
    vm.prank(_owner);
    _oneTime.rescueFunds(_usdc, _payer, _AMOUNT_USDC);

    // Client has received his funds
    assertEq(_usdc.balanceOf(address(_payer)), prevWhaleBalance + _AMOUNT_USDC);
  }

  function test_PaymentWithCustomFee() public {
    // ------------------------------
    // 1. Set custom fee of 2% (200 basis points) for the merchant
    // ------------------------------
    vm.prank(_owner);
    _grateful.setCustomFee(200, _merchant);

    // Process payment with custom fee of 2%
    _approveAndPay(_payer, _merchant, _AMOUNT_USDC, false);

    // Expected amounts
    uint256 expectedCustomFee = (_AMOUNT_USDC * 200) / 10_000; // 2% fee
    uint256 expectedMerchantAmount = _AMOUNT_USDC - expectedCustomFee;

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
    _approveAndPay(_payer, _merchant, _AMOUNT_USDC, false);

    // Expected amounts
    uint256 expectedZeroFee = 0; // 0% fee
    uint256 expectedMerchantAmount2 = _AMOUNT_USDC;

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
    _approveAndPay(_payer, _merchant, _AMOUNT_USDC, false);

    // Expected amounts
    uint256 expectedFeeAfterUnset = (_AMOUNT_USDC * 100) / 10_000; // 1% fee
    uint256 expectedMerchantAmount3 = _AMOUNT_USDC - expectedFeeAfterUnset;

    // Verify balances after fourth payment
    assertEq(
      _usdc.balanceOf(_merchant),
      expectedMerchantAmount + expectedMerchantAmount2 + expectedMerchantAmount3,
      "Merchant balance mismatch after third payment"
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
    uint256 paymentId = _grateful.calculateId(_payer, _merchant, address(_usdc), _AMOUNT_USDC);

    // 2. Precompute address
    address precomputed = address(_grateful.computeOneTimeAddress(_merchant, _tokens, _AMOUNT_USDC, 4, paymentId, true));

    // 3. Once the payment address is precomputed, the client sends the payment
    vm.prank(_payer);
    _usdc.transfer(precomputed, _AMOUNT_USDC);

    // 4. Grateful automation calls api to make one time payment to his address
    vm.prank(_gratefulAutomation);
    _grateful.createOneTimePayment(_merchant, _tokens, _AMOUNT_USDC, 4, paymentId, true, precomputed);

    // 5. Advance time so yield is generated
    vm.warp(block.timestamp + 1 days);

    // 6. Merchant withdraws funds
    vm.prank(_merchant);
    _grateful.withdraw(address(_usdc));

    // 7. Check if merchant's balance is greater than the amount with fee applied
    assertGt(_usdc.balanceOf(_merchant), _grateful.applyFee(_merchant, _AMOUNT_USDC));

    // 8. Check that owner holds the fee amount
    uint256 feeAmount = _AMOUNT_USDC - _grateful.applyFee(_merchant, _AMOUNT_USDC);
    assertEq(_usdc.balanceOf(_owner), feeAmount);
  }
}
