// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Base test contract
import {UnitBase} from "./helpers/Base.t.sol";

// Mock ERC20 token
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

// Grateful contract and related interfaces
import {Grateful, IGrateful} from "contracts/Grateful.sol";
import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";

// Mocks for Aave V3 dependencies
import {PoolMock} from "test/aave-v3/mocks/PoolMock.sol";
import {RewardsControllerMock} from "test/aave-v3/mocks/RewardsControllerMock.sol";

// Solmate ERC20 import for vault creation
import {ERC20} from "solmate/tokens/ERC20.sol";

// Aave V3 interfaces
import {IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract UnitVaultManagement is UnitBase {
  function test_AddVault() public {
    // Deploy a new token and whitelist it
    address newToken = address(new ERC20Mock());
    vm.prank(owner);
    grateful.addToken(newToken);

    // Deploy a new AaveV3Vault for the token
    AaveV3Vault newVault = new AaveV3Vault(
      ERC20(newToken),
      ERC20(address(0)), // Replace with appropriate aToken mock if needed
      IPool(address(0)), // Replace with appropriate PoolMock if needed
      owner,
      IRewardsController(address(0)), // Replace with appropriate RewardsControllerMock if needed
      address(grateful)
    );

    // Act: Add the vault
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.VaultAdded(newToken, address(newVault));
    grateful.addVault(newToken, address(newVault));

    // Assert: Verify that the vault was added
    assertEq(address(grateful.vaults(newToken)), address(newVault), "Vault was not added correctly");
  }

  function test_revertIfAddVaultTokenNotWhitelisted() public {
    // Deploy a new token without whitelisting
    address newToken = address(new ERC20Mock());

    // Deploy a new AaveV3Vault for the token
    AaveV3Vault newVault = new AaveV3Vault(
      ERC20(newToken),
      ERC20(address(0)), // Replace with appropriate aToken mock if needed
      IPool(address(0)), // Replace with appropriate PoolMock if needed
      owner,
      IRewardsController(address(0)), // Replace with appropriate RewardsControllerMock if needed
      address(grateful)
    );

    // Attempt to add the vault and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_TokenNotWhitelisted.selector);
    grateful.addVault(newToken, address(newVault));
  }

  function test_revertIfAddVaultInvalidVaultAddress() public {
    // Deploy and whitelist a new token
    address newToken = address(new ERC20Mock());
    vm.prank(owner);
    grateful.addToken(newToken);

    // Attempt to add a vault with an invalid address and expect a revert
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_InvalidAddress.selector);
    grateful.addVault(newToken, address(0));
  }

  function test_RemoveVault() public {
    // Deploy and whitelist a new token
    address newToken = address(new ERC20Mock());
    vm.prank(owner);
    grateful.addToken(newToken);

    // Deploy a new AaveV3Vault and add it
    AaveV3Vault newVault = new AaveV3Vault(
      ERC20(newToken),
      ERC20(address(0)), // Replace with appropriate aToken mock if needed
      IPool(address(0)), // Replace with appropriate PoolMock if needed
      owner,
      IRewardsController(address(0)), // Replace with appropriate RewardsControllerMock if needed
      address(grateful)
    );
    vm.prank(owner);
    grateful.addVault(newToken, address(newVault));

    // Act: Remove the vault
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.VaultRemoved(newToken, address(newVault));
    grateful.removeVault(newToken);

    // Assert: Verify that the vault was removed
    assertEq(address(grateful.vaults(newToken)), address(0), "Vault was not removed correctly");
  }

  function test_revertIfRemoveVaultTokenNotWhitelisted() public {
    // Deploy a new token without whitelisting
    address newToken = address(new ERC20Mock());

    // Attempt to remove a vault for a non-whitelisted token
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_TokenNotWhitelisted.selector);
    grateful.removeVault(newToken);
  }

  function test_revertIfRemoveVaultVaultNotSet() public {
    // Deploy and whitelist a new token
    address newToken = address(new ERC20Mock());
    vm.prank(owner);
    grateful.addToken(newToken);

    // Attempt to remove a vault that hasn't been added
    vm.prank(owner);
    vm.expectRevert(IGrateful.Grateful_TokenOrVaultNotFound.selector);
    grateful.removeVault(newToken);
  }
}
