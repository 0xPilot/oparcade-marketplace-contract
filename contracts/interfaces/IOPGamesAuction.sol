// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IOPGamesAuction {
  function auctions(address, uint256)
    external
    view
    returns (
      address,
      address,
      uint256,
      uint256,
      uint256,
      bool
    );
}
