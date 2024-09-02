import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract OneTime {
  IERC20 public token;
  address public merchant;
  uint256 public amount;
  bool public paid;

  constructor(IERC20 _token, address _merchant, uint256 _amount) {
    token = _token;
    merchant = _merchant;
    amount = _amount;
  }

  function processPayment() public {
    paid = true;
    token.transfer(merchant, amount);
  }
}
