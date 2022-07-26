// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
  constructor() ERC721("MockNFT", "TESTNFT") {}

  function mint(address to, uint256 id) public {
    _mint(to, id);
  }
}
