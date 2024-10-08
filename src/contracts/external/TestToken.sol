// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "solmate/tokens/ERC20.sol";

contract TestToken is ERC20 {
  constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) {}

  function mint(address to, uint256 amount) external {
    _mint(to, amount);
  }
}
