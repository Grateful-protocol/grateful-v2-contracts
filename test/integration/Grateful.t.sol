// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/console.sol";
import {IntegrationBase} from "test/integration/IntegrationBase.sol";

contract IntegrationGreeter is IntegrationBase {
  function test_Payment() public {
    vm.startPrank(_daiWhale);
    _dai.approve(address(_grateful), 100);
    _grateful.pay(_merchant, address(_dai), 100);
    vm.stopPrank();

    assertEq(_dai.balanceOf(_merchant), 100);
  }

  function test_PaymentYieldingFunds() public {
    assertEq(_grateful.yieldingFunds(_merchant), false);

    vm.prank(_merchant);
    _grateful.switchYieldingFunds();

    assertEq(_grateful.yieldingFunds(_merchant), true);

    vm.startPrank(_daiWhale);
    _dai.approve(address(_grateful), 100);
    _grateful.pay(_merchant, address(_dai), 100);
    vm.stopPrank();
  }
}
