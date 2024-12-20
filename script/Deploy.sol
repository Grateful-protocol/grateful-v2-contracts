// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Grateful} from "contracts/Grateful.sol";
import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";
import {Script} from "forge-std/Script.sol";

import {console} from "forge-std/console.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract Deploy is Script {
  /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

  // Mainnets
  uint256 public constant CHAIN_ETHEREUM = 1;
  uint256 public constant CHAIN_OPTIMISM = 10;
  uint256 public constant CHAIN_POLYGON = 137;
  uint256 public constant CHAIN_BASE = 8453;
  uint256 public constant CHAIN_ARBITRUM = 42_161;
  uint256 public constant CHAIN_BNB = 56;

  // Testnets
  uint256 public constant CHAIN_OPTIMISM_SEPOLIA = 11_155_420;
  uint256 public constant CHAIN_ARBITRUM_SEPOLIA = 421_614;

  address public constant GRATEFUL_MULTISIG = 0xbC4d66e4FA462d4deeb77495E7Aa51Bb8034710b;
  address public constant DEV_ADDRESS = 0xe84DbC4EE14b0360B7bF87c7d30Cd0604E0e1E0F;

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
    address owner;
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
    if (chainId == CHAIN_ETHEREUM) {
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
        owner: DEV_ADDRESS,
        aavePool: IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2),
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else if (chainId == CHAIN_OPTIMISM) {
      address[] memory _tokens = new address[](3);
      _tokens[0] = address(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85); // USDC
      _tokens[1] = address(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58); // USDT
      _tokens[2] = address(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); // DAI

      VaultDeploymentParams[] memory _vaults = new VaultDeploymentParams[](3);

      _vaults[0] = VaultDeploymentParams({
        token: address(0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85), // USDC
        aToken: address(0x38d693cE1dF5AaDF7bC62595A37D667aD57922e5), // aUSDC
        rewardsController: address(0x929EC64c34a17401F460460D4B9390518E5B473e) // Rewards Controller
      });

      _vaults[1] = VaultDeploymentParams({
        token: address(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58), // USDT
        aToken: address(0x6ab707Aca953eDAeFBc4fD23bA73294241490620), // aUSDT
        rewardsController: address(0x929EC64c34a17401F460460D4B9390518E5B473e) // Rewards Controller
      });

      _vaults[2] = VaultDeploymentParams({
        token: address(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1), // DAI
        aToken: address(0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE), // aDAI
        rewardsController: address(0x929EC64c34a17401F460460D4B9390518E5B473e) // Rewards Controller
      });

      params = DeploymentParams({
        tokens: _tokens,
        owner: DEV_ADDRESS,
        aavePool: IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD),
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else if (chainId == CHAIN_POLYGON) {
      address[] memory _tokens = new address[](3);
      _tokens[0] = address(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359); // USDC
      _tokens[1] = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F); // USDT
      _tokens[2] = address(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063); // DAI

      VaultDeploymentParams[] memory _vaults = new VaultDeploymentParams[](3);

      _vaults[0] = VaultDeploymentParams({
        token: address(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359), // USDC
        aToken: address(0xA4D94019934D8333Ef880ABFFbF2FDd611C762BD), // aUSDC
        rewardsController: address(0x929EC64c34a17401F460460D4B9390518E5B473e) // Rewards Controller
      });

      _vaults[1] = VaultDeploymentParams({
        token: address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F), // USDT
        aToken: address(0x6ab707Aca953eDAeFBc4fD23bA73294241490620), // aUSDT
        rewardsController: address(0x929EC64c34a17401F460460D4B9390518E5B473e) // Rewards Controller
      });

      _vaults[2] = VaultDeploymentParams({
        token: address(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063), // DAI
        aToken: address(0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE), // aDAI
        rewardsController: address(0x929EC64c34a17401F460460D4B9390518E5B473e) // Rewards Controller
      });

      params = DeploymentParams({
        tokens: _tokens,
        owner: DEV_ADDRESS,
        aavePool: IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD),
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else if (chainId == CHAIN_ARBITRUM) {
      address[] memory _tokens = new address[](3);
      _tokens[0] = address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831); // USDC
      _tokens[1] = address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9); // USDT
      _tokens[2] = address(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); // DAI

      VaultDeploymentParams[] memory _vaults = new VaultDeploymentParams[](3);

      _vaults[0] = VaultDeploymentParams({
        token: address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831), // USDC
        aToken: address(0x724dc807b04555b71ed48a6896b6F41593b8C637), // aUSDC
        rewardsController: address(0x929EC64c34a17401F460460D4B9390518E5B473e) // Rewards Controller
      });

      _vaults[1] = VaultDeploymentParams({
        token: address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9), // USDT
        aToken: address(0x6ab707Aca953eDAeFBc4fD23bA73294241490620), // aUSDT
        rewardsController: address(0x929EC64c34a17401F460460D4B9390518E5B473e) // Rewards Controller
      });

      _vaults[2] = VaultDeploymentParams({
        token: address(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1), // DAI
        aToken: address(0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE), // aDAI
        rewardsController: address(0x929EC64c34a17401F460460D4B9390518E5B473e) // Rewards Controller
      });

      params = DeploymentParams({
        tokens: _tokens,
        owner: DEV_ADDRESS,
        aavePool: IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD),
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else if (chainId == CHAIN_BNB) {
      address[] memory _tokens = new address[](3);
      _tokens[0] = address(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d); // USDC
      _tokens[1] = address(0x55d398326f99059fF775485246999027B3197955); // USDT
      _tokens[2] = address(0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3); // DAI

      VaultDeploymentParams[] memory _vaults = new VaultDeploymentParams[](2);

      _vaults[0] = VaultDeploymentParams({
        token: address(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d), // USDC
        aToken: address(0x00901a076785e0906d1028c7d6372d247bec7d61), // aUSDC
        rewardsController: address(0xC206C2764A9dBF27d599613b8F9A63ACd1160ab4) // Rewards Controller
      });

      _vaults[1] = VaultDeploymentParams({
        token: address(0x55d398326f99059fF775485246999027B3197955), // USDT
        aToken: address(0xa9251ca9DE909CB71783723713B21E4233fbf1B1), // aUSDT
        rewardsController: address(0xC206C2764A9dBF27d599613b8F9A63ACd1160ab4) // Rewards Controller
      });

      params = DeploymentParams({
        tokens: _tokens,
        owner: DEV_ADDRESS,
        aavePool: IPool(0x6807dc923806fE8Fd134338EABCA509979a7e0cB),
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else if (chainId == CHAIN_BASE) {
      address[] memory _tokens = new address[](3);
      _tokens[0] = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // USDC
      _tokens[1] = address(0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2); // USDT
      _tokens[2] = address(0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb); // DAI

      VaultDeploymentParams[] memory _vaults = new VaultDeploymentParams[](1);

      _vaults[0] = VaultDeploymentParams({
        token: address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913), // USDC
        aToken: address(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB), // aUSDC
        rewardsController: address(0xf9cc4F0D883F1a1eb2c253bdb46c254Ca51E1F44) // Rewards Controller
      });

      params = DeploymentParams({
        tokens: _tokens,
        owner: DEV_ADDRESS,
        aavePool: IPool(0xA238Dd80C259a72e81d7e4664a9801593F98d1c5),
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else if (chainId == CHAIN_OPTIMISM_SEPOLIA) {
      address[] memory _tokens = new address[](1);
      _tokens[0] = address(0x5fd84259d66Cd46123540766Be93DFE6D43130D7);

      VaultDeploymentParams[] memory _vaults = new VaultDeploymentParams[](1);
      _vaults[0] = VaultDeploymentParams({
        token: address(0x5fd84259d66Cd46123540766Be93DFE6D43130D7),
        aToken: address(0xa818F1B57c201E092C4A2017A91815034326Efd1),
        rewardsController: address(0xaD4F91D26254B6B0C6346b390dDA2991FDE2F20d)
      });

      params = DeploymentParams({
        tokens: _tokens,
        owner: DEV_ADDRESS,
        aavePool: IPool(0xb50201558B00496A145fE76f7424749556E326D8),
        initialFee: 0.01 ether, // 1%
        initialPerformanceFee: 0.05 ether, // 5%
        vaults: _vaults
      });
    } else if (chainId == CHAIN_ARBITRUM_SEPOLIA) {
      address[] memory _tokens = new address[](1);
      _tokens[0] = address(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d); // usdc

      VaultDeploymentParams[] memory _vaults = new VaultDeploymentParams[](1);
      _vaults[0] = VaultDeploymentParams({
        token: address(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d),
        aToken: address(0x460b97BD498E1157530AEb3086301d5225b91216),
        rewardsController: address(0x3A203B14CF8749a1e3b7314c6c49004B77Ee667A)
      });

      params = DeploymentParams({
        tokens: _tokens,
        owner: DEV_ADDRESS,
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

    grateful =
      new Grateful(_params.tokens, _params.aavePool, _params.initialFee, _params.initialPerformanceFee, _params.owner);

    // Deploy vaults and add them to Grateful
    uint256 vaultsLength = _params.vaults.length;
    for (uint256 i = 0; i < vaultsLength; i++) {
      VaultDeploymentParams memory vaultParams = _params.vaults[i];

      // Deploy the vault
      AaveV3Vault vault = new AaveV3Vault(
        ERC20(vaultParams.token),
        ERC20(vaultParams.aToken),
        _params.aavePool,
        GRATEFUL_MULTISIG,
        IRewardsController(vaultParams.rewardsController),
        address(grateful) // newOwner
      );

      // Add the vault to Grateful
      grateful.addVault(vaultParams.token, address(vault));

      vaults[vaultParams.token] = vault;
    }

    grateful.transferOwnership(GRATEFUL_MULTISIG);

    if (!vm.envBool("TESTING")) {
      vm.stopBroadcast();
    }
  }
}
