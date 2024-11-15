// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Grateful} from "contracts/Grateful.sol";
import {TestToken} from "contracts/external/TestToken.sol";
import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";
import {Script} from "forge-std/Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract Deploy is Script {
  struct VaultDeploymentParams {
    address token;
    address aToken;
    address rewardsController;
  }

  struct DeploymentParams {
    address[] tokens;
    IPool aavePool;
    uint256 initialFee;
    VaultDeploymentParams[] vaults;
  }

  error UnsupportedChain();

  function getDeploymentParams(
    uint256 chainId
  ) internal pure returns (DeploymentParams memory params) {
    if (chainId == 1) {
      // Mainnet
      address[] memory _tokens = new address[](1);
      _tokens[0] = address(0x5fd84259d66Cd46123540766Be93DFE6D43130D7);

      VaultDeploymentParams[] memory _vaults;

      params = DeploymentParams({
        tokens: _tokens,
        aavePool: IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2),
        initialFee: 100,
        vaults: _vaults
      });
    } else if (chainId == 10) {
      // Optimism
      address[] memory _tokens = new address[](2);
      _tokens[0] = address(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
      _tokens[1] = address(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

      VaultDeploymentParams[] memory _vaults;

      params = DeploymentParams({
        tokens: _tokens,
        aavePool: IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD),
        initialFee: 100,
        vaults: _vaults
      });
    } else if (chainId == 11_155_420) {
      // Optimism Sepolia
      address[] memory _tokens = new address[](1);
      _tokens[0] = address(0x5fd84259d66Cd46123540766Be93DFE6D43130D7);

      VaultDeploymentParams[] memory _vaults = new VaultDeploymentParams[](1);
      _vaults[0] = VaultDeploymentParams({
        token: address(0x5fd84259d66Cd46123540766Be93DFE6D43130D7), // Token address
        aToken: address(0xa818F1B57c201E092C4A2017A91815034326Efd1), // aToken address
        rewardsController: address(0xaD4F91D26254B6B0C6346b390dDA2991FDE2F20d) // Rewards Controller address
      });

      params = DeploymentParams({
        tokens: _tokens,
        aavePool: IPool(0xb50201558B00496A145fE76f7424749556E326D8),
        initialFee: 100,
        vaults: _vaults
      });
    } else if (chainId == 421_614) {
      // Arbitrum Sepolia
      address[] memory _tokens = new address[](1);
      _tokens[0] = address(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d); // usdc

      VaultDeploymentParams[] memory _vaults = new VaultDeploymentParams[](1);
      _vaults[0] = VaultDeploymentParams({
        token: address(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d), // Token address
        aToken: address(0x460b97BD498E1157530AEb3086301d5225b91216), // aToken address
        rewardsController: address(0x3A203B14CF8749a1e3b7314c6c49004B77Ee667A) // Rewards Controller address
      });

      params = DeploymentParams({
        tokens: _tokens,
        aavePool: IPool(0xBfC91D59fdAA134A4ED45f7B584cAf96D7792Eff),
        initialFee: 100,
        vaults: _vaults
      });
    } else {
      revert UnsupportedChain();
    }
  }

  function run() public {
    DeploymentParams memory _params = getDeploymentParams(block.chainid);

    vm.startBroadcast();

    // Deploy Grateful contract
    Grateful _grateful = new Grateful(_params.tokens, _params.aavePool, _params.initialFee);

    // Deploy vaults and add them to Grateful
    uint256 vaultsLength = _params.vaults.length;
    for (uint256 i = 0; i < vaultsLength; i++) {
      VaultDeploymentParams memory vaultParams = _params.vaults[i];

      // Deploy the vault
      AaveV3Vault vault = new AaveV3Vault(
        ERC20(vaultParams.token),
        ERC20(vaultParams.aToken),
        _params.aavePool,
        _grateful.owner(), // rewardRecipient_ (set to desired address)
        IRewardsController(vaultParams.rewardsController),
        address(_grateful) // newOwner
      );

      // Add the vault to Grateful
      _grateful.addVault(vaultParams.token, address(vault));
    }

    // Deploy TestToken (if needed)
    TestToken _testToken = new TestToken("Test Token", "TEST", 18);

    // Add TestToken to Grateful (if needed)
    _grateful.addToken(address(_testToken));

    vm.stopBroadcast();
  }
}
