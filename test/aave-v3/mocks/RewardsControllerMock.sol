// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.26;

import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract RewardsControllerMock is IRewardsController {
  uint256 public constant CLAIM_AMOUNT = 10 ** 18;
  ERC20Mock public aave;

  constructor(
    address _aave
  ) {
    aave = ERC20Mock(_aave);
  }

  function claimAllRewards(
    address[] calldata,
    address to
  ) external override returns (address[] memory rewardsList, uint256[] memory claimedAmounts) {
    aave.mint(to, CLAIM_AMOUNT);

    rewardsList = new address[](1);
    rewardsList[0] = address(aave);

    claimedAmounts = new uint256[](1);
    claimedAmounts[0] = CLAIM_AMOUNT;
  }
}
