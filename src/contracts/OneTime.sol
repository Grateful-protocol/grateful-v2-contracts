// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {console} from "forge-std/console.sol";
import {IGrateful} from "interfaces/IGrateful.sol";

contract OneTime {
  using SafeERC20 for IERC20;

  IGrateful immutable grateful;

  constructor(
    IGrateful _grateful,
    address[] memory _tokens,
    address _merchant,
    uint256 _amount,
    uint256 _paymentId,
    bool _yieldFunds
  ) {
    grateful = _grateful;

    for (uint256 i = 0; i < _tokens.length; i++) {
      IERC20 token = IERC20(_tokens[i]);
      if (token.balanceOf(address(this)) >= _amount) {
        token.safeIncreaseAllowance(address(_grateful), _amount);
        _grateful.receiveOneTimePayment(_merchant, address(token), _paymentId, _amount, _yieldFunds);
      }
    }
  }

  function rescueFunds(IERC20 _token, address _receiver, uint256 _amount) external {
    if (msg.sender != grateful.owner()) {
      revert Ownable.OwnableUnauthorizedAccount(msg.sender);
    }

    IERC20(_token).safeTransfer(_receiver, _amount);
  }
}
