// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IGrateful} from "interfaces/IGrateful.sol";
import {AaveV3ERC4626, IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract Grateful is IGrateful, Ownable2Step {
  IPool public aavePool;
  mapping(address => bool) public tokensWhitelisted;
  mapping(address => bool) public yieldingFunds;
  mapping(address => AaveV3ERC4626) public vaults;
  mapping(address => mapping(address => uint256)) public shares;

  modifier onlyWhenTokenWhitelisted(address _token) {
    if (!tokensWhitelisted[_token]) {
      revert Grateful_TokenNotWhitelisted();
    }
    _;
  }

  constructor(address[] memory _tokens, IPool _aavePool) Ownable(msg.sender) {
    aavePool = _aavePool;
    for (uint256 i = 0; i < _tokens.length; i++) {
      tokensWhitelisted[_tokens[i]] = true;
      IERC20(_tokens[i]).approve(address(_aavePool), type(uint256).max);
    }
  }

  // @inheritdoc IGrateful
  function addVault(address _token, address _vault) external onlyWhenTokenWhitelisted(_token) onlyOwner {
    vaults[_token] = AaveV3ERC4626(_vault);
  }

  // @inheritdoc IGrateful
  function pay(address _merchant, address _token, uint256 _amount) external onlyWhenTokenWhitelisted(_token) {
    if (yieldingFunds[_merchant]) {
      AaveV3ERC4626 vault = vaults[_token];
      if (address(vault) == address(0)) {
        revert Grateful_VaultNotSet();
      }
      IERC20(_token).transferFrom(msg.sender, address(this), _amount);
      uint256 _shares = vault.deposit(_amount, address(this));
      shares[_merchant][_token] += _shares;
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
