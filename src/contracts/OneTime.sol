// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IGrateful} from "interfaces/IGrateful.sol";

contract OneTime {
  constructor(
    IGrateful _grateful,
    IERC20 _token,
    address _merchant,
    uint256 _amount,
    uint256 _paymentId,
    address[] memory _recipients,
    uint256[] memory _percentages
  ) {
    _token.approve(address(_grateful), _amount);
    _grateful.receiveOneTimePayment(_merchant, address(_token), _paymentId, _amount, _recipients, _percentages);
  }
}
