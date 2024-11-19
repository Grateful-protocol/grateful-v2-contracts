// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Grateful, IGrateful} from "contracts/Grateful.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Deploy} from "script/Deploy.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {AaveV3Vault} from "contracts/vaults/AaveV3Vault.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IPool, IRewardsController} from "yield-daddy/aave-v3/AaveV3ERC4626.sol";

interface IERC20Symbol {
  function symbol() external view returns (string memory);
  function decimals() external view returns (uint8);
}

contract IntegrationBase is Test, Deploy {
  using SafeERC20 for IERC20;

  /*//////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////*/

  uint256 internal constant _FEE = 100; // 1% fee
  uint256 internal constant _PAYMENT_SALT = 4; // Salt for computing payment addresses
  bool internal constant _YIELDING_FUNDS = true;
  bool internal constant _NOT_YIELDING_FUNDS = false;

  /*//////////////////////////////////////////////////////////////
                                    ADDRESSES
    //////////////////////////////////////////////////////////////*/

  // EOAs
  address internal _user = makeAddr("user");
  address internal _merchant = makeAddr("merchant");
  address internal _merchant2 = makeAddr("user2");
  address internal _owner = makeAddr("owner");
  address internal _gratefulAutomation = makeAddr("gratefulAutomation");

  // Tokens array
  address[] internal _tokens;

  // Token symbols
  mapping(address => string) internal _tokenSymbols;

  // Amounts per token
  mapping(address => uint256) internal _tokenAmounts;

  // Grateful contract
  IGrateful internal _grateful;

  /*//////////////////////////////////////////////////////////////
                                    SETUP FUNCTION
    //////////////////////////////////////////////////////////////*/

  function setUp() public {
    string memory forkedNetwork = vm.envString("FORKED_NETWORK");
    uint256 forkBlock = vm.envUint("FORK_BLOCK");

    // Use fork block from deployment parameters
    vm.createSelectFork(vm.rpcUrl(forkedNetwork), forkBlock);
    vm.startPrank(_owner);

    // Get deployment parameters
    DeploymentParams memory params = getDeploymentParams(block.chainid);

    // Copy tokens to storage variable _tokens
    uint256 tokensLength = params.tokens.length;
    _tokens = new address[](tokensLength);
    for (uint256 i = 0; i < tokensLength; i++) {
      _tokens[i] = params.tokens[i];
    }

    // Run deployment script
    run();

    // Access the deployed contracts
    _grateful = grateful;

    // Get token symbols and label tokens and vaults
    for (uint256 i = 0; i < tokensLength; i++) {
      address tokenAddr = _tokens[i];
      IERC20Symbol token = IERC20Symbol(tokenAddr);

      string memory symbol = token.symbol();
      _tokenSymbols[tokenAddr] = symbol;

      // Label the token
      vm.label(tokenAddr, symbol);

      // Label the vault
      AaveV3Vault vault = vaults[tokenAddr];
      vm.label(address(vault), string(abi.encodePacked(symbol, " Vault")));

      // Set amount per token (e.g., 10 tokens)
      uint8 decimals = token.decimals();
      uint256 amount = 10 * (10 ** decimals);
      _tokenAmounts[tokenAddr] = amount;
    }

    vm.label(address(_grateful), "Grateful");

    vm.stopPrank();
  }

  /*//////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  function _approveAndPay(address payer, address merchant, address tokenAddr, uint256 amount, bool yieldFunds) internal {
    uint256 paymentId = _grateful.calculateId(payer, merchant, tokenAddr, amount);
    deal(tokenAddr, payer, amount);
    vm.startPrank(payer);
    IERC20 token = IERC20(tokenAddr);
    token.forceApprove(address(_grateful), amount);
    _grateful.pay(merchant, tokenAddr, amount, paymentId, yieldFunds);
    vm.stopPrank();
  }

  function _setupAndExecuteOneTimePayment(
    address payer,
    address merchant,
    address tokenAddr,
    uint256 amount,
    uint256 salt,
    bool yieldFunds
  ) internal returns (uint256 paymentId, address precomputed) {
    deal(tokenAddr, payer, amount);
    paymentId = _grateful.calculateId(payer, merchant, tokenAddr, amount);
    precomputed = address(_grateful.computeOneTimeAddress(merchant, _tokens, amount, salt, paymentId, yieldFunds));
    vm.prank(payer);
    IERC20 token = IERC20(tokenAddr);
    token.safeTransfer(precomputed, amount);
    vm.prank(_gratefulAutomation);
    _grateful.createOneTimePayment(merchant, _tokens, amount, salt, paymentId, yieldFunds, precomputed);
  }
}
