// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Base test contract
import {UnitBase} from "./helpers/Base.t.sol";

// Mock ERC20 token
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

// Grateful contract and related interfaces
import {Grateful, IGrateful} from "contracts/Grateful.sol";

contract UnitTokenManagement is UnitBase {
  function test_addTokenSuccess() public {
    address tokenToAdd = address(new ERC20Mock());
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.TokenAdded(tokenToAdd);
    grateful.addToken(tokenToAdd);
    assertTrue(grateful.tokensWhitelisted(tokenToAdd));
  }

  function test_revertIfAddTokenInvalidAddress() public {
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_InvalidAddress.selector);
    grateful.addToken(address(0));
  }

  function test_removeTokenSuccess() public {
    address tokenToRemove = address(new ERC20Mock());
    vm.prank(owner);
    grateful.addToken(tokenToRemove);
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.TokenRemoved(tokenToRemove);
    grateful.removeToken(tokenToRemove);
    assertFalse(grateful.tokensWhitelisted(tokenToRemove));
  }

  function test_revertIfRemoveTokenNotWhitelisted() public {
    address tokenToRemove = address(new ERC20Mock());
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_TokenNotWhitelisted.selector);
    grateful.removeToken(tokenToRemove);
  }
}
