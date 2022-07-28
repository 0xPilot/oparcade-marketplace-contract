// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface ITokenRegistry {
  function enabledCollection(address _nftAddress) external view returns (bool);

  function enabledPayToken(address _token) external view returns (bool);
}
