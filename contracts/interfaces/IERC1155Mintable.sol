// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IERC1155Mintable {
  function mint(
    address _to,
    uint256 _amount,
    bytes memory _data
  ) external;

  function mintBatch(
    address _to,
    uint256[] memory _amounts,
    bytes memory _data
  ) external;
}
