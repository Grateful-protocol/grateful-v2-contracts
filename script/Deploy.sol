// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Grateful} from "contracts/Grateful.sol";
import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";
import {Script} from "forge-std/Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

contract Deploy is Script {
  struct DeploymentParams {
    address[] tokens;
    IPool aavePool;
  }

  /// @notice Deployment parameters for each chain
  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  function setUp() public {
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(0x5fd84259d66Cd46123540766Be93DFE6D43130D7);

    // Mainnet
    _deploymentParams[1] = DeploymentParams(_tokens, IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2));

    // Optimism Sepolia
    _deploymentParams[11_155_420] = DeploymentParams(_tokens, IPool(0xb50201558B00496A145fE76f7424749556E326D8));
  }

  function run() public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];

    vm.startBroadcast();
    Grateful _grateful = new Grateful(_params.tokens, _params.aavePool);
    AaveV3Vault _vault = new AaveV3Vault(
      ERC20(_params.tokens[0]),
      ERC20(0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97),
      _params.aavePool,
      address(0),
      IRewardsController(0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb),
      address(_grateful)
    );
    _grateful.addVault(_params.tokens[0], address(_vault));
    vm.stopBroadcast();
  }
}
