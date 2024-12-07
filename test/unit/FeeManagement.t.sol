// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Base test contract
import {UnitBase} from "./helpers/Base.t.sol";

// Grateful contract and related interfaces
import {Grateful, IGrateful} from "contracts/Grateful.sol";

contract UnitFeeManagement is UnitBase {
  /*//////////////////////////////////////////////////////////////
                              SETTING GENERAL FEE
    //////////////////////////////////////////////////////////////*/

  function test_setFeeSuccess(
    uint256 newFee
  ) public {
    vm.assume(newFee <= grateful.MAX_FEE());

    // Set the fee as the owner
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.FeeUpdated(newFee);
    grateful.setFee(newFee);

    // Verify that the fee was updated
    assertEq(grateful.fee(), newFee, "Fee was not updated correctly");
  }

  function test_revertIfSetFeeNotOwner(address nonOwner, uint256 newFee) public {
    vm.assume(nonOwner != owner);
    vm.assume(newFee <= grateful.MAX_FEE());

    // Attempt to set the fee as a non-owner and expect a revert
    vm.prank(nonOwner);
    vm.expectRevert();
    grateful.setFee(newFee);
  }

  function test_revertIfSetFeeTooHigh(
    uint256 invalidFee
  ) public {
    vm.assume(invalidFee > grateful.MAX_FEE());

    // Attempt to set an invalid fee and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_FeeRateTooHigh.selector);
    grateful.setFee(invalidFee);
  }

  /*//////////////////////////////////////////////////////////////
                          SETTING PERFORMANCE FEE
    //////////////////////////////////////////////////////////////*/

  function test_setPerformanceFeeSuccess(
    uint256 newPerformanceFee
  ) public {
    vm.assume(newPerformanceFee <= grateful.MAX_PERFORMANCE_FEE());

    // Set the performance fee as the owner
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.PerformanceFeeUpdated(newPerformanceFee);
    grateful.setPerformanceFee(newPerformanceFee);

    // Verify that the performance fee was updated
    assertEq(grateful.performanceFee(), newPerformanceFee, "Performance fee was not updated correctly");
  }

  function test_revertIfSetPerformanceFeeNotOwner(address nonOwner, uint256 newPerformanceFee) public {
    vm.assume(nonOwner != owner);
    vm.assume(newPerformanceFee <= grateful.MAX_PERFORMANCE_FEE());

    // Attempt to set the performance fee as a non-owner and expect a revert
    vm.prank(nonOwner);
    vm.expectRevert();
    grateful.setPerformanceFee(newPerformanceFee);
  }

  function test_revertIfSetPerformanceFeeTooHigh(
    uint256 invalidPerformanceFee
  ) public {
    vm.assume(invalidPerformanceFee > grateful.MAX_PERFORMANCE_FEE());

    // Attempt to set an invalid performance fee and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_FeeRateTooHigh.selector);
    grateful.setPerformanceFee(invalidPerformanceFee);
  }

  /*//////////////////////////////////////////////////////////////
                        SETTING CUSTOM FEE FOR MERCHANT
    //////////////////////////////////////////////////////////////*/

  function test_setCustomFeeSuccess(
    uint256 customFee
  ) public {
    vm.assume(customFee <= grateful.MAX_FEE());

    // Set a custom fee for the merchant as the owner
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.CustomFeeUpdated(merchant, customFee);
    grateful.setCustomFee(customFee, merchant);

    // Verify that the custom fee was set
    (bool isSet, uint256 fee) = grateful.customFees(merchant);
    assertTrue(isSet, "Custom fee was not set");
    assertEq(fee, customFee, "Custom fee value is incorrect");
  }

  function test_revertIfSetCustomFeeNotOwner(address nonOwner, uint256 customFee) public {
    vm.assume(nonOwner != owner);
    vm.assume(customFee <= grateful.MAX_FEE());

    // Attempt to set a custom fee as a non-owner and expect a revert
    vm.prank(nonOwner);
    vm.expectRevert();
    grateful.setCustomFee(customFee, merchant);
  }

  function test_revertIfSetCustomFeeInvalidMerchant(
    uint256 customFee
  ) public {
    vm.assume(customFee <= grateful.MAX_FEE());

    // Attempt to set a custom fee with an invalid merchant address and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_InvalidAddress.selector);
    grateful.setCustomFee(customFee, address(0));
  }

  function test_revertIfSetCustomFeeTooHigh(
    uint256 invalidCustomFee
  ) public {
    vm.assume(invalidCustomFee > grateful.MAX_FEE());

    // Attempt to set an invalid custom fee and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_FeeRateTooHigh.selector);
    grateful.setCustomFee(invalidCustomFee, merchant);
  }

  /*//////////////////////////////////////////////////////////////
                          UNSETTING CUSTOM FEE
    //////////////////////////////////////////////////////////////*/

  function test_unsetCustomFeeSuccess(
    uint256 customFee
  ) public {
    vm.assume(customFee <= grateful.MAX_FEE());

    // Arrange: Set a custom fee first
    vm.prank(owner);
    grateful.setCustomFee(customFee, merchant);

    // Unset the custom fee
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.CustomFeeUnset(merchant);
    grateful.unsetCustomFee(merchant);

    // Verify that the custom fee was unset
    (bool isSet, uint256 fee) = grateful.customFees(merchant);
    assertFalse(isSet, "Custom fee was not unset");
    assertEq(fee, 0, "Custom fee value should be zero after unset");
  }

  function test_revertIfUnsetCustomFeeNotOwner(
    address nonOwner
  ) public {
    vm.assume(nonOwner != owner);

    // Attempt to unset a custom fee as a non-owner and expect a revert
    vm.prank(nonOwner);
    vm.expectRevert();
    grateful.unsetCustomFee(merchant);
  }

  function test_revertIfUnsetCustomFeeInvalidMerchant() public {
    // Attempt to unset a custom fee with an invalid merchant address and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_InvalidAddress.selector);
    grateful.unsetCustomFee(address(0));
  }

  /*//////////////////////////////////////////////////////////////
                            APPLY FEE FUNCTION
    //////////////////////////////////////////////////////////////*/

  function test_applyFeeWithGeneralFee(
    uint256 amount
  ) public {
    vm.assume(amount > 0);
    // Ensure amount * fee won't overflow when divided by 1e18
    vm.assume(amount <= type(uint256).max / grateful.fee());

    uint256 expectedFee = (amount * grateful.fee()) / 1e18;
    uint256 expectedAmountAfterFee = amount - expectedFee;

    // Calculate amount after fee
    uint256 amountAfterFee = grateful.applyFee(merchant, amount);

    // Verify the amount after fee is correct
    assertEq(amountAfterFee, expectedAmountAfterFee, "Amount after fee is incorrect");
  }

  function test_applyFeeWithCustomFee(uint256 amount, uint256 customFee) public {
    vm.assume(amount > 0);
    vm.assume(customFee <= grateful.MAX_FEE());
    if (customFee > 0) {
      vm.assume(amount <= type(uint256).max / customFee);
    }

    // Arrange: Set a custom fee for the merchant
    vm.prank(owner);
    grateful.setCustomFee(customFee, merchant);

    uint256 expectedFee = (amount * customFee) / 1e18;
    uint256 expectedAmountAfterFee = amount - expectedFee;

    // Calculate amount after fee
    uint256 amountAfterFee = grateful.applyFee(merchant, amount);

    // Verify the amount after fee is correct
    assertEq(amountAfterFee, expectedAmountAfterFee, "Amount after custom fee is incorrect");
  }

  /*//////////////////////////////////////////////////////////////
                        CALCULATE PERFORMANCE FEE
    //////////////////////////////////////////////////////////////*/

  function test_calculatePerformanceFee(
    uint256 profit
  ) public {
    vm.assume(profit > 0);
    // Ensure profit * performanceFee won't overflow when divided by 1e18
    vm.assume(profit <= type(uint256).max / grateful.performanceFee());

    uint256 expectedPerformanceFee = (profit * grateful.performanceFee()) / 1e18;

    // Calculate performance fee
    uint256 performanceFeeAmount = grateful.calculatePerformanceFee(profit);

    // Verify the performance fee is correct
    assertEq(performanceFeeAmount, expectedPerformanceFee, "Performance fee calculation is incorrect");
  }

  /*//////////////////////////////////////////////////////////////
                           ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

  function test_revertIfNonOwnerCallsFeeFunctions(address nonOwner, uint256 newFee, uint256 newPerformanceFee) public {
    vm.assume(nonOwner != owner);
    vm.assume(newFee <= grateful.MAX_FEE());
    vm.assume(newPerformanceFee <= grateful.MAX_PERFORMANCE_FEE());

    // Attempt to call setFee as non-owner
    vm.prank(nonOwner);
    vm.expectRevert();
    grateful.setFee(newFee);

    // Attempt to call setPerformanceFee as non-owner
    vm.prank(nonOwner);
    vm.expectRevert();
    grateful.setPerformanceFee(newPerformanceFee);

    // Attempt to call setCustomFee as non-owner
    vm.prank(nonOwner);
    vm.expectRevert();
    grateful.setCustomFee(newFee, merchant);

    // Attempt to call unsetCustomFee as non-owner
    vm.prank(nonOwner);
    vm.expectRevert();
    grateful.unsetCustomFee(merchant);
  }
}
