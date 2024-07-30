// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Grateful, IGrateful} from 'contracts/Grateful.sol';
import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';

contract IntegrationBase is Test {
  uint256 internal constant _FORK_BLOCK = 18_920_905;

  string internal _initialGreeting = 'hola';
  address internal _user = makeAddr('user');
  address internal _merchant = makeAddr('merchant');
  address internal _owner = makeAddr('owner');
  address internal _daiWhale = 0xbf702ea18BB1AB2A710394993a576eC61476cCf3;
  address[] internal _tokens;
  IERC20 internal _dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  IPool internal _aavePool = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
  IGrateful internal _grateful;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), _FORK_BLOCK);
    vm.prank(_owner);
    _tokens = new address[](1);
    _tokens[0] = address(_dai);
    _grateful = new Grateful(_tokens, _aavePool);
  }
}
