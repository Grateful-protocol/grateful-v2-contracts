// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from '@aave/core-v3/contracts/interfaces/IPool.sol';
import {Grateful} from 'contracts/Grateful.sol';
import {Script} from 'forge-std/Script.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';

contract Deploy is Script {
  struct DeploymentParams {
    address[] tokens;
    IPool aavePool;
  }

  /// @notice Deployment parameters for each chain
  mapping(uint256 _chainId => DeploymentParams _params) internal _deploymentParams;

  function setUp() public {
    address[] memory _tokens = new address[](1);
    _tokens[0] = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Mainnet
    _deploymentParams[1] = DeploymentParams(_tokens, IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2));

    // Sepolia
    _deploymentParams[11_155_111] = DeploymentParams(_tokens, IPool(0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951));
  }

  function run() public {
    DeploymentParams memory _params = _deploymentParams[block.chainid];

    vm.startBroadcast();
    new Grateful(_params.tokens, _params.aavePool);
    vm.stopBroadcast();
  }
}
