// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Grateful, IGrateful} from "contracts/Grateful.sol";
import {Test} from "forge-std/Test.sol";

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {AaveV3ERC4626, IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract IntegrationBase is Test {
  uint256 internal constant _FORK_BLOCK = 18_920_905;

  string internal _initialGreeting = "hola";
  address internal _user = makeAddr("user");
  address internal _merchant = makeAddr("merchant");
  address internal _owner = makeAddr("owner");
  address internal _daiWhale = 0xbf702ea18BB1AB2A710394993a576eC61476cCf3;
  address[] internal _tokens;
  IERC20 internal _dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address _aDai = 0x018008bfb33d285247A21d44E50697654f754e63;
  address _rewardsController = 0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;
  IPool internal _aavePool = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
  IGrateful internal _grateful;
  AaveV3ERC4626 internal _vault;
  uint256 internal _amount = 1e25;

  function setUp() public {
    vm.startPrank(_owner);
    vm.createSelectFork(vm.rpcUrl("mainnet"), _FORK_BLOCK);
    _vault = new AaveV3ERC4626(
      ERC20(address(_dai)), ERC20(_aDai), _aavePool, address(0), IRewardsController(_rewardsController)
    );
    vm.label(address(_vault), "Vault");
    _tokens = new address[](1);
    _tokens[0] = address(_dai);
    _grateful = new Grateful(_tokens, _aavePool);
    vm.label(address(_grateful), "Grateful");
    _grateful.addVault(address(_dai), address(_vault));
    vm.stopPrank();
  }
}
