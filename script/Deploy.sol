// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Grateful} from "contracts/Grateful.sol";

import {TestToken} from "contracts/external/TestToken.sol";
import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";
import {Script} from "forge-std/Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract Deploy is Script {
  struct DeploymentParams {
    address[] tokens;
    IPool aavePool;
    uint256 initialFee;
  }

  /// @notice Deployment parameters for each chain
  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  function setUp() public {
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(0x5fd84259d66Cd46123540766Be93DFE6D43130D7);

    address[] memory _tokensOptimism = new address[](2);
    _tokensOptimism[0] = address(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
    _tokensOptimism[1] = address(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

    address[] memory _tokensOptimismSepolia = new address[](2);
    _tokensOptimismSepolia[0] = address(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    _tokensOptimismSepolia[1] = address(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

    address[] memory _tokensArbitrumSepolia = new address[](1);
    _tokensArbitrumSepolia[0] = address(
      0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d // usdc
    );

    // Mainnet
    _deploymentParams[1] = DeploymentParams(_tokens, IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2), 100);

    // Optimism
    _deploymentParams[10] = DeploymentParams(_tokensOptimism, IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD), 100);

    // Optimism Sepolia
    _deploymentParams[11_155_420] = DeploymentParams(_tokens, IPool(0xb50201558B00496A145fE76f7424749556E326D8), 100);

    // V-Optimism
    _deploymentParams[4924] =
      DeploymentParams(_tokensOptimismSepolia, IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD), 100);

    // Arbitrum
    _deploymentParams[421_614] =
      DeploymentParams(_tokensArbitrumSepolia, IPool(0xBfC91D59fdAA134A4ED45f7B584cAf96D7792Eff), 100);
  }

  function run() public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];

    vm.startBroadcast();
    Grateful _grateful = new Grateful(_params.tokens, _params.aavePool, _params.initialFee);

    // Deploy TestToken
    TestToken _testToken = new TestToken("Test Token", "TEST", 18);

    // Add TestToken to Grateful
    _grateful.addToken(address(_testToken));

    vm.stopBroadcast();
  }
}
