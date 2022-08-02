// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IAddressRegistry {
  function tokenRegistry() external view returns (address);

  function marketplace() external view returns (address);

  function auction() external view returns (address);
}
