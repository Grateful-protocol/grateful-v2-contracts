// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Grateful contract and related interfaces
import {Grateful, IGrateful} from "contracts/Grateful.sol";

// Aave V3 interfaces
import {IPool} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

// Base test contract
import {UnitBase} from "./helpers/Base.t.sol";

contract UnitDeploy is UnitBase {
  // Test the constructor with valid arguments
  function test_ConstructorWhenPassingValidArgs() public {
    // Deploy the Grateful contract
    grateful = new Grateful(tokens, IPool(address(aavePool)), initialFee, initialPerformanceFee, owner);

    // Check that the Grateful contract is deployed correctly
    assertEq(grateful.owner(), owner);
    assertEq(address(grateful.aavePool()), address(aavePool));
    assertEq(grateful.fee(), initialFee);
    assertEq(grateful.performanceFee(), initialPerformanceFee);
    assertEq(grateful.tokensWhitelisted(address(token)), true);
  }

  // Test the constructor with an invalid pool address
  function test_revertIfConstructorWhenPassingInvalidPoolAddress() public {
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_InvalidAddress.selector));
    grateful = new Grateful(tokens, IPool(address(0)), initialFee, initialPerformanceFee, owner);
  }

  // Test the constructor with an invalid max fee
  function test_revertIfConstructorWhenPassingInvalidMaxFee(
    uint256 invalidFee
  ) public {
    vm.assume(invalidFee > grateful.MAX_FEE());
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_FeeRateTooHigh.selector));
    grateful = new Grateful(tokens, IPool(address(aavePool)), invalidFee, initialPerformanceFee, owner);
  }

  // Test the constructor with an invalid max performance fee
  function test_revertIfConstructorWhenPassingInvalidMaxPerformanceFee(
    uint256 invalidPerformanceFee
  ) public {
    vm.assume(invalidPerformanceFee > grateful.MAX_PERFORMANCE_FEE());
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_FeeRateTooHigh.selector));
    grateful = new Grateful(tokens, IPool(address(aavePool)), initialFee, invalidPerformanceFee, owner);
  }
}
