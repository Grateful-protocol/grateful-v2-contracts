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

contract UnitGrateful is Test {
  using SafeERC20 for IERC20;

  /*//////////////////////////////////////////////////////////////
                             CONTRACTS & VARIABLES
    //////////////////////////////////////////////////////////////*/

  // Main contracts
  Grateful public grateful;
  ERC20Mock public token;
  ERC20Mock public aToken;
  ERC20Mock public aave;
  PoolMock public aavePool;
  AaveV3Vault public aaveVault;
  RewardsControllerMock public rewardsController;

  // Addresses
  address public owner = makeAddr("owner");
  address public merchant = makeAddr("merchant");
  address public user = makeAddr("user");

  // Token and fee parameters
  address[] public tokens;
  uint256 public initialFee = 0.01 ether; // 1%
  uint256 public initialPerformanceFee = 0.05 ether; // 5%
  uint256 public tokenInitialSupply = 1_000_000 * 1e18; // 1 million tokens

  function setUp() public {
    /*//////////////////////////////////////////////////////////////
                               DEPLOY MOCK TOKEN
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
                            DEPLOY AAVE V3 VAULT
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
                                 TEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////
                                 CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  // Test the constructor with valid arguments
  function test_ConstructorWhenPassingValidArgs() public {
    // Deploy the Grateful contract
    grateful = new Grateful(tokens, IPool(address(aavePool)), initialFee, initialPerformanceFee, owner);

    // Check that the Grateful contract is deployed correctly
    assertEq(grateful.owner(), owner);
    assertEq(address(grateful.aavePool()), address(aavePool));
    assertEq(grateful.fee(), initialFee);
    assertEq(grateful.performanceFee(), initialPerformanceFee);
    assertEq(grateful.tokensWhitelisted(address(token)), true);
  }

  // Test the constructor with an invalid pool address
  function test_ConstructorWhenPassingInvalidPoolAddress() public {
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_InvalidAddress.selector));
    grateful = new Grateful(tokens, IPool(address(0)), initialFee, initialPerformanceFee, owner);
  }

  // Test the constructor with an invalid max fee
  function test_ConstructorWhenPassingInvalidMaxFee(
    uint256 invalidFee
  ) public {
    vm.assume(invalidFee > grateful.MAX_FEE());
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_FeeRateTooHigh.selector));
    grateful = new Grateful(tokens, IPool(address(aavePool)), invalidFee, initialPerformanceFee, owner);
  }

  // Test the constructor with an invalid max performance fee
  function test_ConstructorWhenPassingInvalidMaxPerformanceFee(
    uint256 invalidPerformanceFee
  ) public {
    vm.assume(invalidPerformanceFee > grateful.MAX_PERFORMANCE_FEE());
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_FeeRateTooHigh.selector));
    grateful = new Grateful(tokens, IPool(address(aavePool)), initialFee, invalidPerformanceFee, owner);
  }

  /*//////////////////////////////////////////////////////////////
                             TOKEN WHITELISTING
    //////////////////////////////////////////////////////////////*/

  // Test adding a token
  function test_AddToken() public {
    address tokenToAdd = address(new ERC20Mock());
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.TokenAdded(tokenToAdd);
    grateful.addToken(tokenToAdd);
    assertTrue(grateful.tokensWhitelisted(tokenToAdd));
  }

  // Test removing a token
  function test_RemoveToken() public {
    address tokenToRemove = address(new ERC20Mock());
    vm.prank(owner);
    grateful.addToken(tokenToRemove);
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.TokenRemoved(tokenToRemove);
    grateful.removeToken(tokenToRemove);
    assertFalse(grateful.tokensWhitelisted(tokenToRemove));
  }

  // Test adding a token with an invalid address
  function test_AddTokenWithInvalidAddress() public {
    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_InvalidAddress.selector));
    grateful.addToken(address(0));
  }

  // Test removing a token that is not whitelisted
  function test_RemoveTokenNotWhitelisted() public {
    address tokenToRemove = address(new ERC20Mock());
    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_TokenOrVaultNotFound.selector));
    grateful.removeToken(tokenToRemove);
  }

  /*//////////////////////////////////////////////////////////////
                                 VAULTS
    //////////////////////////////////////////////////////////////*/

  // Test adding a vault
  function test_AddVault() public {
    address newToken = address(new ERC20Mock());
    AaveV3Vault newVault = new AaveV3Vault(
      ERC20(newToken),
      ERC20(address(aToken)),
      IPool(address(aavePool)),
      owner,
      IRewardsController(address(rewardsController)),
      address(grateful)
    );

    vm.prank(owner);
    grateful.addToken(newToken);

    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.VaultAdded(newToken, address(newVault));
    grateful.addVault(newToken, address(newVault));

    assertEq(address(grateful.vaults(newToken)), address(newVault));
  }

  // Test adding a vault when token is not whitelisted
  function test_AddVaultTokenNotWhitelisted() public {
    address newToken = address(new ERC20Mock());
    AaveV3Vault newVault = new AaveV3Vault(
      ERC20(newToken),
      ERC20(address(aToken)),
      IPool(address(aavePool)),
      owner,
      IRewardsController(address(rewardsController)),
      address(grateful)
    );

    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_TokenNotWhitelisted.selector));
    grateful.addVault(newToken, address(newVault));
  }

  // Test removing a vault
  function test_RemoveVault() public {
    address newToken = address(new ERC20Mock());
    AaveV3Vault newVault = new AaveV3Vault(
      ERC20(newToken),
      ERC20(address(aToken)),
      IPool(address(aavePool)),
      owner,
      IRewardsController(address(rewardsController)),
      address(grateful)
    );

    vm.prank(owner);
    grateful.addToken(newToken);
    vm.prank(owner);
    grateful.addVault(newToken, address(newVault));

    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit IGrateful.VaultRemoved(newToken, address(newVault));
    grateful.removeVault(newToken);

    assertEq(address(grateful.vaults(newToken)), address(0));
  }

  // Test adding a vault with an invalid address
  function test_AddVaultWithInvalidAddress() public {
    address newToken = address(new ERC20Mock());
    vm.prank(owner);
    grateful.addToken(newToken);

    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_InvalidAddress.selector));
    grateful.addVault(newToken, address(0));
  }

  // Test removing a vault that is not added
  function test_RemoveVaultNotAdded() public {
    address newToken = address(new ERC20Mock());
    vm.prank(owner);
    grateful.addToken(newToken);

    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_TokenOrVaultNotFound.selector));
    grateful.removeVault(newToken);
  }

  /*//////////////////////////////////////////////////////////////
                                 FEES
    //////////////////////////////////////////////////////////////*/

  // Test setting the fee
  function test_SetFee() public {
    uint256 newFee = grateful.MAX_FEE() - 1;
    vm.prank(owner);
    grateful.setFee(newFee);
    assertEq(grateful.fee(), newFee);
  }

  // Test setting a custom fee
  function test_SetCustomFee() public {
    uint256 customFee = grateful.MAX_FEE() - 1;
    vm.prank(owner);
    grateful.setCustomFee(customFee, merchant);

    (bool isSet, uint256 fee) = grateful.customFees(merchant);
    assertEq(isSet, true);
    assertEq(fee, customFee);
  }

  // Test setting the fee and reverting when the fee is too high
  function test_SetFeeRevertsWhenFeeTooHigh() public {
    uint256 invalidFee = grateful.MAX_FEE() + 1;
    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_FeeRateTooHigh.selector));
    grateful.setFee(invalidFee);
  }

  // Test setting a custom fee and reverting when the fee is too high
  function test_SetCustomFeeRevertsWhenFeeTooHigh() public {
    uint256 invalidCustomFee = grateful.MAX_FEE() + 1;
    vm.prank(owner);
    vm.expectRevert(abi.encodeWithSelector(IGrateful.Grateful_FeeRateTooHigh.selector));
    grateful.setCustomFee(invalidCustomFee, merchant);
  }
}
