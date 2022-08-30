// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20Mock is ERC20 {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
    _mint(msg.sender, 10**30);
  }

  function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
    return interfaceId == type(IERC20).interfaceId;
  }
}
