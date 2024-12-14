// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ATokenVault, IPoolAddressesProvider} from "aave-vault/ATokenVault.sol";

contract AaveV3VaultFee is ATokenVault {
  constructor(
    address asset_,
    uint256 fee_,
    IPoolAddressesProvider poolAddressesProvider_,
    address newOwner
  ) ATokenVault(asset_, 0, poolAddressesProvider_) {
    // TODO: Stuff here, or add initializer?
  }

  function deposit(uint256 assets, address receiver) public override onlyOwner returns (uint256 shares) {
    return super.deposit(assets, receiver);
  }

  function mint(uint256 shares, address receiver) public override onlyOwner returns (uint256 assets) {
    return super.mint(shares, receiver);
  }

  function withdraw(
    uint256 assets,
    address receiver,
    address owner_
  ) public override onlyOwner returns (uint256 shares) {
    return super.withdraw(assets, receiver, owner_);
  }

  function redeem(uint256 shares, address receiver, address owner_) public override onlyOwner returns (uint256 assets) {
    return super.redeem(shares, receiver, owner_);
  }
}
