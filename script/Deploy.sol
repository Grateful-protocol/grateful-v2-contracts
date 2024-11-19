// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Grateful} from "contracts/Grateful.sol";
import {TestToken} from "contracts/external/TestToken.sol";
import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";
import {Script} from "forge-std/Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract Deploy is Script {
  /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

  uint256 public constant CHAIN_MAINNET = 1;
  uint256 public constant CHAIN_OPTIMISM = 10;
  uint256 public constant CHAIN_OPTIMISM_SEPOLIA = 11_155_420;
  uint256 public constant CHAIN_ARBITRUM_SEPOLIA = 421_614;

  address public constant GRATEFUL_MULTISIG = 0xbC4d66e4FA462d4deeb77495E7Aa51Bb8034710b;

  /*//////////////////////////////////////////////////////////////
                              STRUCTS
    //////////////////////////////////////////////////////////////*/

  struct VaultDeploymentParams {
    address token;
    address aToken;
    address rewardsController;
  }

  struct DeploymentParams {
    address[] tokens;
    IPool aavePool;
    uint256 initialFee;
    uint256 initialPerformanceFee;
    VaultDeploymentParams[] vaults;
  }

  error UnsupportedChain();

  // Public variables to store deployed contracts
  Grateful public grateful;
  mapping(address => AaveV3Vault) public vaults;

  function getDeploymentParams(
    uint256 chainId
  ) internal pure returns (DeploymentParams memory params) {
    if (chainId == CHAIN_MAINNET) {
      // Mainnet
      address[] memory _tokens = new address[](3);
      _tokens[0] = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
      _tokens[1] = address(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT
      _tokens[2] = address(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI

      VaultDeploymentParams[] memory _vaults = new VaultDeploymentParams[](3);

      _vaults[0] = VaultDeploymentParams({
        token: address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), // USDC
        aToken: address(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c), // aUSDC
        rewardsController: address(0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb) // Rewards Controller
      });

      _vaults[1] = VaultDeploymentParams({
        token: address(0xdAC17F958D2ee523a2206206994597C13D831ec7), // USDT
        aToken: address(0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a), // aUSDT
        rewardsController: address(0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb) // Rewards Controller
      });

      _vaults[2] = VaultDeploymentParams({
        token: address(0x6B175474E89094C44Da98b954EedeAC495271d0F), // DAI
        aToken: address(0x018008bfb33d285247A21d44E50697654f754e63), // aDAI
        rewardsController: address(0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb) // Rewards Controller
      });

      params = DeploymentParams({
        tokens: _tokens,
        aavePool: IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2),
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else if (chainId == CHAIN_OPTIMISM) {
      // Optimism
      address[] memory _tokens = new address[](2);
      _tokens[0] = address(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);
      _tokens[1] = address(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

      VaultDeploymentParams[] memory _vaults;

      params = DeploymentParams({
        tokens: _tokens,
        aavePool: IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD),
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else if (chainId == CHAIN_OPTIMISM_SEPOLIA) {
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
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else if (chainId == CHAIN_ARBITRUM_SEPOLIA) {
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
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else {
      revert UnsupportedChain();
    }
  }

  function run() public {
    DeploymentParams memory _params = getDeploymentParams(block.chainid);

    if (!vm.envBool("TESTING")) {
      vm.startBroadcast();
    }
    // Deploy Grateful contract
    grateful = new Grateful(_params.tokens, _params.aavePool, _params.initialFee, _params.initialPerformanceFee);
    grateful.transferOwnership(GRATEFUL_MULTISIG);

    // Deploy vaults and add them to Grateful
    uint256 vaultsLength = _params.vaults.length;
    for (uint256 i = 0; i < vaultsLength; i++) {
      VaultDeploymentParams memory vaultParams = _params.vaults[i];

      // Deploy the vault
      AaveV3Vault vault = new AaveV3Vault(
        ERC20(vaultParams.token),
        ERC20(vaultParams.aToken),
        _params.aavePool,
        grateful.owner(), // rewardRecipient_ (set to desired address)
        IRewardsController(vaultParams.rewardsController),
        address(grateful) // newOwner
      );

      // Add the vault to Grateful
      grateful.addVault(vaultParams.token, address(vault));

      vaults[vaultParams.token] = vault;
    }

    if (!vm.envBool("TESTING")) {
      vm.stopBroadcast();
    }
  }
}
