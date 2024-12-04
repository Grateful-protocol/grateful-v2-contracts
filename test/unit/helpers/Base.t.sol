// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// Forge standard library imports for testing
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// OpenZeppelin imports for ERC20 and contract utilities
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Solmate ERC20 import for vault creation
import {ERC20} from "solmate/tokens/ERC20.sol";

// Grateful contract and related interfaces
import {Grateful, IGrateful} from "contracts/Grateful.sol";
import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";

// Mock contracts for testing
import {PoolMock} from "test/aave-v3/mocks/PoolMock.sol";
import {RewardsControllerMock} from "test/aave-v3/mocks/RewardsControllerMock.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

// Aave V3 interfaces
import {IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract UnitBase is Test {
  using SafeERC20 for IERC20;

  /*//////////////////////////////////////////////////////////////
                           CONTRACTS & VARIABLES
    //////////////////////////////////////////////////////////////*/

  // Main contracts
  Grateful internal grateful;
  ERC20Mock internal token;
  ERC20Mock internal aToken;
  ERC20Mock internal aave;
  PoolMock internal aavePool;
  AaveV3Vault internal aaveVault;
  RewardsControllerMock internal rewardsController;

  // Addresses
  address internal owner = address(0x1);
  address internal merchant = address(0x2);
  address internal user = address(0x3);

  // Token and fee parameters
  address[] internal tokens;
  uint256 internal initialFee = 0.01 ether; // 1%
  uint256 internal initialPerformanceFee = 0.05 ether; // 5%
  uint256 internal tokenInitialSupply = 1_000_000 * 1e18; // 1 million tokens

  function setUp() public virtual {
    /*//////////////////////////////////////////////////////////////
                             DEPLOY MOCK TOKENS
        //////////////////////////////////////////////////////////////*/

    // Deploy mock ERC20 tokens
    token = new ERC20Mock();
    aToken = new ERC20Mock();
    aave = new ERC20Mock();

    // Label the token addresses for easier debugging
    vm.label(address(token), "Mock Token");
    vm.label(address(aToken), "Mock AToken");
    vm.label(address(aave), "Mock Aave");

    /*//////////////////////////////////////////////////////////////
                         DEPLOY AAVE MOCK CONTRACTS
        //////////////////////////////////////////////////////////////*/

    // Deploy a mock Aave V3 pool
    aavePool = new PoolMock();

    // Deploy a mock Rewards Controller with its own Aave token
    rewardsController = new RewardsControllerMock(address(aave));

    // Label the Aave pool and rewards controller addresses
    vm.label(address(aavePool), "Aave Pool Mock");
    vm.label(address(rewardsController), "Rewards Controller Mock");

    /*//////////////////////////////////////////////////////////////
                            DEPLOY GRATEFUL CONTRACT
        //////////////////////////////////////////////////////////////*/

    // Prepare the tokens array with the mock token address
    tokens = new address[](1);
    tokens[0] = address(token);

    // Deploy the Grateful contract
    vm.startPrank(owner);
    grateful = new Grateful(tokens, IPool(address(aavePool)), initialFee, initialPerformanceFee, owner);

    // Label the Grateful contract address
    vm.label(address(grateful), "Grateful");

    /*//////////////////////////////////////////////////////////////
                        DEPLOY AND SETUP AAVE V3 VAULT
        //////////////////////////////////////////////////////////////*/

    // Set reserve AToken in the mock pool
    aavePool.setReserveAToken(address(token), address(aToken));

    // Deploy the AaveV3Vault with the token, mock Aave pool, and rewards controller
    aaveVault = new AaveV3Vault(
      ERC20(address(token)),
      ERC20(address(aToken)),
      IPool(address(aavePool)),
      owner,
      IRewardsController(address(rewardsController)),
      address(grateful)
    );

    // Label the AaveV3Vault address
    vm.label(address(aaveVault), "AaveV3Vault");

    /*//////////////////////////////////////////////////////////////
                          SETUP GRATEFUL CONTRACT
        //////////////////////////////////////////////////////////////*/

    // Add the AaveV3Vault to the Grateful contract
    grateful.addVault(address(token), address(aaveVault));

    // Stop acting as owner
    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                              HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  function _deployNewTokenAndVault() internal returns (address newToken, AaveV3Vault newVault) {
    newToken = address(new ERC20Mock());

    // Deploy new AaveV3Vault for the new token
    newVault = new AaveV3Vault(
      ERC20(newToken),
      ERC20(address(aToken)),
      IPool(address(aavePool)),
      owner,
      IRewardsController(address(rewardsController)),
      address(grateful)
    );

    // Set reserve AToken in the mock pool
    aavePool.setReserveAToken(newToken, address(aToken));

    return (newToken, newVault);
  }
}
