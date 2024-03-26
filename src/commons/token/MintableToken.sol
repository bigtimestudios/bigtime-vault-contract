// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "src/commons/token/TokenPermit.sol";

import "src/commons/Ownable.sol";


contract MintableToken is TokenPermit, Ownable {
  error MintingDisabled();

  event MintingEnded(address _sender);

  bool public mintingEnabled = true;

  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals
  ) TokenPermit(_name, _symbol, _decimals) {}

  function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
    if (!mintingEnabled) revert MintingDisabled();
    _mint(_to, _amount);
    return true;
  }

  function disableMinting() external onlyOwner returns (bool) {
    if (!mintingEnabled) revert MintingDisabled();
    mintingEnabled = false;
    emit MintingEnded(msg.sender);
    return true;
  }
}
