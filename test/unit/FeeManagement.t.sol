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

  function test_setFeeSuccess() public {
    uint256 newFee = 0.02 ether; // 2%

    // Set the fee as the owner
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.FeeUpdated(newFee);
    grateful.setFee(newFee);

    // Verify that the fee was updated
    assertEq(grateful.fee(), newFee, "Fee was not updated correctly");
  }

  function test_revertIfSetFeeNotOwner() public {
    uint256 newFee = 0.02 ether; // 2%

    // Attempt to set the fee as a non-owner and expect a revert
    vm.prank(user);
    vm.expectRevert();
    grateful.setFee(newFee);
  }

  function test_revertIfSetFeeTooHigh() public {
    uint256 invalidFee = 1.1 ether; // 110%, exceeds MAX_FEE

    // Attempt to set an invalid fee and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_FeeRateTooHigh.selector);
    grateful.setFee(invalidFee);
  }

  /*//////////////////////////////////////////////////////////////
                          SETTING PERFORMANCE FEE
    //////////////////////////////////////////////////////////////*/

  function test_setPerformanceFeeSuccess() public {
    uint256 newPerformanceFee = 0.1 ether; // 10%

    // Set the performance fee as the owner
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.PerformanceFeeUpdated(newPerformanceFee);
    grateful.setPerformanceFee(newPerformanceFee);

    // Verify that the performance fee was updated
    assertEq(grateful.performanceFee(), newPerformanceFee, "Performance fee was not updated correctly");
  }

  function test_revertIfSetPerformanceFeeNotOwner() public {
    uint256 newPerformanceFee = 0.1 ether; // 10%

    // Attempt to set the performance fee as a non-owner and expect a revert
    vm.prank(user);
    vm.expectRevert();
    grateful.setPerformanceFee(newPerformanceFee);
  }

  function test_revertIfSetPerformanceFeeTooHigh() public {
    uint256 invalidPerformanceFee = 0.6 ether; // 60%, exceeds MAX_PERFORMANCE_FEE

    // Attempt to set an invalid performance fee and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_FeeRateTooHigh.selector);
    grateful.setPerformanceFee(invalidPerformanceFee);
  }

  /*//////////////////////////////////////////////////////////////
                        SETTING CUSTOM FEE FOR MERCHANT
    //////////////////////////////////////////////////////////////*/

  function test_setCustomFeeSuccess() public {
    uint256 customFee = 0.03 ether; // 3%

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

  function test_revertIfSetCustomFeeNotOwner() public {
    uint256 customFee = 0.03 ether; // 3%

    // Attempt to set a custom fee as a non-owner and expect a revert
    vm.prank(user);
    vm.expectRevert();
    grateful.setCustomFee(customFee, merchant);
  }

  function test_revertIfSetCustomFeeInvalidMerchant() public {
    uint256 customFee = 0.03 ether; // 3%

    // Attempt to set a custom fee with an invalid merchant address and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_InvalidAddress.selector);
    grateful.setCustomFee(customFee, address(0));
  }

  function test_revertIfSetCustomFeeTooHigh() public {
    uint256 invalidCustomFee = 1.1 ether; // 110%, exceeds MAX_FEE

    // Attempt to set an invalid custom fee and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_FeeRateTooHigh.selector);
    grateful.setCustomFee(invalidCustomFee, merchant);
  }

  /*//////////////////////////////////////////////////////////////
                          UNSETTING CUSTOM FEE
    //////////////////////////////////////////////////////////////*/

  function test_unsetCustomFeeSuccess() public {
    uint256 customFee = 0.03 ether; // 3%

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

  function test_revertIfUnsetCustomFeeNotOwner() public {
    // Attempt to unset a custom fee as a non-owner and expect a revert
    vm.prank(user);
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

  function test_applyFeeWithGeneralFee() public {
    uint256 amount = 0 ether; // Example amount
    uint256 expectedFee = (amount * grateful.fee()) / 1e18;
    uint256 expectedAmountAfterFee = amount - expectedFee;

    // Calculate amount after fee
    uint256 amountAfterFee = grateful.applyFee(merchant, amount);

    // Verify the amount after fee is correct
    assertEq(amountAfterFee, expectedAmountAfterFee, "Amount after fee is incorrect");
  }

  function test_applyFeeWithCustomFee() public {
    uint256 amount = 0 ether; // Example amount
    uint256 customFee = 0.02 ether; // 2%

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

  function test_calculatePerformanceFee() public {
    uint256 profit = 500 ether; // Example profit
    uint256 expectedPerformanceFee = (profit * grateful.performanceFee()) / 1e18;

    // Calculate performance fee
    uint256 performanceFeeAmount = grateful.calculatePerformanceFee(profit);

    // Verify the performance fee is correct
    assertEq(performanceFeeAmount, expectedPerformanceFee, "Performance fee calculation is incorrect");
  }

  /*//////////////////////////////////////////////////////////////
                           ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

  function test_revertIfNonOwnerCallsFeeFunctions() public {
    uint256 newFee = 0.02 ether;
    uint256 newPerformanceFee = 0.1 ether;

    // Attempt to call setFee as non-owner
    vm.prank(user);
    vm.expectRevert();
    grateful.setFee(newFee);

    // Attempt to call setPerformanceFee as non-owner
    vm.prank(user);
    vm.expectRevert();
    grateful.setPerformanceFee(newPerformanceFee);

    // Attempt to call setCustomFee as non-owner
    vm.prank(user);
    vm.expectRevert();
    grateful.setCustomFee(newFee, merchant);

    // Attempt to call unsetCustomFee as non-owner
    vm.prank(user);
    vm.expectRevert();
    grateful.unsetCustomFee(merchant);
  }
}
