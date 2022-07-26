// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TokenRegistry is Initializable, OwnableUpgradeable {
  event TokenAdded(address indexed by, address indexed token);
  event TokenRemoved(address indexed by, address indexed token);

  /// @notice Token -> Bool
  mapping(address => bool) public enabled;

  function initialize() external initializer {
    __Ownable_init();
  }

  /**
   @notice Add payment token
   @dev Only owner
   @param _token ERC20 token address
   */
  function add(address _token) external onlyOwner {
    require(!enabled[_token], "token already added");

    enabled[_token] = true;

    emit TokenAdded(msg.sender, _token);
  }

  /**
   @notice Remove payment token
   @dev Only owner
   @param _token ERC20 token address
   */
  function remove(address _token) external onlyOwner {
    require(enabled[_token], "token not exist");

    enabled[_token] = false;

    emit TokenRemoved(msg.sender, _token);
  }
}
