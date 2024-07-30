// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Ownable2Step} from '@openzeppelin/contracts/access/Ownable2Step.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {IGrateful} from 'interfaces/IGrateful.sol';

contract Grateful is IGrateful, Ownable2Step {
  // @inheritdoc IGrateful
  IPool public aavePool;

  // inheritdoc IGrateful
  mapping(address => bool) public tokensWhitelisted;

  // @inheritdoc IGrateful
  mapping(address => bool) public yieldingFunds;

  constructor(address[] memory _tokens, IPool _aavePool) Ownable(msg.sender) {
    aavePool = _aavePool;
    for (uint256 i = 0; i < _tokens.length; i++) {
      tokensWhitelisted[_tokens[i]] = true;
      IERC20(_tokens[i]).approve(address(_aavePool), type(uint256).max);
    }
  }

  // @inheritdoc IGrateful
  function pay(address _merchant, address _token, uint256 _amount) external {
    if (!tokensWhitelisted[_token]) {
      revert Grateful_TokenNotWhitelisted();
    }

    if (yieldingFunds[_merchant]) {
      IERC20(_token).transferFrom(msg.sender, address(this), _amount);
      aavePool.supply(_token, _amount, address(this), 0);
    } else {
      if (!IERC20(_token).transferFrom(msg.sender, _merchant, _amount)) {
        revert Grateful_TransferFailed();
      }
    }
  }

  // @inheritdoc IGrateful
  function switchYieldingFunds() external {
    yieldingFunds[msg.sender] = !yieldingFunds[msg.sender];
  }
}
