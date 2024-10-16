// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Grateful, IGrateful} from "contracts/Grateful.sol";
import {Test} from "forge-std/Test.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract IntegrationBase is Test {
  uint256 internal constant _FORK_BLOCK = 18_920_905;

  string internal _initialGreeting = "hola";
  address internal _user = makeAddr("user");
  address internal _merchant = makeAddr("merchant");
  address internal _owner = makeAddr("owner");
  address internal _gratefulAutomation = makeAddr("gratefulAutomation");
  address internal _payer = 0x555d73f2002A457211d690313f942B065eAD1FFF;
  address[] internal _tokens;
  IERC20 internal _usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  IERC20 internal _usdt = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address internal _aUsdc = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
  address internal _rewardsController = 0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;
  IPool internal _aavePool = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
  IGrateful internal _grateful;
  AaveV3Vault internal _vault;
  uint256 internal _amount = 10 * 10 ** 6; // 10 DAI
  uint256 internal _subscriptionPlanId = 0;
  uint256 internal _fee = 100;

  function setUp() public {
    vm.startPrank(_owner);
    vm.createSelectFork(vm.rpcUrl("mainnet"), _FORK_BLOCK);
    vm.label(address(_vault), "Vault");
    _tokens = new address[](2);
    _tokens[0] = address(_usdc);
    _tokens[1] = address(_usdt);
    _grateful = new Grateful(_tokens, _aavePool, _fee);
    _vault = new AaveV3Vault(
      ERC20(address(_usdc)),
      ERC20(_aUsdc),
      _aavePool,
      address(0),
      IRewardsController(_rewardsController),
      address(_grateful)
    );
    vm.label(address(_grateful), "Grateful");
    _grateful.addVault(address(_usdc), address(_vault));
    vm.stopPrank();
  }
}
