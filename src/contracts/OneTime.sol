// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IGrateful} from "interfaces/IGrateful.sol";

contract OneTime {
  IGrateful immutable grateful;

  constructor(
    IGrateful _grateful,
    address[] memory _tokens,
    address _merchant,
    uint256 _amount,
    uint256 _paymentId,
    address[] memory _recipients,
    uint256[] memory _percentages
  ) {
    grateful = _grateful;

    for (uint256 i = 0; i < _tokens.length; i++) {
      IERC20 token = IERC20(_tokens[i]);
      if (token.balanceOf(address(this)) >= _amount) {
        token.approve(address(_grateful), _amount);
        _grateful.receiveOneTimePayment(_merchant, address(token), _paymentId, _amount, _recipients, _percentages);
      }
    }
  }

  function rescueFunds(address _token, address _receiver, uint256 _amount) external {
    if (msg.sender != grateful.owner()) {
      revert Ownable.OwnableUnauthorizedAccount(msg.sender);
    }

    IERC20(_token).transfer(_receiver, _amount);
  }
}
