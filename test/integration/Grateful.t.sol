// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IntegrationBase} from "test/integration/IntegrationBase.sol";

contract IntegrationGreeter is IntegrationBase {
  function test_Payment() public {
    vm.startPrank(_daiWhale);
    _dai.approve(address(_grateful), _amount);
    _grateful.pay(_merchant, address(_dai), _amount);
    vm.stopPrank();

    assertEq(_dai.balanceOf(_merchant), _amount);
  }

  function test_PaymentYieldingFunds() public {
    assertEq(_grateful.yieldingFunds(_merchant), false);

    vm.prank(_merchant);
    _grateful.switchYieldingFunds();

    assertEq(_grateful.yieldingFunds(_merchant), true);

    vm.startPrank(_daiWhale);
    _dai.approve(address(_grateful), _amount);
    _grateful.pay(_merchant, address(_dai), _amount);
    vm.stopPrank();

    vm.warp(block.timestamp + 60 days);

    vm.prank(_merchant);
    _grateful.withdraw(address(_dai));

    assertGt(_dai.balanceOf(_merchant), _amount);
  }
}
