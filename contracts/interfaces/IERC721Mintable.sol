// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IERC721Mintable {
  function mint(address _to, uint256 _tokenCount) external;
}
