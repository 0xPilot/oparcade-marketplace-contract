// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface ITokenRegistry {
  function enabled(address _token) external view returns (bool);
}
